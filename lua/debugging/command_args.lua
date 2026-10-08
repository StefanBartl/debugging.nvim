---@module 'debugging.command_args'
--- The positional arguments of the `:Debug` routes, keyed `"<category> <action>"` (or just `"<category>"` for the
--- free-form ones): name, composer type, and the one-line text the composer option float shows for them. Wording
--- follows the handlers (`debugging.commands` -> the leaf modules) and docs/commands.md.
---
--- A route that is not listed takes no argument (`:Debug messages show`) and has no slot, so the float does not
--- suggest one. A stray token still lands in `ctx.rest`: every route's `run` hands the raw `fargs` to
--- `commands.dispatch`, which ignores what the action does not read. The schema exists to drive `<Tab>` completion
--- and the float; validation and defaults are the handlers' own.
---
--- Types: the handle-taking actions used to share a generic `STRING` slot, which completed nothing -- and a window or
--- buffer id is unguessable, so the only way to supply one was to run `:echo win_getid()` first. They now use the
--- composer type that can enumerate their values. `proc` thresholds and `performance startup` run counts take values
--- this plugin does not enumerate, so a completer there would have nothing true to offer: they stay `STRING`.
--- `keylogger start` writes a file, so file completion is the right one even though the file does not exist yet --
--- it completes the directory part on the way there.

---@type table<string, Lib.UserCmd.Composer.ArgSpec[]>
return {
  ["autocmds runtime"] = {
    {
      name = "event",
      type = "STRING",
      optional = true,
      desc = "Event to list the autocmds of (default: BufAdd)",
    },
    {
      name = "pattern",
      type = "STRING",
      optional = true,
      desc = "Pattern as registered, matched literally (default: *)",
    },
  },
  -- The words are `key=value` options of the audit; `autocmds all` reads event=, root= and refresh= only, so it
  -- takes the text of the type, `sources` lists all of its keys.
  ["autocmds sources"] = {
    {
      name = "expr",
      type = "DBG_AUTOCMD_EXPR",
      optional = true,
      desc = "key=value options: event= sort= impl= summary= freq= root= refresh= qf=",
    },
  },
  ["autocmds all"] = {
    { name = "expr", type = "DBG_AUTOCMD_EXPR", optional = true },
  },
  ["dump"] = {
    {
      name = "varname",
      type = "STRING",
      optional = true,
      desc = "Name of a global Lua variable (default: word under cursor)",
    },
  },
  ["indent treesitter"] = {
    {
      name = "enable",
      type = "STRING",
      optional = true,
      values = { "true", "false" },
      desc = "Prefer Tree-sitter indent in the current buffer (default: true)",
      enum_desc = {
        ["true"] = "turn cindent and smartindent off",
        ["false"] = "turn cindent and smartindent on again",
      },
    },
  },
  ["inspect buffer"] = {
    {
      name = "bufnr",
      type = "BUFFER",
      optional = true,
      desc = "Buffer number to inspect (default: current buffer)",
    },
  },
  ["inspect window"] = {
    {
      name = "winid",
      type = "WINDOW",
      optional = true,
      desc = "Window id to inspect (default: current window)",
    },
  },
  ["inspect tab"] = {
    {
      name = "tabnr",
      type = "STRING",
      optional = true,
      desc = "Tab number as in the tabline (default: current tab)",
    },
  },
  ["keylogger start"] = {
    {
      name = "file",
      type = "PATH",
      optional = true,
      desc = "File to append the keys to (default: the configured logfile)",
    },
  },
  ["performance startup"] = {
    {
      name = "runs",
      type = "STRING",
      optional = true,
      desc = "Number of startups to average, 1 to 20 (default: 1)",
    },
  },
  ["proc start"] = {
    {
      name = "threshold_ms",
      type = "STRING",
      optional = true,
      desc = "Slow-call threshold in ms; slower calls get a traceback (default: 200)",
    },
  },
  ["proc watch"] = {
    {
      name = "seconds",
      type = "STRING",
      optional = true,
      desc = "How long the watcher runs, in seconds (default: 120)",
    },
  },
  ["report win"] = {
    {
      name = "winid",
      type = "WINDOW",
      optional = true,
      desc = "Window id to report (default: current window)",
    },
  },
}
