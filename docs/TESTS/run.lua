-- docs/TESTS/run.lua — headless test runner for debugging.nvim.
--
-- Run from the repo root:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
-- or:
--   nvim --headless -u NONE -c "set rtp+=." -l docs/TESTS/run.lua
--
-- Loads every spec listed below, runs it against the shared harness, prints a
-- per-spec result and exits non-zero if any spec failed (so it is CI-friendly).

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local H = dofile(dir .. "harness.lua")

-- Unlike buffer-ctx.nvim, lib.nvim is a HARD dependency here: every module
-- pulls `lib.nvim.notify` at require time, so without it nothing loads and
-- the suite cannot run at all. A sibling checkout wins over the plugin-manager
-- copy, which is frequently stale.
local function add_lib_nvim()
  local candidates = {}
  if vim.env.LIB_NVIM_PATH then
    candidates[#candidates + 1] = vim.env.LIB_NVIM_PATH
  end
  candidates[#candidates + 1] = vim.fn.getcwd() .. "/../lib.nvim"
  candidates[#candidates + 1] = vim.fn.stdpath("data") .. "/lazy/lib.nvim"

  for _, path in ipairs(candidates) do
    local norm = vim.fs.normalize(path)
    if vim.fn.isdirectory(norm .. "/lua/lib") == 1 then
      vim.opt.rtp:append(norm)
      package.path = table.concat({
        norm .. "/lua/?.lua",
        norm .. "/lua/?/init.lua",
        package.path,
      }, ";")
      return norm
    end
  end
  return nil
end

if not add_lib_nvim() then
  print("FAIL  lib.nvim not found — it is a hard dependency of debugging.nvim.")
  print("      Set $LIB_NVIM_PATH, or check it out next to this repo.")
  os.exit(1)
end

-- Ordered so failures point at the smallest layer first.
local specs = {
  "config_spec.lua",
  "sources_spec.lua",
  "commands_spec.lua",
}

local failed = 0
for _, name in ipairs(specs) do
  local run = dofile(dir .. name)
  local ok, err = pcall(run, H)
  if ok then
    print(("ok    %s"):format(name))
  else
    failed = failed + 1
    print(("FAIL  %s\n      %s"):format(name, tostring(err)))
  end
end

if failed > 0 then
  print(("\n%d spec(s) failed"):format(failed))
  os.exit(1)
end

print("\nDEBUGGING_TESTS_OK")
