# Quickstart

Ask `:Debug` what it can do — the completion is the catalogue:

```vim
:Debug <Tab>
```

Then pick a category and an action:

```vim
:Debug messages show       " the :messages window, auto-refreshing
:Debug autocmds all        " combined sources-vs-runtime view, and the diff
:Debug report buf          " buffer report
:Debug proc start 200      " log every system()/jobstart call over 200ms
```

Verify your setup any time with:

```vim
:checkhealth debugging
```

The full two-level surface is in [commands.md](commands.md); the same surface
written up as prose, with the reasoning behind each part, is in
[FEATURES/](FEATURES/README.md).
