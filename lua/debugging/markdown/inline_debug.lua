---@module 'debugging.markdown.inline_debug'
---@brief Diagnose inline-code highlighting in Markdown buffers.
---@description
--- Robust collector for diagnostic information about inline-code highlighting
--- in Markdown buffers. Writes a timestamped log to stdpath("data")/debuglog/
--- markdown_inline and provides a user command. Uses only non-deprecated
--- LSP/highlight APIs, guarded with pcall throughout, and makes file I/O and
--- API access robust across Neovim versions.

local notify = require("lib.nvim.notify").create("[debugging.markdown.inline_debug]")

local M = {}

local debugfolder = vim.fn.stdpath("data") .. "/debuglog/markdown_inline"

--------------------------------------------------------------------------------
-- get_timestamp
--------------------------------------------------------------------------------
--- Return a timestamp suitable for filenames (seconds precision).
--- Always returns a string (explicit tostring) so static analyzers see a consistent type.
---@return string timestamp_string
local function get_timestamp()
  local now_sec = math.floor(os.time())
  -- os.date can theoretically return non-string types in some analyzer models;
  -- wrapping with tostring guarantees a string return value.
  return tostring(os.date("%Y%m%d-%H%M%S", now_sec))
end

--- Safe pcall wrapper that returns (ok:boolean, result_or_err:string)
---@param fn function
---@return boolean, any|string
local function safe_call(fn)
  local ok, res = pcall(fn)
  if ok then
    return true, res
  end
  return false, tostring(res)
end

--- Simple serializer for logging; prefers vim.inspect when available.
---@param v any
---@return string
local function dump(v)
  local ok, inspect = pcall(require, "vim.inspect")
  if ok and inspect then
    return inspect(v, { depth = 5 })
  end
  if type(v) == "table" then
    local parts = {}
    for k, val in pairs(v) do
      table.insert(parts, tostring(k) .. "=" .. tostring(val))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end

--- Get highlight definition by name with compatibility and safe pcall.
--- Uses only the modern `nvim_get_hl` when available to avoid deprecated APIs.
---@param name string
---@return table|string hl_or_err  -- returns a table on success or an error string on failure
local function get_highlight(name)
  -- prefer modern API; guard with type check to avoid calling missing/old APIs
  if type(vim.api.nvim_get_hl) ~= "function" then
    -- older Neovim without modern API: return a descriptive error string instead of calling deprecated functions
    return "<error: vim.api.nvim_get_hl not available on this Neovim build>"
  end

  local ok, res = pcall(function()
    -- call with link=true so returned table may include a `link` field resolved by Neovim
    return vim.api.nvim_get_hl(0, { name = name, link = true })
  end)

  if not ok then
    return ("<error: %s>"):format(tostring(res))
  end

  return res
end

--- Return a list of interesting highlight groups.
---@return string[]
local function interesting_hl_groups()
  return {
    "markdownCode",
    "markdownCodeDelimiter",
    "MarkdownInlineCode",
    "@markup.raw",
    "@markup.raw.block",
    "@markup.fenced_code.block",
    "@markup.raw.inline",
    "@markup.raw.inline.markdown_inline",
    "@text.literal",
    "@text.literal.markdown_inline",
    "@markup.raw.delimiter",
    "@punctuation.delimiter.markdown",
    "@punctuation.delimiter.markdown_inline",
    "Comment",
    "String",
    "Constant",
    "Special",
    "DiagnosticWarn",
    "Normal",
  }
end

--- Collect Treesitter info for buffer (best-effort).
---@param bufnr number
---@return table
local function collect_treesitter_info(bufnr)
  local info = {}
  local ok_parsers, parsers = safe_call(function()
    return require("nvim-treesitter.parsers")
  end)
  info.filetype = vim.bo[bufnr].filetype
  if not ok_parsers then
    info.parsers_available = false
    info.parsers_error = parsers
    return info
  end
  local ok_has, has = safe_call(function()
    return parsers.has_parser(info.filetype)
  end)
  info.has_parser = ok_has and has or false
  local ok_getp, getp = safe_call(function()
    return parsers.get_parser(bufnr)
  end)
  info.parser_attached = ok_getp and (getp ~= nil) or false
  return info
end

--------------------------------------------------------------------------------
-- collect_lsp_info
--------------------------------------------------------------------------------
--- Collect LSP clients attached to the buffer.
--- Uses only non-deprecated APIs where possible. If `vim.lsp.get_clients` exists it
--- enumerates them and does a best-effort filter for clients likely relevant to the
--- given buffer. If the modern API is not present, returns an empty table rather
--- than calling deprecated functions.
---@param bufnr number
---@return table info  -- table with `.clients` array or `.error` on failure
local function collect_lsp_info(bufnr)
  local result = {}

  -- Guard: ensure modern API exists; do not call deprecated vim.lsp.buf_get_clients
  if not (vim.lsp and type(vim.lsp.get_clients) == "function") then
    -- Older Neovim without modern API — avoid calling deprecated functions to silence LSP warnings.
    result.clients = {}
    return result
  end

  local ok, clients_or_err = pcall(function()
    return vim.lsp.get_clients()
  end)
  if not ok then
    result.error = tostring(clients_or_err)
    return result
  end

  local filtered = {}
  for _, c in ipairs(clients_or_err) do
    -- Best-effort heuristics to decide whether client is relevant to this buffer:
    -- 1) If client explicitly exposes attached_buffers (some LSP wrappers do), prefer that.
    -- 2) If client supports 'textDocument' capabilities, assume it's relevant.
    -- 3) Otherwise include the client so the user can inspect it — safer than dropping it.
    local considered_relevant = false

    if c.attached_buffers and type(c.attached_buffers) == "table" then
      for _, b in ipairs(c.attached_buffers) do
        if b == bufnr then
          considered_relevant = true
          break
        end
      end
    end

    -- If not explicitly attached, check server_capabilities as a loose signal
    if not considered_relevant and c.server_capabilities and type(c.server_capabilities) == "table" then
      -- presence of textDocumentSync or completionProvider are normal signs of a document LSP
      if c.server_capabilities.textDocumentSync or c.server_capabilities.completionProvider then
        considered_relevant = true
      end
    end

    -- If still unknown, include the client (it's better to show extra clients than miss one)
    if considered_relevant or true then
      table.insert(filtered, {
        name = c.name,
        id = c.id or "<no-id>",
        -- attached_buffers may not be present; show what is available
        attached_buffers = c.attached_buffers or "<unknown>",
        workspace_folders = c.workspace_folders and vim.inspect(c.workspace_folders) or nil,
        server_capabilities = c.server_capabilities and vim.inspect(c.server_capabilities) or nil,
      })
    end
  end

  result.clients = filtered
  return result
end
--- Collect buffer-local settings that may influence highlighting.
---@param bufnr number
---@return table
local function collect_buffer_info(bufnr)
  local b = {}
  b.bufnr = bufnr
  b.name = vim.api.nvim_buf_get_name(bufnr)
  b.filetype = vim.bo[bufnr].filetype
  b.syntax = vim.bo[bufnr].syntax
  b.buftype = vim.bo[bufnr].buftype
  b.modified = vim.bo[bufnr].modified
  b.readonly = vim.bo[bufnr].readonly
  b.line_count = vim.api.nvim_buf_line_count(bufnr)
  local ok_lines, lines = pcall(function()
    return vim.api.nvim_buf_get_lines(bufnr, 0, math.min(50, b.line_count), false)
  end)
  if ok_lines then
    b.lines_sample = table.concat(lines, "\n")
  else
    b.lines_sample = "<could not read lines>"
  end
  return b
end

--------------------------------------------------------------------------------
-- collect_autocmds
--------------------------------------------------------------------------------
--- Collect autocommands for the "MarkdownFencedFix" group.
--- The function may return either a table (autocmd list) or a string (fallback message)
--- depending on runtime API availability; the annotation reflects that.
--- This prevents diagnostics complaining about mismatched return types.
---@return table|string autocmds_or_msg
local function collect_autocmds()
  if type(vim.api.nvim_get_autocmds) ~= "function" then
    -- API not present on older Neovim builds; return a descriptive fallback string.
    return "<nvim.api.nvim_get_autocmds not available on this Neovim>"
  end

  local ok, res = pcall(function()
    -- Request autocommands for the named augroup. This returns a list (table) on success.
    return vim.api.nvim_get_autocmds({ group = "MarkdownFencedFix" })
  end)

  if not ok then
    -- pcall failed; return the error string so caller can log it.
    return tostring(res)
  end

  return res
end
--- Collect loaded modules that match keywords (best-effort).
---@return table
local function collect_loaded_modules()
  local mods = {}
  for k, _ in pairs(package.loaded) do
    if
      k:match("[Mm]arkdown")
      or k:match("[Hh]ighlight")
      or k:match("snacks")
      or k:match("fenced")
      or k:match("treesitter")
    then
      table.insert(mods, k)
    end
  end
  table.sort(mods)
  return mods
end

--- Main gather function; writes log and notifies user.
---@return boolean, string|nil  -- ok, errmsg_or_path
function M.gather()
  local ts = get_timestamp()
  M.timestamp = ts
  local bufnr = vim.api.nvim_get_current_buf()
  M.bufnr = bufnr
  M.results = {}

  M.results.env = {
    neovim_version = vim.version(),
    colorscheme = vim.g.colors_name,
    runtimepath = vim.o.runtimepath,
    termguicolors = vim.o.termguicolors,
    background = vim.o.background,
  }

  M.results.buffer = collect_buffer_info(bufnr)

  M.results.highlights = {}
  for _, name in ipairs(interesting_hl_groups()) do
    M.results.highlights[name] = get_highlight(name)
  end

  M.results.treesitter = collect_treesitter_info(bufnr)
  M.results.lsp = collect_lsp_info(bufnr)
  M.results.autocmds = collect_autocmds()
  M.results.loaded_modules = collect_loaded_modules()

  local syntax_on = false
  pcall(function()
    syntax_on = vim.fn.exists("syntax_on") == 1
  end)
  M.results.syntax_on = syntax_on

  local link_probe = {}
  local probe_names = { "MarkdownInlineCode", "markdownCode", "markdownCodeDelimiter" }
  for _, n in ipairs(probe_names) do
    link_probe[n] = get_highlight(n)
  end
  M.results.link_probe = link_probe

  local log_lines = {}
  table.insert(log_lines, ("Markdown Inline Highlight Debug - %s"):format(ts))
  table.insert(log_lines, "=== ENVIRONMENT ===")
  table.insert(log_lines, dump(M.results.env))
  table.insert(log_lines, "=== BUFFER ===")
  table.insert(log_lines, dump(M.results.buffer))
  table.insert(log_lines, "=== HIGHLIGHTS (selected) ===")
  for k, v in pairs(M.results.highlights) do
    table.insert(log_lines, ("%s => %s"):format(k, dump(v)))
  end
  table.insert(log_lines, "=== LINK PROBE ===")
  table.insert(log_lines, dump(M.results.link_probe))
  table.insert(log_lines, "=== TREESITTER ===")
  table.insert(log_lines, dump(M.results.treesitter))
  table.insert(log_lines, "=== LSP ===")
  table.insert(log_lines, dump(M.results.lsp))
  table.insert(log_lines, "=== AUTOCMDS 'MarkdownFencedFix' ===")
  table.insert(log_lines, dump(M.results.autocmds))
  table.insert(log_lines, "=== LOADED MODULES (filtered) ===")
  table.insert(log_lines, dump(M.results.loaded_modules))
  table.insert(log_lines, "=== SYNTAX ON? ===")
  table.insert(log_lines, dump(M.results.syntax_on))
  table.insert(log_lines, "")
  table.insert(log_lines, "=== SAMPLE TOP LINES OF BUFFER ===")
  table.insert(log_lines, M.results.buffer.lines_sample or "")

  -- Ensures the timestamp `ts` is inserted correctly into the filename
  local out_path = debugfolder .. "_debuglog_" .. ts .. ".log"
  --create the "debuglog" directory if it doesn't exist
  vim.fn.mkdir(debugfolder)
  M.out_path = out_path

  -- write file robustly and return clear error on failure
  local fd, open_err = io.open(out_path, "w")
  if not fd then
    return false, ("failed to open log file '%s': %s"):format(out_path, tostring(open_err))
  end
  local ok_write, write_err = pcall(function()
    fd:write(table.concat(log_lines, "\n"))
    fd:close()
  end)
  if not ok_write then
    return false, ("failed to write log file '%s': %s"):format(out_path, tostring(write_err))
  end

  -- Notify user
  notify.info(("wrote debug log to %s"):format(out_path))

  -- Quick echo summary in command line (escape single quotes)
  local quick = {
    ("buf=%d"):format(bufnr),
    ("filetype=%s"):format(M.results.buffer.filetype or "<nil>"),
    ("colorscheme=%s"):format(M.results.env.colorscheme or "<nil>"),
    ("termguicolors=%s"):format(tostring(M.results.env.termguicolors)),
    ("syntax_on=%s"):format(tostring(M.results.syntax_on)),
  }
  vim.cmd(("echohl ModeMsg | echo '%s' | echohl None"):format(table.concat(quick, " | ")))

  return true, out_path
end

--- Open the generated log in a new tab buffer (safe).
---@return boolean, string|nil
function M.open_log()
  if not M.out_path then
    return false, "no log file found; run gather() first"
  end
  local ok, res = pcall(function()
    local fname = vim.fn.fnameescape(M.out_path)
    vim.cmd("tabnew")
    vim.cmd("silent edit " .. fname)
    vim.bo.readonly = true
    vim.bo.bufhidden = "wipe"
  end)
  if not ok then
    return false, tostring(res)
  end
  return true, M.out_path
end

return M
