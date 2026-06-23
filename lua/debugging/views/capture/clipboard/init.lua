---@module 'debugging.capture.clipboard'
--- Clipboard helpers using lib.cross for platform detection.

local notify = require("lib.nvim.notify").create("[debugging.views.capture.clipboard]")

local lazy = require("lib.lua.lazy")
local has_exec = lazy.require("lib.nvim.core").has_exec
local cross = lazy.require("lib.nvim.cross")
local run_argv = lazy.require("lib.nvim.cross.run_argv")

---@param text string
---@param debug boolean
---@return boolean|nil
return function (text, debug)
  -- Fast path: Neovim clipboard provider
  local ok = pcall(vim.fn.setreg, "+", text)
  if ok then
    if debug then
      notify.debug("DebugViews: setreg('+') ok")
    end
    return true
  end

  -- Platform detection via lib.cross
  local is_mac = cross.is_macos()
  local is_win = cross.is_windows()
  local is_wsl = cross.is_wsl()
  local is_linux = cross.is_linux()

  -- Display server detection remains environment-based
  local is_wayland = (vim.env.WAYLAND_DISPLAY or "") ~= ""
  local is_x11 = (vim.env.DISPLAY or "") ~= ""

  -- macOS
  if is_mac and has_exec("pbcopy") then
    local ok2, err = run_argv({ "pbcopy" }, text)
    if ok2 then return true end
    if debug then notify.debug("pbcopy failed: " .. tostring(err)) end
  end

  -- Windows / WSL
  if is_win or is_wsl then
    if has_exec("clip.exe") then
      local ok2, err = run_argv({ "clip.exe" }, text)
      if ok2 then return true end
      if debug then notify.debug("clip.exe failed: " .. tostring(err)) end
    end

    local clip_abs = "/mnt/c/Windows/System32/clip.exe"
    if is_wsl and not has_exec("clip.exe") and vim.fn.filereadable(clip_abs) == 1 then
      local ok2, err = run_argv({ clip_abs }, text)
      if ok2 then return true end
      if debug then notify.debug("abs clip.exe failed: " .. tostring(err)) end
    end
  end

  -- Linux (Wayland)
  if is_linux and is_wayland and has_exec("wl-copy") then
    local ok2, err = run_argv({ "wl-copy" }, text)
    if ok2 then return true end
    if debug then notify.debug("wl-copy failed: " .. tostring(err)) end
  end

  -- Linux (X11)
  if is_linux and is_x11 then
    if has_exec("xclip") then
      local ok2, err = run_argv({ "xclip", "-selection", "clipboard" }, text)
      if ok2 then return true end
      if debug then notify.debug("xclip failed: " .. tostring(err)) end
    end
    if has_exec("xsel") then
      local ok2, err = run_argv({ "xsel", "--clipboard", "--input" }, text)
      if ok2 then return true end
      if debug then notify.debug("xsel failed: " .. tostring(err)) end
    end
  end

  return false
end
