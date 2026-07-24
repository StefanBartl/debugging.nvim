---@module 'debugging.health'
---@brief :checkhealth debugging — environment, lib.nvim deps, and per-feature externals.

local M = {}

---@param mod string
---@param label string
---@param level "ok"|"warn"|"info"
local function check_require(mod, label, level)
  if pcall(require, mod) then
    vim.health.ok(label .. " (" .. mod .. ")")
  elseif level == "warn" then
    vim.health.warn(label .. " missing (" .. mod .. ")")
  else
    vim.health.info(label .. " not found (" .. mod .. ")")
  end
end

function M.check()
  -- ── Core ────────────────────────────────────────────────────────────────
  vim.health.start("debugging: core")
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.warn("Neovim 0.9+ recommended")
  end
  if vim.g.loaded_debugging then
    vim.health.ok("plugin loaded (vim.g.loaded_debugging = " .. tostring(vim.g.loaded_debugging) .. ")")
  else
    vim.health.warn("plugin guard not set — call require('debugging').setup()")
  end

  -- ── lib.nvim dependency ───────────────────────────────────────────────────
  vim.health.start("debugging: lib.nvim")
  check_require("lib.nvim.usercmd.composer", ":Debug command layer", "warn")
  check_require("lib.nvim.notify", "notify", "warn")
  check_require("lib.nvim.buf_win_tab.buffer_utils", "reports: buffer_utils", "warn")
  check_require("lib.nvim.buf_win_tab.windows_utils", "reports: windows_utils", "warn")
  check_require("lib.nvim.buf_win_tab.tabs_utils", "reports: tabs_utils", "warn")
  check_require("lib.nvim.buf_win_tab.capture", "views: capture", "info")
  check_require("lib.nvim.fs.write.to_file", "views: fs.write.to_file", "warn")
  check_require("lib.nvim.fs.path", "views: fs.path", "warn")
  check_require("lib.nvim.normalize", "views: normalize", "warn")
  check_require("lib.nvim.fs.collect_recursive", "autocmds sources: directory walk", "warn")
  check_require("lib.nvim.cache.memory", "autocmds sources: scan cache", "warn")
  check_require("lib.nvim.window", "views/overview: scratch + float windows", "warn")
  check_require("lib.lua.lazy", "lib.lua.lazy", "warn")

  -- ── Externals per feature ─────────────────────────────────────────────────
  vim.health.start("debugging: externals")

  local has_clipboard = false
  for _, bin in ipairs({ "pbcopy", "wl-copy", "xclip", "xsel", "clip.exe" }) do
    if vim.fn.executable(bin) == 1 then
      vim.health.ok("clipboard provider: " .. bin)
      has_clipboard = true
    end
  end
  if not has_clipboard then
    vim.health.warn("No clipboard provider (views capture → clipboard disabled)", {
      "Install pbcopy (macOS) / wl-copy (Wayland) / xclip (X11) / clip.exe (WSL)",
    })
  end

  if pcall(require, "nvim-treesitter") then
    vim.health.ok("nvim-treesitter present (markdown / indent diagnostics)")
  else
    vim.health.info("nvim-treesitter not installed (optional)")
  end

  if pcall(require, "noice") then
    vim.health.ok("noice present (views: Noice all/errors)")
  else
    vim.health.info("noice not installed — Noice views fall back to :messages")
  end

  if require("debugging.bindings.which_key").available() then
    vim.health.ok("which-key present (views keymap group label)")
  else
    vim.health.info("which-key not installed (optional)")
  end

  -- ── Write permissions ─────────────────────────────────────────────────────
  local state_dir = vim.fn.stdpath("state") .. "/debug_views"
  if pcall(vim.fn.mkdir, state_dir, "p") then
    vim.health.ok("write permissions OK: " .. state_dir)
  else
    vim.health.error("cannot write to: " .. state_dir)
  end

  -- ── module_reload ─────────────────────────────────────────────────────────
  vim.health.start("debugging: module_reload")
  if vim.loader ~= nil then
    vim.health.ok("vim.loader available (Neovim 0.9+ cache reset supported)")
  else
    vim.health.info("vim.loader not available — only package.loaded cache will be cleared")
  end


  -- ── autocmds sources parser ───────────────────────────────────────────────
  vim.health.start("debugging: autocmds sources")
  if pcall(vim.treesitter.get_string_parser, "", "lua") then
    vim.health.ok("Lua Tree-sitter parser available (sources audit uses Tree-sitter)")
  else
    vim.health.info("no Lua Tree-sitter parser — sources audit falls back to the text parser")
  end

  -- ── performance (startup benchmark) ───────────────────────────────────────
  vim.health.start("debugging: performance")
  if vim.v.progpath and vim.v.progpath ~= "" then
    vim.health.ok("Neovim binary located for `:Debug performance startup`: " .. vim.v.progpath)
  else
    vim.health.warn("vim.v.progpath is empty — `:Debug performance startup` cannot spawn Neovim")
  end

  -- ── neotree bridge (opt-in, config-specific) ──────────────────────────────
  vim.health.start("debugging: neotree (opt-in)")
  local neotree = require("debugging.config").get().neotree or {}
  for _, key in ipairs({ "quarantine", "safety" }) do
    local target = neotree[key]
    if type(target) == "table" then
      vim.health.ok(("neotree.%s bridge injected directly (table)"):format(key))
    elseif type(target) == "string" then
      check_require(target, "neotree." .. key .. " bridge", "info")
    else
      vim.health.info(("neotree.%s not configured"):format(key))
    end
  end

  -- ── proc_trace (freeze diagnosis) ─────────────────────────────────────────
  vim.health.start("debugging: proc (freeze diagnosis)")
  check_require("lib.nvim.system.proc_trace", "lib.nvim.system.proc_trace", "warn")
  if vim.fn.has("win32") == 1 then
    local hits = vim.api.nvim_get_runtime_file("scripts/watch-nvim-procs.ps1", false)
    if hits[1] then
      vim.health.ok("bundled watcher script found: " .. hits[1])
    else
      vim.health.warn("scripts/watch-nvim-procs.ps1 not found on the runtimepath")
    end
    if vim.fn.executable("pwsh") == 1 or vim.fn.executable("powershell") == 1 then
      vim.health.ok("PowerShell available (pwsh or powershell.exe) for `:Debug proc watch`")
    else
      vim.health.warn("neither pwsh nor powershell.exe on PATH — `:Debug proc watch` will fail")
    end
  else
    vim.health.info("`:Debug proc watch` is Windows-only (Win32 CIM process tree); "
      .. "`:Debug proc start/stop/status/log` work on every platform")
  end
end

return M
