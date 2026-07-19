---@module 'debugging.views.capture'
---@brief Unified capture system for :messages, Noice, etc.
---@description
--- Reads the message history (Noice when available, `:messages` otherwise),
--- then optionally copies it to the clipboard and writes a timestamped file
--- under the configured output directory. Clipboard and file writer are
--- pulled in lazily, so a capture that needs neither costs nothing.
--- Returns `ok, content_or_error` — it never notifies on behalf of callers.

local notify = require("lib.nvim.notify").create("[debugging.views.capture]")

local lazy = require("lib.lua.lazy")
local copy_to_clipboard = lazy.require("debugging.views.capture.clipboard")
local write_file = lazy.require("lib.nvim.fs.write.to_file")

local M = {}

-- Default capture directory
---@type string
M.base_dir = vim.fn.stdpath("config") .. "/docs/debug_views"

---@param s string
---@return string
local function rstrip(s)
  return (s:gsub("%s*$", ""))
end

---@return string dir, string logfile
local function resolve_paths()
  local base = require("lib.nvim.normalize").normalize_path(M.base_dir)
  local dir = base
  local timestamp = os.date("%Y%m%d-%H%M%S")
  local logfile = require("lib.nvim.fs.path").joinpath({ dir, string.format("messages-%s.log", timestamp) })
  return dir, logfile
end

---Extract text content from Noice message object (handles functions and _lines)
---@param obj any Noice message object or content part
---@param depth? integer Recursion depth limit
---@return string|nil
local function extract_noice_text(obj, depth)
  depth = depth or 0
  if depth > 10 then return nil end

  if type(obj) == "string" then
    return obj
  end

  if type(obj) ~= "table" then
    return nil  -- Don't stringify non-string, non-table values
  end

  -- Noice Message objects have _lines field (internal storage)
  if obj._lines and type(obj._lines) == "table" then
    local lines = {}
    for _, line in ipairs(obj._lines) do
      if type(line) == "table" then
        -- Each line is an array of content parts
        local parts = {}
        for _, part in ipairs(line) do
          if type(part) == "string" then
            table.insert(parts, part)
          elseif type(part) == "table" then
            -- Part might have _text field
            if part._text then
              table.insert(parts, tostring(part._text))
            elseif part[1] then
              table.insert(parts, tostring(part[1]))
            end
          end
        end
        if #parts > 0 then
          table.insert(lines, table.concat(parts, ""))
        end
      elseif type(line) == "string" then
        table.insert(lines, line)
      end
    end
    if #lines > 0 then
      return table.concat(lines, "\n")
    end
  end

  -- If content is a function, call it
  if obj.content and type(obj.content) == "function" then
    local ok, result = pcall(obj.content, obj)
    if ok and result then
      return extract_noice_text(result, depth + 1)
    end
  end

  -- If content is already extracted
  if obj.content and type(obj.content) ~= "function" then
    return extract_noice_text(obj.content, depth + 1)
  end

  -- Handle array of content parts
  if obj[1] ~= nil then
    local parts = {}
    for _, item in ipairs(obj) do
      if type(item) == "string" then
        table.insert(parts, item)
      elseif type(item) == "table" then
        if item._text then
          table.insert(parts, tostring(item._text))
        elseif item[1] then
          local nested = extract_noice_text(item, depth + 1)
          if nested then table.insert(parts, nested) end
        else
          local text = item.text or item.str
          if text then table.insert(parts, tostring(text)) end
        end
      end
    end
    if #parts > 0 then
      return table.concat(parts, "")
    end
  end

  -- Try other known fields
  if obj._text then
    return tostring(obj._text)
  end

  if obj.message then
    if type(obj.message) == "string" then
      return obj.message
    else
      return extract_noice_text(obj.message, depth + 1)
    end
  end

  if obj.text then
    return tostring(obj.text)
  end

  if obj.str then
    return tostring(obj.str)
  end

  return nil
end

---Try to get messages from Noice if available
---@return boolean success, string|nil messages, string|nil source
local function try_noice()
  local ok_noice, noice = pcall(require, "noice")
  if not ok_noice then
    return false, nil, "noice not installed"
  end

  -- Method 1: Get from message manager (most reliable)
  local ok_manager, manager = pcall(require, "noice.message.manager")
  if ok_manager and manager and manager.get then
    -- Get ALL messages including history
    local ok_msgs, messages = pcall(manager.get, nil, {
      history = true,
      reverse = false,  -- Chronological order
    })

    if ok_msgs and messages and type(messages) == "table" then
      local lines = {}
      local msg_count = 0

      for _, msg in ipairs(messages) do
        msg_count = msg_count + 1
        local text = extract_noice_text(msg)

        if text and text ~= "" then
          -- Include timestamp if available
          if msg.opts and msg.opts.timestamp then
            local ts = os.date("%H:%M:%S", msg.opts.timestamp)
            table.insert(lines, string.format("[%s] %s", ts, text))
          else
            table.insert(lines, text)
          end
        end
      end

      if #lines > 0 then
        return true, table.concat(lines, "\n"), string.format("noice.manager (%d messages)", msg_count)
      end
    end
  end

  -- Method 2: Try getting from Noice history directly
  if noice.history and type(noice.history.get) == "function" then
    local ok_hist, history = pcall(noice.history.get)
    if ok_hist and history and type(history) == "table" and #history > 0 then
      local lines = {}
      for _, entry in ipairs(history) do
        local text = extract_noice_text(entry)
        if text and text ~= "" then
          table.insert(lines, text)
        end
      end
      if #lines > 0 then
        return true, table.concat(lines, "\n"), string.format("noice.history (%d entries)", #history)
      end
    end
  end

  -- Method 3: Read from Noice buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local ok_name, name = pcall(vim.api.nvim_buf_get_name, buf)
      if ok_name and name and name:match("noice://") then
        local ok_lines, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, -1, false)
        if ok_lines and lines and #lines > 0 then
          -- Filter out empty lines
          local filtered = {}
          for _, line in ipairs(lines) do
            if line ~= "" then
              table.insert(filtered, line)
            end
          end
          if #filtered > 0 then
            return true, table.concat(filtered, "\n"), string.format("noice buffer (%d lines)", #filtered)
          end
        end
      end
    end
  end

  -- Method 4: Try API status (usually just shows last message)
  if noice.api and noice.api.status and noice.api.status.message then
    local ok_status, status_msg = pcall(noice.api.status.message.get)
    if ok_status and status_msg and status_msg ~= "" then
      return true, status_msg, "noice.api.status (last message only)"
    end
  end

  return false, nil, "noice available but empty"
end

---Try to get messages via vim.fn.execute
---@return boolean success, string|nil messages, string|nil source
local function try_execute()
  local ok_exec, messages = pcall(vim.fn.execute, "messages")
  if ok_exec and messages and rstrip(messages) ~= "" then
    return true, messages, "vim.fn.execute('messages')"
  end
  return false, nil, "vim.fn.execute returned empty"
end

---Try to get messages via nvim_exec2
---@return boolean success, string|nil messages, string|nil source
local function try_exec2()
  local ok_exec, res = pcall(vim.api.nvim_exec2, "messages", { output = true })
  if ok_exec and res and res.output and rstrip(res.output) ~= "" then
    return true, res.output, "nvim_exec2('messages')"
  end
  return false, nil, "nvim_exec2 returned empty"
end

---Capture messages with multiple fallback strategies
---@param debug boolean
---@return boolean success, string|nil messages, string|nil source
local function capture_messages_raw(debug)
  local attempts = {}

  -- Strategy 1: Try Noice first (most reliable with Noice installed)
  local ok, msgs, src = try_noice()
  table.insert(attempts, { method = "noice", success = ok, source = src })
  if ok then
    if debug then notify.debug("DebugViews: ✓ captured via " .. src) end
    return true, msgs, src
  end

  -- Strategy 2: Try vim.fn.execute
  ok, msgs, src = try_execute()
  table.insert(attempts, { method = "execute", success = ok, source = src })
  if ok then
    if debug then notify.debug("DebugViews: ✓ captured via " .. src) end
    return true, msgs, src
  end

  -- Strategy 3: Try nvim_exec2
  ok, msgs, src = try_exec2()
  table.insert(attempts, { method = "exec2", success = ok, source = src })
  if ok then
    if debug then notify.debug("DebugViews: ✓ captured via " .. src) end
    return true, msgs, src
  end

  -- Build detailed error message
  local details = {}
  for _, attempt in ipairs(attempts) do
    table.insert(details, string.format("  • %s: %s", attempt.method, attempt.source))
  end

  return false, nil, "all methods failed:\n" .. table.concat(details, "\n")
end

---Capture :messages with optional file save and clipboard
---@param opts Dbg.Views.CaptureOpts|nil
---@return boolean success, string|nil content
function M.capture_messages(opts)
  opts = opts or {}
  local debug = opts.debug == true
  local save_file = opts.save_file ~= false
  local clipboard = opts.clipboard ~= false

  local dir, logfile = resolve_paths()
  if debug then
    notify.debug(("DebugViews: dir=%s\nlog=%s"):format(dir, logfile))
  end

  -- Try all capture methods
  local ok_capture, messages, source = capture_messages_raw(debug)
  if not ok_capture or not messages then
    notify.warn("DebugViews: Failed to capture messages.\n" .. (source or "unknown error") .. "\n\n" .. "Suggestions:\n" .. " 1. Try :Noice all to view messages\n" .. " 2. Try :messages to check if messages exist\n" .. " 3. Enable debug mode: :lua require('debugging.views.capture').capture_messages({debug=true})")
    return false, nil
  end

  messages = rstrip(messages)
  local line_count = require("lib.lua.strings.core").count_lines(messages)

  if debug then
    notify.debug(("DebugViews: captured %d bytes, %d lines via %s"):format(#messages, line_count, source))
  end

  if messages == "" then
    notify.warn("DebugViews: no messages to capture (empty content)")
    return false, ""
  end

  local success_operations = {}

  if save_file then
    local ok_write, err = write_file(logfile, messages)
    if not ok_write then
      notify.error("DebugViews: write failed: " .. tostring(err))
    else
      table.insert(success_operations, string.format("%d lines → %s", line_count, vim.fn.fnamemodify(logfile, ":t")))
    end
  end

  if clipboard then
    local ok_clip = copy_to_clipboard(messages, debug)
    if not ok_clip then
      notify.warn("DebugViews: clipboard not available. Install: pbcopy/wl-copy/xclip/xsel/clip.exe")
    else
      table.insert(success_operations, string.format("%d lines → clipboard", line_count))
    end
  end

  -- Show combined success notification
  if #success_operations > 0 then
    local msg = "✓ " .. table.concat(success_operations, " | ")
    if debug then
      msg = msg .. "\n  (via " .. source .. ")"
    end
    notify.info(msg)
  end

  return true, messages
end

return M
