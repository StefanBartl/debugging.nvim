---@module 'debugging.config.KEYMAP_ACTIONS'
--- Names of the views keymap actions, in the order they are declared and shown.
---
--- Pure data, like DEFAULTS: `debugging.config` reads it to accept
--- `views.keymaps.<action> = "<lhs>" | { ... } | false` as known options, and
--- `debugging.bindings.keymaps` reads it as the declaration order of its
--- registry spec. One list for both, so an action added to the spec cannot be
--- forgotten in the schema (it would be dropped as an unknown option, silently
--- for everyone who overrides it).
---@type string[]
return {
  "messages",
  "noice_all",
  "noice_errors",
  "capture",
  "capture_file",
  "capture_clipboard",
  "clear",
}
