# Tests

Headless spec suite for debugging.nvim.

Most of this plugin is UI side effects (scratch windows, notifications), which
is why testing was deferred for a long time. What *is* worth testing is the
layer underneath: the text parsers in `autocmds/sources.lua`, the argument
handling in `commands.lua` and the config merge — all pure or nearly pure, and
all places where a silent wrong answer is plausible.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
```

The runner prints one line per spec and exits non-zero if any spec failed
(`DEBUGGING_TESTS_OK` on success).

[lib.nvim](https://github.com/StefanBartl/lib.nvim) is a hard dependency —
every module requires `lib.nvim.notify` at load time. The runner looks for it
in `$LIB_NVIM_PATH`, then `../lib.nvim`, then the lazy.nvim install dir, and
aborts if none of them has it.

## Layout

| File                | Covers                                                                                          |
| ------------------- | ----------------------------------------------------------------------------------------------- |
| `harness.lua`       | Shared assertions (`eq`, `ok`, `match`, `eq_list`) plus `scratch()` and `tmpfile()` helpers.       |
| `config_spec.lua`   | `config/init.lua`: DEFAULTS merge, partial overrides, `all = true`, DEFAULTS immutability.         |
| `sources_spec.lua`  | `autocmds/sources.lua`: `normalize_events`, `read_brace_block`, `parse_args`, completion, and an end-to-end scan over a temp tree. |
| `commands_spec.lua` | `commands.lua`: dispatch, feature gating, buffer/window id validation, two-level completion.        |
| `run.lua`           | Runner: resolves lib.nvim, loads each spec, reports results, sets exit code.                       |

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.match` / `H.eq_list`) and add its filename to the `specs` list in `run.lua`.

Two conventions worth keeping:

- **Stub `vim.notify` when asserting on user-facing messages**, and restore it
  in all paths (`pcall` around the body) — an unrestored stub silently breaks
  every later spec.
- **Prefer asserting on the reason, not just the effect.** `commands_spec`
  checks that an invalid id produces *"invalid window id"*, because the bug it
  guards against was a dispatch that did something plausible-looking instead of
  refusing.

## Testing the tests

A spec that cannot fail is worse than no spec. When adding one, break the code
it covers on purpose once and confirm the suite goes red. The id-validation
assertions in `commands_spec` were verified that way: with the check disabled,
`:Debug report win abc` falls back to reporting all windows, which is exactly
the regression the spec now pins down.
