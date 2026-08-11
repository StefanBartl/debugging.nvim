# Workflow — getting real use out of debugging.nvim day to day

Every feature here is documented on its own elsewhere (`docs/FEATURES.md`,
`docs/commands.md`, `docs/BINDINGS.md`). This is the different question:
once a freeze happens, or a config stops behaving, which `:Debug` category
do you actually reach for first, and how do the pieces chain together.

## Freeze right now, or freeze reproducible? Different tool, either way

If Neovim is *currently* hung or sluggish and you don't know why yet, the
in-process tracer is useless after the fact — it only sees calls made while
it is running. The real habit is starting it pre-emptively:

```vim
:Debug proc start 200        " first line of a debugging session, ideally
                              " the first line after startup
```

...then reproduce the slow action, and:

```vim
:Debug proc stop
:Debug proc log              " durations + full Lua tracebacks for calls ≥200ms
```

**The trap:** `proc_trace` wraps `vim.fn.system`/`vim.fn.systemlist`/
`vim.system`/`vim.fn.jobstart` in place — a plugin that did
`local system = vim.fn.system` at its own load time, before `proc start`
ran, holds a reference to the *original* function and bypasses the tracer
completely. There is no fix from inside `:Debug`; only starting the tracer
as early as possible in `init.lua` shrinks the window where this matters.

If the culprit turns out not to go through any of those four APIs at all —
an LSP server's own subprocess, or a plugin that shells out through
something `proc_trace` doesn't wrap — `proc_trace` will show nothing. That's
what `proc watch` is for:

```vim
:Debug proc watch 60         " Windows only: bundled PowerShell script polls
                              " the Win32 process tree
" reproduce the freeze in this same instance, Ctrl+C when done
```

It reports every child process regardless of how it was spawned, sorted by
lifetime once you stop it. On Linux/macOS there's no bundled equivalent —
`pstree -p <nvim_pid>` or a `watch`-looped `ps` covers the same ground.
Running both together (`proc start` for the "which line" answer,
`proc watch` for the "which process" answer) is the combination that
actually pins down a freeze that `proc start` alone leaves ambiguous.

## Debugging autocmds: know which of the three views you actually need

`:Debug autocmds` has three actions and it's easy to reach for the wrong one:

| Action | Answers | Source |
|---|---|---|
| `runtime [event] [pat]` | "What's registered *right now*, live" | `nvim_get_autocmds()` |
| `sources [args]` | "Where in the source tree is this defined" | static scan of `nvim_create_autocmd` call sites |
| `all [root=][refresh=][event=]` | "Do those two agree, and what's missing" | fuses both, flags runtime-only events |

`sources` is the one worth knowing the args for: `qf=true` sends
`path:line` to the quickfix list instead of a scratch report, which turns
"find who registered this autocmd" into a normal `:cnext`/`<CR>` jump
instead of manual reading. It also parses with the Lua Tree-sitter grammar
when available and falls back to a text parser otherwise — the Tree-sitter
path is robust against multi-line/nested `nvim_create_autocmd` calls, the
text fallback is not, so a source file with an oddly wrapped call can show
up in `runtime` but silently not in `sources` if Tree-sitter's Lua parser
isn't installed. If a result looks stale, it likely is: results are cached
per project root for a few seconds via `lib.nvim.cache.memory`, so a source
edit right before re-running `sources` needs `refresh=true`, not a second
plain run.

`autocmds all` is the one that actually answers "is this plugin-defined
autocmd expected" — it flags events registered at runtime with no matching
source, which is `sources`'s blind spot (dynamically-registered autocmds,
typically from another plugin) made visible instead of silently absent.

## Reports vs inspect: printed snapshot vs scoped browsing

`:Debug report buf|tab|win [id]` prints straight to `:messages` — fastest
path when you just need to paste a snapshot somewhere (an issue, a chat) or
glance and move on. `:Debug inspect buffer|window|tab [id]` opens a proper
scoped view of options and state — reach for it when you're actually
comparing values across buffers/windows, not just capturing one. Both
accept an explicit id (`report win 1000`, `inspect tab 2`) — omit it for
"the current one".

## Module reload during plugin iteration

`:Debug module reload` reloads the Lua module backing the *current buffer*
— evict from `package.loaded`, re-`require`. This is the fast inner loop
for iterating on debugging.nvim's own source (or any Lua plugin) without
restarting Neovim, but it only clears the one module the buffer belongs to
— it won't cascade to modules that already `require`d the old table and
kept a local reference to it (closures over the pre-reload functions keep
running against stale code until *they're* reloaded too, or Neovim
restarts). For a change that touches several interdependent modules, a
restart is still the reliable answer; `module reload` is for "I changed one
leaf function and want to test it now."

## Neo-tree bridge: opt-in, and silent-by-design when unconfigured

`features.neotree` defaults to `false` for a reason beyond "not everyone
uses Neo-tree" — the bridge's two targets (`neotree.quarantine`,
`neotree.safety`) point at config that lives in *your* Neovim config, not in
this plugin, by design (each is a module name to `require`, or an
already-loaded table you inject directly). Turn the feature on without also
having that config layer present, and every `:Debug neotree *` action
degrades to a warning notification rather than an error — which is
deliberate (pcall-guarded), but means "the command ran with no error" is not
the same as "the command did something." If `:Debug neotree status` just
prints a warning about a target "not configured," that's the expected
behavior for anyone without the private `config.neotree.*` layout, not a
bug to chase.

## Keylogger: notify-only unless you set a logfile

`:Debug keylogger start` with no argument only notifies keys as they're
pressed — nothing is written to disk unless `terminals.keylogger.logfile`
is set in `setup()`, or you pass a path directly:
`:Debug keylogger start ~/keys.log`. The per-session path (via the command
argument) overrides the config default for that run only; it does not
persist. Worth deciding up front whether a given keylogging session needs a
durable record — starting notify-only and realizing later you wanted the
file means re-starting the logger, not recovering what was already typed.

## Startup benchmarking: average over runs, don't trust one sample

`:Debug performance startup` with no argument runs `--startuptime` once.
Startup timing on any real machine has enough run-to-run jitter (disk
cache state, background processes) that a single run is a weak signal for
"did my config change actually help" — `:Debug performance startup 5`
averages the total over 5 headless launches and is the version worth
running before/after a config change you're trying to measure, not the
bare form.

## Tab completion reflects the *active* config, not the full feature set

`:Debug <Tab>` only lists categories enabled by the running config — a
freshly-installed `neotree = false` setup simply won't show `neotree` as a
completion candidate, which is easy to misread as "this feature doesn't
exist" rather than "it's off." If a category you expect is missing from
completion, `:Debug health` (or reading `opts.features` back) is the faster
check than assuming a typo in the command name.

## Keymaps are opt-in and share one prefix

The five default keymaps (`<lt>m/n/e/c/x` — messages, Noice all, Noice
errors, capture, close-all) live under `config.views.keymaps.enable` and a
single configurable prefix (default `<lt>`, the literal `<` key). Disabling
`features.views` disables the keymaps along with the usercmds — there's no
way to keep the keymaps without the underlying views subsystem, since the
keymaps are literally the views' own trigger. If `<` already means something
else in your config, changing `views.keymaps.prefix` is the fix, not
disabling the keymaps and reaching for `:Debug messages show` every time.
