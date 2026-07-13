---@meta
---@module 'debugging.bindings.@types'

-- #####################################################################
-- commands.lua (registry consumed by bindings/usercmds.lua)

---@alias Dbg.ActionFn fun(args: string[]): nil

---@class Dbg.Bindings.RegistryEntry
---@field feature string                        Config.features.* key gating this category ("__always" bypasses gating)
---@field actions string[]                      Ordered action names, for completion + the overview
---@field run table<string, Dbg.ActionFn>       action name -> handler; "__default" handles free-form categories (dump, health)

return {}
