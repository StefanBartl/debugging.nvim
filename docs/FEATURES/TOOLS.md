# Tools

The individual `:Debug` categories beyond the dispatcher and the autocmd
audit: state inspection, the terminal keylogger, indent/markdown
diagnostics, the opt-in Neo-tree safety bridge, and the startup-time
benchmark.

## Debug category catalogue

Alongside `messages`/`noice`/`report`/`autocmds`, the dispatcher ships
`inspect`, `cursor`, `dump`, `keylogger`, `indent`, `markdown`, `neotree`
(opt-in), and `health` as first-class categories — each with its own
feature flag and its own leaf module, routed through the same registry as
everything else.

- **Module:** `tools/buffer_inspector/init.lua`, `tools/cursor/state.lua`
  (`M.print`), `tools/vardump/init.lua` (`M.dump`), `terminals/keylogger.lua`,
  `nvim_options/indent_helpers.lua`, `markdown/inline_debug.lua`,
  `actions/neotree_safety.lua`, `health.lua`
- **Usercmds:** `:Debug inspect|cursor|dump|keylogger|indent|markdown|neotree|health`
  (see [BINDINGS.md](../BINDINGS.md#user-commands))

## `inspect window` / `inspect tab`

Window-scoped options/state and a tab page's window/buffer layout, alongside
the pre-existing `inspect buffer`.

- **Module:** `tools/buffer_inspector/init.lua` (`M.window`, `M.tab`,
  `M.inspect`)
- **Usercmds:** `:Debug inspect window [winid]`, `:Debug inspect tab
  [tabnr]` (see [BINDINGS.md](../BINDINGS.md#user-commands))

## Keylogger with logfile

`:Debug keylogger start [file]` (or `config.terminals.keylogger.logfile`)
appends every key pressed in the current terminal buffer to disk, in
addition to the existing notify-only echo — for reviewing long sessions
after the fact. `~` and env vars are expanded.

- **Module:** `terminals/keylogger.lua` (`M.start`, `M.stop`,
  `resolve_logfile`)
- **Config:** `opts.terminals.keylogger.logfile` (default `nil` = notify
  only)
- **Usercmds:** `:Debug keylogger start [file]|stop` (see
  [BINDINGS.md](../BINDINGS.md#user-commands))

## Neo-tree bridge is pcall-guarded

The opt-in Neo-tree safety bridge (`:Debug neotree …`) resolves its two
targets — watcher-quarantine and safety — through a `pcall`-guarded
`require`, so it degrades gracefully with a clear notification instead of
erroring when the user's own `config.neotree.*` layer is absent.

- **Module:** `actions/neotree_safety.lua` (`need`)
- **Config:** `opts.features.neotree` (default `false`)

## Neo-tree bridge injectable

The quarantine/safety targets come from `config.neotree.quarantine` /
`config.neotree.safety`, each either a module *name* to `require` or an
already-loaded table injected directly — so the bridge works without the
private `config.neotree.*` module layout a specific user config happens to
use.

- **Module:** `actions/neotree_safety.lua` (`need`), `config/DEFAULTS.lua`
  (`neotree` table)
- **Config:** `opts.neotree.quarantine`, `opts.neotree.safety` (default
  module names `"config.neotree.watcher_quarantine"` /
  `"config.neotree.safety"`)
- **Usercmds:** `:Debug neotree status|exit|restart|backup-list|backup-clean|dryrun-toggle|dryrun-report|queue-status|queue-clear`
  (see [BINDINGS.md](../BINDINGS.md#user-commands))

## `performance startup`

Spawns a headless Neovim under `--startuptime`, parses the resulting log,
and reports the total startup time (optionally averaged over N runs) plus
the slowest sourced scripts. Each measurement runs in its own subprocess and
quits immediately, so it has no effect on the current session.

- **Module:** `tools/startup.lua` (`M.parse`, `M.startup`)
- **Config:** `opts.features.performance` (default `true`)
- **Usercmds:** `:Debug performance startup [runs]` (see
  [BINDINGS.md](../BINDINGS.md#user-commands))
