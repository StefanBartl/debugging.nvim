-- docs/TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by docs/TESTS/run.lua.

local H = {}

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  if not v then
    error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Assert `s` matches Lua pattern `pat`.
---@param s string
---@param pat string
---@param msg string|nil
function H.match(s, pat, msg)
  if not tostring(s):match(pat) then
    error(("FAIL %s: %q does not match pattern %q"):format(msg or "", tostring(s), pat), 2)
  end
end

--- Assert two list-like tables hold equal values in the same order.
---@param a any[]
---@param b any[]
---@param msg string|nil
function H.eq_list(a, b, msg)
  H.eq(#a, #b, (msg or "") .. " (length)")
  for i = 1, #b do
    H.eq(a[i], b[i], ("%s [%d]"):format(msg or "", i))
  end
end

--- Fresh scratch buffer, made current, named `name` with an optional filetype.
---@param name string|nil
---@param ft string|nil
---@return integer bufnr
function H.scratch(name, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  if name then
    vim.api.nvim_buf_set_name(buf, name)
  end
  if ft then
    vim.bo[buf].filetype = ft
  end
  return buf
end

--- Write `lines` to a fresh file under a temp dir and return both paths.
--- Used by the source-scanner specs, which need real files on disk.
---@param rel string    Path relative to the returned root, e.g. "lua/foo.lua"
---@param lines string[]
---@param root string|nil Reuse an existing root instead of making a new one
---@return string root
---@return string abs
function H.tmpfile(rel, lines, root)
  root = root or vim.fs.normalize(vim.fn.tempname())
  local abs = root .. "/" .. rel
  vim.fn.mkdir(vim.fn.fnamemodify(abs, ":h"), "p")
  vim.fn.writefile(lines, abs)
  return root, abs
end

return H
