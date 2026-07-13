---@module 'debugging.nvim_options.indent_helpers'
---@brief Inspect and toggle indentation providers in Neovim.
---@description
--- `:Debug indent show` reports the buffer's indent-related options;
--- `:Debug indent treesitter [true|false]` disables/restores
--- `cindent`/`smartindent` so an existing Tree-sitter indentexpr can take over.

local notify = require("lib.nvim.notify").create("[debugging.nvim_options.indent_helpers]")

local M = {}

local api = vim.api

-- Report current indentation-related buffer options
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
  notify.info(vim.inspect(opts))
end

-- Disables cindent/smartindent so an existing Tree-sitter `indentexpr` (if
-- any is registered for this filetype) can take over; does not itself
-- verify a Tree-sitter parser or indentexpr is configured.
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
  notify.info(("treesitter-prefer mode for %s set to %s"):format(ft, tostring(enable)))
end

return M
