---@module 'debugging.views.debug_helper'
---Diagnostic helper for debugging message capture issues

local notify = require("lib.nvim.notify").create("[debugging.views.debug_helper]")

local M = {}

---Check Noice availability and configuration
---@return table status
function M.check_noice()
  local status = {
    installed = false,
    manager_available = false,
    history_available = false,
    api_available = false,
    buffers_found = 0,
    message_count = 0,
    sample_messages = {},
  }

  local ok, noice = pcall(require, "noice")
  if not ok then
    return status
  end

  status.installed = true

  -- Check manager and get sample messages
  local ok_manager, manager = pcall(require, "noice.message.manager")
  if ok_manager and manager then
    status.manager_available = true
    local ok_msgs, messages = pcall(manager.get, nil, { history = true })
    if ok_msgs and messages then
      status.message_count = #messages

      -- Get first 3 messages as samples
      for i = 1, math.min(3, #messages) do
        local msg = messages[i]
        local sample = {
          has_content = msg.content ~= nil,
          content_type = type(msg.content),
          has_message = msg.message ~= nil,
          has_text = msg.text ~= nil,
          has__text = msg._text ~= nil,
          has__lines = msg._lines ~= nil,
          _lines_type = type(msg._lines),
          _lines_count = 0,
          _lines_sample = nil,
          keys = {},
        }

        -- Check _lines content
        if msg._lines and type(msg._lines) == "table" then
          sample._lines_count = #msg._lines
          if msg._lines[1] then
            -- Show structure of first line
            local line = msg._lines[1]
            if type(line) == "table" then
              sample._lines_sample = {
                type = "table",
                length = #line,
                first_part = line[1] and {
                  type = type(line[1]),
                  has__text = type(line[1]) == "table" and line[1]._text ~= nil,
                  _text_value = type(line[1]) == "table" and line[1]._text,
                } or nil
              }
            elseif type(line) == "string" then
              sample._lines_sample = {
                type = "string",
                value = line:sub(1, 50)
              }
            end
          end
        end

        -- Collect all keys
        for k, _ in pairs(msg) do
          table.insert(sample.keys, k)
        end

        table.insert(status.sample_messages, sample)
      end
    end
  end

  -- Check history
  if noice.history and type(noice.history.get) == "function" then
    status.history_available = true
  end

  -- Check API
  if noice.api and noice.api.status and noice.api.status.message then
    status.api_available = true
  end

  -- Check buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local ok_name, name = pcall(vim.api.nvim_buf_get_name, buf)
      if ok_name and name:match("noice://") then
        status.buffers_found = status.buffers_found + 1
      end
    end
  end

  return status
end

---Check if standard :messages works
---@return table status
function M.check_messages()
  local status = {
    execute_works = false,
    execute_content = "",
    exec2_works = false,
    exec2_content = "",
  }

  -- Try vim.fn.execute
  local ok, result = pcall(vim.fn.execute, "messages")
  if ok and result then
    status.execute_works = true
    status.execute_content = result
  end

  -- Try nvim_exec2
  local ok2, result2 = pcall(vim.api.nvim_exec2, "messages", { output = true })
  if ok2 and result2 and result2.output then
    status.exec2_works = true
    status.exec2_content = result2.output
  end

  return status
end

---Print comprehensive diagnostic report
function M.report()
  print("\n" .. string.rep("=", 60))
  print("DEBUGGING.VIEWS DIAGNOSTIC REPORT")
  print(string.rep("=", 60))

  -- Check Noice
  print("\n📦 NOICE STATUS:")
  local noice_status = M.check_noice()
  print(string.format("  Installed: %s", noice_status.installed and "✓" or "✗"))
  if noice_status.installed then
    print(string.format("  Manager: %s", noice_status.manager_available and "✓" or "✗"))
    print(string.format("  History: %s", noice_status.history_available and "✓" or "✗"))
    print(string.format("  API: %s", noice_status.api_available and "✓" or "✗"))
    print(string.format("  Buffers: %d", noice_status.buffers_found))
    print(string.format("  Messages: %d", noice_status.message_count))

    -- Show sample message structure
    if #noice_status.sample_messages > 0 then
      print("\n  Sample Message Structure:")
      for i, sample in ipairs(noice_status.sample_messages) do
        print(string.format("    Message #%d:", i))
        print(string.format("      content: %s (type: %s)",
          tostring(sample.has_content), sample.content_type))
        print(string.format("      _lines: %s (count: %d)",
          tostring(sample.has__lines), sample._lines_count))

        if sample._lines_sample then
          print("      _lines[1] structure:")
          if sample._lines_sample.type == "table" then
            print(string.format("        type: table, length: %d", sample._lines_sample.length))
            if sample._lines_sample.first_part then
              print(string.format("        [1] type: %s", sample._lines_sample.first_part.type))
              if sample._lines_sample.first_part.has__text then
                print(string.format("        [1]._text: %s",
                  vim.inspect(sample._lines_sample.first_part._text_value):sub(1, 50)))
              end
            end
          else
            print(string.format("        type: %s", sample._lines_sample.type))
            if sample._lines_sample.value then
              print(string.format("        value: %s", sample._lines_sample.value))
            end
          end
        end

        if #sample.keys > 0 then
          print("      keys: " .. table.concat(sample.keys, ", "))
        end
      end
    end
  end

  -- Check Messages
  print("\n📝 MESSAGES STATUS:")
  local msg_status = M.check_messages()
  print(string.format("  vim.fn.execute: %s", msg_status.execute_works and "✓" or "✗"))
  if msg_status.execute_works then
    local line_count = select(2, msg_status.execute_content:gsub("\n", "\n"))
    print(string.format("    Lines: %d", line_count + 1))
    print(string.format("    Bytes: %d", #msg_status.execute_content))
  end

  print(string.format("  nvim_exec2: %s", msg_status.exec2_works and "✓" or "✗"))
  if msg_status.exec2_works then
    local line_count = select(2, msg_status.exec2_content:gsub("\n", "\n"))
    print(string.format("    Lines: %d", line_count + 1))
    print(string.format("    Bytes: %d", #msg_status.exec2_content))
  end

  -- Check Paths
  print("\n📁 PATHS:")
  local capture = require("debugging.views.capture")
  print(string.format("  base_dir: %s", capture.base_dir))
  local dir, _ = capture.base_dir, capture.base_dir .. "/test.log"
  print(string.format("  dir exists: %s", vim.fn.isdirectory(dir) == 1 and "✓" or "✗"))

  -- Platform
  print("\n💻 PLATFORM:")
  local uname = (vim.uv or vim.loop).os_uname()
  if uname then
    print(string.format("  System: %s", uname.sysname))
    print(string.format("  Release: %s", uname.release or "unknown"))
  end
  local sep = package.config:sub(1, 1)
  print(string.format("  Path separator: %s", sep == "\\" and "Windows (\\)" or "Unix (/)"))

  print("\n" .. string.rep("=", 60))
  print("Next steps:")
  print("  1. :lua require('debugging.views.debug_helper').test_capture()")
  print("  2. :DebugMessagesCapture")
  print(string.rep("=", 60) .. "\n")
end

---Test capture with detailed output
function M.test_capture()
  -- Add some test messages first
  vim.notify("Test message 1", vim.log.levels.INFO)
  notify.warn("Test message 2")
  notify.error("Test message 3")

  print("\n" .. string.rep("=", 60))
  print("TESTING CAPTURE (added 3 test messages)")
  print(string.rep("=", 60))

  -- Try capture with debug
  local capture = require("debugging.views.capture")
  local ok, content = capture.capture_messages({
    debug = true,
    clipboard = false,  -- Don't spam clipboard during test
    save_file = true,
  })

  if ok and content then
    print(string.format("\n✓ Capture succeeded"))
    print(string.format("  Content length: %d bytes", #content))
    print(string.format("  First 200 chars:\n%s", content:sub(1, 200)))
  else
    print("\n✗ Capture failed")
  end

  print(string.rep("=", 60) .. "\n")
end

return M
