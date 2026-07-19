-- docs/TESTS/startup_spec.lua
-- Covers the pure --startuptime log parser behind `:Debug performance startup`
-- (debugging.tools.startup.parse).

return function(H)
  local startup = require("debugging.tools.startup")

  -- A representative --startuptime log: a header, the "NVIM STARTED" total
  -- line, and three "sourcing" lines with a self-time third column.
  local log = {
    "times in msec",
    " clock   self+sourced   self:  sourced script",
    "000.006  000.006: --- NVIM STARTING ---",
    "010.100  002.500  002.500: sourcing /cfg/slow.lua",
    "012.200  000.400  000.400: sourcing /cfg/fast.lua",
    "045.121  005.000  005.000: sourcing /cfg/slowest.lua",
    "120.500  120.500: --- NVIM STARTED ---",
  }

  local total, entries = startup.parse(log)

  -- Total comes from the "NVIM STARTED" clock, not the max sourcing clock.
  H.eq(total, 120.5, "parse: total from NVIM STARTED line")

  -- Only the three-column "sourcing" lines become entries.
  H.eq(#entries, 3, "parse: one entry per sourced script")

  -- Entries are sorted by self time, slowest first.
  H.eq(entries[1].self_ms, 5.0, "parse: slowest script first")
  H.match(entries[1].event, "slowest", "parse: slowest entry keeps its label")
  H.eq(entries[#entries].self_ms, 0.4, "parse: fastest script last")

  -- With no "NVIM STARTED" line, the total falls back to the max clock seen.
  local total2 = startup.parse({
    "000.010  000.010: event init",
    "050.000  001.000  001.000: sourcing /x.lua",
  })
  H.eq(total2, 50.0, "parse: total falls back to max clock")

  -- Header / non-numeric lines are ignored rather than parsed as entries.
  local _, only = startup.parse({ "times in msec", " clock   self:  sourced script" })
  H.eq(#only, 0, "parse: header lines yield no entries")
end
