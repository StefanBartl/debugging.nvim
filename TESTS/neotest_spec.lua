-- TESTS/neotest_spec.lua
-- Covers `debugging.actions.neotest`: the six reports against a fake
-- neotest (`package.loaded["neotest"]` / `["neotest.config"]`), and the
-- "neotest not loaded" degradation without one. Every action returns its
-- lines, so the reports are asserted on their text; `neotest.output =
-- "notify"` keeps the float out of the headless run.

return function(H)
  local orig_notify = vim.notify
  local seen = {}
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.notify = function(msg, level)
    seen[#seen + 1] = { msg = tostring(msg), level = level }
  end
  local function last()
    return seen[#seen] and seen[#seen].msg or ""
  end
  local function reset()
    seen = {}
  end
  local function joined(lines)
    return table.concat(lines or {}, "\n")
  end

  local saved_neotest = package.loaded["neotest"]
  local saved_neotest_config = package.loaded["neotest.config"]
  local orig_cwd = vim.fn.getcwd()
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")

  local ok, err = pcall(function()
    local config = require("debugging.config")
    config.setup({ neotest = { output = "notify" } })
    local neotest_actions = require("debugging.actions.neotest")

    -- ================================================== without neotest
    package.loaded["neotest"] = nil
    package.loaded["neotest.config"] = nil
    local orig_preload = package.preload["neotest"]
    package.preload["neotest"] = function()
      error("no neotest here")
    end
    reset()
    H.eq(neotest_actions.adapters(), nil, "neotest: adapters returns nil without neotest")
    H.match(last(), "neotest is not loaded", "neotest: absence is reported")
    reset()
    H.eq(neotest_actions.discover(), nil, "neotest: discover returns nil without neotest")
    package.preload["neotest"] = orig_preload

    -- `framework` needs no neotest at all: it reads the cwd.
    vim.fn.writefile({ '{ "devDependencies": { "vitest": "^2" } }' }, tmp .. "/package.json")
    vim.fn.writefile({ "export default {}" }, tmp .. "/vitest.config.ts")
    vim.cmd("cd " .. vim.fn.fnameescape(tmp))
    reset()
    local fw = joined(neotest_actions.framework())
    H.match(fw, "%+ vitest%.config%.ts", "framework: marker file listed")
    H.match(fw, "%+ package%.json", "framework: package.json listed as a marker")
    H.match(fw, "names: vitest", "framework: package.json framework named")
    H.ok(not fw:find("jest", 1, true), "framework: absent framework not named")

    -- ================================================== with a fake neotest
    local proj = tmp .. "/proj"
    vim.fn.mkdir(proj, "p")
    vim.fn.writefile({ "{}" }, proj .. "/package.json")
    local test_file = proj .. "/a.test.ts"
    vim.fn.writefile({ "test()" }, test_file)

    local function node(data)
      return {
        data = function()
          return data
        end,
      }
    end
    local nodes = {
      node({ type = "file", name = "a.test.ts" }),
      node({ type = "namespace", name = "suite" }),
      node({ type = "test", name = "one" }),
      node({ type = "test", name = "two" }),
    }
    local tree = {
      data = function()
        return { type = "file", name = "a.test.ts" }
      end,
      iter_nodes = function()
        local i = 0
        return function()
          i = i + 1
          if nodes[i] then
            return i, nodes[i]
          end
        end
      end,
    }
    local positions_calls = {}
    package.loaded["neotest"] = {
      state = {
        adapter_ids = function()
          return { "neotest-vitest:" .. proj }
        end,
        positions = function(id, args)
          positions_calls[#positions_calls + 1] = { id = id, args = args }
          if id == "neotest-vitest:" .. proj then
            return tree
          end
          return nil
        end,
      },
    }
    package.loaded["neotest.config"] = {
      adapters = {
        {
          name = "neotest-vitest",
          root = function(dir)
            return dir:find(proj, 1, true) and proj or nil
          end,
          is_test_file = function(path)
            return path:match("%.test%.ts$") ~= nil
          end,
        },
        {
          name = "neotest-go",
          root = function()
            return nil
          end,
          is_test_file = function(path)
            return path:match("_test%.go$") ~= nil
          end,
        },
      },
    }

    -- adapters: both lists, in order.
    local ad = neotest_actions.adapters()
    H.match(joined(ad), "Configured %(neotest%.setup%): 2", "adapters: configured count")
    H.match(joined(ad), "%[1%] neotest%-vitest", "adapters: first configured adapter")
    H.match(joined(ad), "%[2%] neotest%-go", "adapters: second configured adapter")
    H.match(joined(ad), "Registered %(state%.adapter_ids%): 1", "adapters: registered count")

    -- state/file/root against the test file.
    H.scratch(test_file, "typescript")
    local st = joined(neotest_actions.state())
    H.match(st, "Found: YES %(neotest%-vitest:", "state: tree found under the owning adapter")
    H.match(st, "Root: a%.test%.ts", "state: root name read via tree:data()")
    H.match(st, "Positions: file 1, namespace 1, test 2", "state: counts by type")
    H.ok(positions_calls[#positions_calls].args.buffer ~= nil, "state: positions asked per buffer")

    local fl = joined(neotest_actions.file())
    H.match(fl, "neotest%-vitest%s+YES", "file: the vitest adapter claims the file")
    H.match(fl, "neotest%-go%s+no", "file: the go adapter does not")
    H.match(fl, "Positions tree: YES", "file: tree reported")

    local rt = joined(neotest_actions.root())
    H.match(rt, "neotest%-vitest%s+" .. vim.pesc(proj), "root: vitest root resolved")
    H.match(rt, "neotest%-go%s+NONE", "root: go has none")
    H.match(rt, "Markers in " .. vim.pesc(proj), "root: markers section for the resolved root")
    H.match(rt, "%+ package%.json", "root: marker found in the root")

    -- discover: per adapter and total.
    local dc = joined(neotest_actions.discover())
    H.match(dc, "4 positions %(file 1, namespace 1, test 2%)", "discover: per-adapter counts")
    H.match(dc, "Tests discovered: 2", "discover: total tests")

    -- A file no adapter wants: the hint appears.
    H.scratch(proj .. "/notes.md", "markdown")
    local fl2 = joined(neotest_actions.file())
    H.match(fl2, "No adapter wants this file", "file: hint when nothing claims it")

    -- A buffer without a file: warning, nil.
    vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
    reset()
    H.eq(neotest_actions.file(), nil, "file: nameless buffer returns nil")
    H.match(last(), "no file", "file: nameless buffer warns")

    -- The dispatcher reaches the category, and completion lists its actions.
    local commands = require("debugging.commands")
    H.eq_list(
      commands.complete("", "Debug neotest ", 14),
      { "adapters", "state", "file", "root", "framework", "discover" },
      "complete: neotest actions"
    )
    reset()
    commands.dispatch({ "neotest", "adapters" })
    H.match(last(), "=== neotest adapters ===", "dispatch: neotest adapters runs")
  end)

  package.loaded["neotest"] = saved_neotest
  package.loaded["neotest.config"] = saved_neotest_config
  vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
  pcall(vim.fn.delete, tmp, "rf")
  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
