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
  check_require("lib.nvim.notify", "notify", "warn")
  check_require("lib.nvim.buf_win_tab.buffer_utils", "reports: buffer_utils", "warn")
  check_require("lib.nvim.buf_win_tab.windows_utils", "reports: windows_utils", "warn")
  check_require("lib.nvim.buf_win_tab.tabs_utils", "reports: tabs_utils", "warn")
  check_require("lib.nvim.buf_win_tab.capture", "views: capture", "info")
  check_require("lib.nvim.fs.write.to_file", "views: fs.write.to_file", "warn")
  check_require("lib.nvim.fs.path", "views: fs.path", "warn")
  check_require("lib.nvim.normalize", "views: normalize", "warn")
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


  -- ── neotree bridge (opt-in, config-specific) ──────────────────────────────
  vim.health.start("debugging: neotree (opt-in)")
  check_require("config.neotree.safety", "neotree.safety bridge", "info")
  check_require("config.neotree.watcher_quarantine", "neotree.watcher_quarantine bridge", "info")
end

return M
