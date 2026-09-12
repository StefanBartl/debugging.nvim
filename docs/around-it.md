# Around It

How debugging.nvim's scope differs from nearby plugins in the same collection.

> **[insights.nvim](https://github.com/StefanBartl/insights.nvim)** — analyses the
> codebase you are editing (symbols, imports, metrics, file tree); this one
> inspects the editor itself — buffers, windows, autocmds, messages — as it runs.
>
> **[runtime-analysis.nvim](https://github.com/StefanBartl/runtime-analysis.nvim)** —
> records what your config *does* over time (telemetry, benchmarks, stall
> detection); this one answers a single question right now, in the session where
> something is already going wrong.
>
> **[dap.nvim](https://github.com/StefanBartl/dap.nvim)** — debugs your *program*
> over the Debug Adapter Protocol. This one debugs the editor around it, with no
> adapter involved.
>
> All of the above are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Installation](installation.md#requirements).
