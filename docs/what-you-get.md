# What You Get With the Defaults

`opts = {}` enables every category whose prerequisites are present. The ones
worth knowing on day one:

| Command | Does |
| --- | --- |
| `:Debug` | Overview of the categories your setup has enabled |
| `:Debug messages show` | An auto-refreshing `:messages` window you can leave open |
| `:Debug messages capture` | The same content to a file and the clipboard |
| `:Debug autocmds runtime BufEnter *` | The live registry, for one event and pattern |
| `:Debug autocmds all` | Registry versus what the source claims to register, plus the diff |
| `:Debug report buf` | Every buffer, with its options and state |
| `:Debug dump my_global` | A recursive dump of a Lua value, or the word under the cursor |
| `:Debug proc start 200` | Log every `system()`/`jobstart` call over 200 ms |
| `:Debug module reload` | Reload the current buffer's Lua module without restarting |
| `:Debug health` | `:checkhealth debugging` |

The full two-level surface is [commands.md](commands.md); every key and
autocommand is in the [bindings cheatsheet](BINDINGS.md).
