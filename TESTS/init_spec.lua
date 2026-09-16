-- TESTS/init_spec.lua
-- Covers `debugging` (lua/debugging/init.lua): the setup() idempotency
-- guard, the features.views gate on wiring up the views subsystem, and that
-- bindings.setup() always runs.
--
-- Loaded fresh via package.loaded manipulation, since the real module
-- instance may already have run its one-shot setup() by the time this spec
-- executes (other specs call `require("debugging").setup({})`).

return function(H)
  local orig_debugging = package.loaded["debugging"]
  local orig_config = package.loaded["debugging.config"]
  local orig_views = package.loaded["debugging.views"]
  local orig_bindings = package.loaded["debugging.bindings"]
  local orig_loaded_flag = vim.g.loaded_debugging

  local ok, err = pcall(function()
    local config_calls, views_calls, bindings_calls = 0, 0, 0

    package.loaded["debugging.config"] = {
      setup = function(opts)
        config_calls = config_calls + 1
        return {
          features = { views = opts and opts.views_enabled or false },
          views = {},
        }
      end,
    }
    package.loaded["debugging.views"] = {
      setup = function()
        views_calls = views_calls + 1
      end,
    }
    package.loaded["debugging.bindings"] = {
      setup = function()
        bindings_calls = bindings_calls + 1
      end,
    }

    package.loaded["debugging"] = nil
    vim.g.loaded_debugging = nil
    local debugging = require("debugging")

    -- features.views = false: bindings.setup() still runs, views.setup() does not.
    debugging.setup({ views_enabled = false })
    H.eq(config_calls, 1, "init: setup() calls config.setup() once")
    H.eq(views_calls, 0, "init: features.views=false skips views.setup()")
    H.eq(bindings_calls, 1, "init: bindings.setup() always runs")
    H.eq(vim.g.loaded_debugging, 1, "init: sets vim.g.loaded_debugging")

    -- Idempotency guard: a second call is a total no-op, regardless of args.
    debugging.setup({ views_enabled = true })
    H.eq(config_calls, 1, "init: setup() is a no-op after the first call (config)")
    H.eq(views_calls, 0, "init: setup() is a no-op after the first call (views)")
    H.eq(bindings_calls, 1, "init: setup() is a no-op after the first call (bindings)")

    -- Fresh module instance, features.views = true this time: views.setup() runs.
    package.loaded["debugging"] = nil
    vim.g.loaded_debugging = nil
    local debugging2 = require("debugging")
    debugging2.setup({ views_enabled = true })
    H.eq(views_calls, 1, "init: features.views=true wires up views.setup()")
  end)

  package.loaded["debugging.config"] = orig_config
  package.loaded["debugging.views"] = orig_views
  package.loaded["debugging.bindings"] = orig_bindings
  package.loaded["debugging"] = orig_debugging
  vim.g.loaded_debugging = orig_loaded_flag
  if not package.loaded["debugging"] then
    require("debugging").setup({}) -- leave a real, set-up module behind
  end

  if not ok then
    error(err, 0)
  end
end
