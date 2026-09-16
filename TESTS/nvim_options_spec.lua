-- TESTS/nvim_options_spec.lua
-- Covers `debugging.nvim_options.indent_helpers`: the option report and the
-- treesitter-indent-preference toggle (enable/disable/default).

return function(H)
  local indent = require("debugging.nvim_options.indent_helpers")

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

  local ok, err = pcall(function()
    local buf = H.scratch("indent_helpers_spec.lua", "lua")

    reset()
    indent.print_indent_options(buf)
    H.match(last(), "shiftwidth", "print_indent_options: reports shiftwidth")
    H.match(last(), "cindent", "print_indent_options: reports cindent")

    -- enable = true (explicit): cindent/smartindent turned off in favour of
    -- an external indentexpr.
    vim.bo[buf].cindent = true
    vim.bo[buf].smartindent = true
    indent.prefer_treesitter_indent(true)
    H.eq(vim.bo[buf].cindent, false, "prefer_treesitter_indent(true): disables cindent")
    H.eq(vim.bo[buf].smartindent, false, "prefer_treesitter_indent(true): disables smartindent")

    -- enable = false: restores cindent/smartindent.
    indent.prefer_treesitter_indent(false)
    H.eq(vim.bo[buf].cindent, true, "prefer_treesitter_indent(false): restores cindent")
    H.eq(vim.bo[buf].smartindent, true, "prefer_treesitter_indent(false): restores smartindent")

    -- enable = nil defaults to true (same effect as the explicit-true case).
    indent.prefer_treesitter_indent(nil)
    H.eq(vim.bo[buf].cindent, false, "prefer_treesitter_indent(nil): defaults to enable=true")

    reset()
    indent.prefer_treesitter_indent(true)
    H.match(last(), "set to true", "prefer_treesitter_indent: reports the resulting mode")
  end)

  vim.notify = orig_notify
  if not ok then
    error(err, 0)
  end
end
