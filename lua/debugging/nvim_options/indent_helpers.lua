---@module 'debugging.nvim_options.indent_helpers'
-- Helpers to inspect and toggle indentation providers in Neovim.
-- Usage:
-- :lua require("debugging.indent_helpers").print_indent_options()
-- :lua require("debugging.indent_helpers").prefer_treesitter_indent()
-- or
-- use usercommands

local M = {}

local api = vim.api

-- Print current indentation-related buffer options
---@param bufnr integer? Buffer number, defaults to current buffer
function M.print_indent_options(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local opts = {
    autoindent = api.nvim_get_option_value("autoindent", { buf = bufnr }),
    smartindent = api.nvim_get_option_value("smartindent", { buf = bufnr }),
    cindent = api.nvim_get_option_value("cindent", { buf = bufnr }),
    indentexpr = api.nvim_get_option_value("indentexpr", { buf = bufnr }),
    indentkeys = api.nvim_get_option_value("indentkeys", { buf = bufnr }),
    shiftwidth = api.nvim_get_option_value("shiftwidth", { buf = bufnr }),
    tabstop = api.nvim_get_option_value("tabstop", { buf = bufnr }),
  }
  print(vim.inspect(opts))
end

-- Simple toggle to prefer tree-sitter indent by disabling cindent/smartindent
---@param enable boolean? Enable or disable tree-sitter preference, default true
function M.prefer_treesitter_indent(enable)
  enable = enable == nil and true or enable
  local ft = vim.bo.filetype
  if enable then
    vim.bo.cindent = false
    vim.bo.smartindent = false
  else
    -- Restore default behavior; currently disables tree-sitter preference
    vim.bo.cindent = true
    vim.bo.smartindent = true
  end
  print(("treesitter-prefer mode for %s set to %s"):format(ft, tostring(enable)))
end

return M
