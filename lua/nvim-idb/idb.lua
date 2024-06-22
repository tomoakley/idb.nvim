local Input = require("nui.input")
local Popup = require("nui.popup")
local Timer = Popup:extend("Timer")
local event = require("nui.utils.autocmd").event

local json = require"nvim-idb.json"
local utils = require"nvim-idb.utils"
local idb = {}

local interactableCommands = {"ui tap", "ui text", "ui swipe"}
local elementsCache = {}
local simulatorDetails
local lastAction

function Timer:init(popup_options)
  local options = vim.tbl_deep_extend("force", popup_options or {}, {
    border = "double",
    relative = "editor",
    focusable = false,
    position = { row = "100%", col = "100%" },
    size = { width = 30, height = 2 },
    zindex = 100,
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:SpecialChar",
    },
  })

  Timer.super.init(self, options)
end

function Timer:countdown(time, command)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, 1, false, { "Command: "..command })

  self:mount()

  local remaining_time = time

  vim.fn.timer_start(time, function()
    remaining_time = remaining_time - time

    if remaining_time <= 0 then
      self:unmount()
    end
  end, { ["repeat"] = math.ceil(remaining_time / time) })
end

local runCommand = function(command, callback)
  utils.run_shell_command_async(command, function(data)
    local lastActionIsInteractable = false
    if command and lastAction ~= command then
      for _, cmd in pairs(interactableCommands) do
        lastActionIsInteractable = string.match(command, cmd)
        if lastActionIsInteractable then
          lastAction = command
          break
        end
      end
      if callback then
        callback(data)
      end
    end
  end)
  vim.schedule(function()
    local timer = Timer()
    timer:countdown(1500, command)
  end)
end

function idb.getInteractableElements(callback)
  runCommand("idb ui describe-all", function(data)
    local elementTable = json.parse(data[1])
    local interactableElementTypes = {"Link", "TextField", "Button"}
    local filteredElements = utils.filter(elementTable, function(key, value, table)
      local matchFound = false
      for _, allowedType in ipairs(interactableElementTypes) do
        if (value.type and value.type == allowedType) then
          matchFound = true
          break
        end
      end
      return matchFound
    end)
    elementsCache = filteredElements
    if callback then
      callback(filteredElements)
    end
  end)
  return elementsCache
end

function idb.tapOnElement(element, callback)
  if element.frame ~= nil then
    local xCoord = math.ceil(element.frame.x)
    local yCoord = math.ceil(element.frame.y)
    runCommand("idb ui tap "..xCoord.." "..yCoord, callback)
    if element.type == "TextField" then
      local input = Input({
        relative = "editor",
        position = {
          row = "50%",
          col = "50%"
        },
        zindex = 100,
        size = {
          width = 40,
        },
        border = {
          style = "single",
          text = {
            top = element.AXLabel,
            top_align = "center",
          },
        },
        win_options = {
          winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
      }, {
        prompt = "> ",
        default_value = element.AXValue, -- doesn't always show, or slow to show, existing text in prompt. Why?
        on_submit = function(value)
          -- todo: manipulate text.
            -- if the entered text deletes values in AXValue, we need to use `idb ui key 42` (backspace key code)
          -- eg if entered text appends to AXValue, we need to get the appended text and only enter that
          if value ~= element.AXValue then
            runCommand("idb ui text '"..value.."'")
          end
        end,
      })
      input:map("i", "<c-n>", function()
        local text = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
        local value = string.match(text[1], "> (%S.*)")
        if value ~= element.AXValue then
          runCommand("idb ui text '"..value.."'")
        end
        input:unmount()
        runCommand("idb ui key 40")
      end, { noremap = true })
      input:mount()
      input:on(event.BufLeave, function()
        input:unmount()
      end)
      return false
    end
    return true
  end
end

function idb.tapOnPoint()
  local input = Input({
    relative = "editor",
    position = {
      row = "50%",
      col = "50%"
    },
    zindex = 100,
    size = {
      width = 40,
    },
    border = {
      style = "single",
      text = {
        top = "X, Y",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
    prompt = "> ",
    on_submit = function(value)
      if value:find(",") then
        local patternWithSpace = "(%d+), (%d+)"
        local patternNoSpace = "(%d+),(%d+)"

        local num1, num2 = value:match(patternNoSpace)
        if not num2 then
          num1, num2 = value:match(patternWithSpace)
        end
        value = num1.." "..num2
      end
      runCommand("idb ui tap "..value)
    end,
  })
  input:mount()
  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

function idb.setLastAction(command)
  lastAction = command
end

function idb.getLastAction()
  return lastAction
end

function idb.repeatLastAction()
  if lastAction then
    utils.run_shell_command_async(lastAction)
  end
end

function idb.restartCurrentApp()
  runCommand("idb list-apps | awk -F '|' '{if ($3 == \" user \" && $5 == \" Running \") { print $1; exit } }'", function(data)
    local bundleId = data[1]
    runCommand("idb terminate "..bundleId, function()
      runCommand("idb launch "..bundleId)
    end)
  end)
end

local function scrollDown()
  utils.debounce_trailing(function()
    runCommand('idb ui swipe --duration 0.1 300 800 300 700')
  end, 500)()
end
local function scrollUp()
  utils.debounce_trailing(function()
    runCommand('idb ui swipe --duration 0.1 300 700 300 800')
  end, 500)()
end

local function swipeRight()
  runCommand("idb ui swipe --duration 0.1 0 300 500 300")
end

local function scrollToElement(element)
  local safeAreas = {59, 34}
--[[   local doesScreenHaveTabBar =
-- if the bottom of the screen (screen height - 34) has multiple bottoms along the bottom on the same y axis, can probably assume that the screen has a tab bar
--]]
end

local function getSimulatorDetailsAsync(callback)
  if not simulatorDetails then
    runCommand("idb describe --json", function(data)
      simulatorDetails = json.parse(data[1])
      callback(simulatorDetails)
    end)
  else
    callback(simulatorDetails)
  end
end

local function getSimulatorDetails()
  if simulatorDetails then
    return simulatorDetails
  else
    return nil
  end
end


local mappings = {
  { "j", scrollDown },
  { "k", scrollUp },
  { "t", idb.tapOnPoint },
  { "f", nil }, -- won't let me set in loop
  { "r", idb.restartCurrentApp },
  { "H", swipeRight },
  { ".", idb.repeatLastAction },
  { "<esc>", nil } -- can't use in loop
}

local function disableKeyMappings()
  for _, mappingAndCallback in pairs(mappings) do
    local mapping = mappingAndCallback[1]
    vim.api.nvim_del_keymap('n', mapping)
  end
end

function idb.startSession()
  local startSessionPopup = Popup({
    enter = false,
    focusable = false,
    border = {
      padding = {
        1, 1
      },
      style = "double",
    },
    relative = "editor",
    position = {
      col = "50%",
      row = "20%"
    },
    size = {
      width = 30,
      height = 7,
    },
    zindex = 10,
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  })

  getSimulatorDetailsAsync(function(data)
    local screenDimensions = data.screen_dimensions
    vim.schedule(function()
      vim.api.nvim_buf_set_lines(startSessionPopup.bufnr, 0, 1, false, {
        "Now controlling iOS Simulator.",
        "Press <esc> to return to vim.",
        "Details: ",
        data.name.." ("..data.udid..")",
        "W: "..screenDimensions.width..", H: "..screenDimensions.height,
        "Density: "..screenDimensions.density.." ("..screenDimensions.width_points.."x"..screenDimensions.height_points..")"
      })
      startSessionPopup:mount()
    end)
  end)
  idb.getInteractableElements()
  for _, mappingAndCallback in pairs(mappings) do
    local mapping = mappingAndCallback[1]
    local callback = mappingAndCallback[2]
    if callback then
      vim.keymap.set('n', mapping, callback, { noremap=true })
    end
  end
  vim.keymap.set('n', 'f', require('telescope').extensions["nvim-idb"].get_elements, { noremap=true })
  vim.keymap.set('n', '<esc>', function()
    disableKeyMappings()
    startSessionPopup:unmount()
  end, { noremap=true })
  local job_id = vim.fn.jobstart({"sim-server", "-h"}, {
    on_stdout = function(id, data)
      vim.fn.chansend(id, "touchDown 1188 252\n")
      print("stdout", vim.inspect(data), id)
      vim.fn.chansend(id, "touchUp 1188 252\n")
    end,
    on_stderr = function(id, data) print("stderr", vim.inspect(data)) end,
    on_stdin = function(id, data) print("stdin", vim.inspect(data)) end
  })
  vim.keymap.set('n', 'a', function()
    print('press a!', job_id)
    local sendTouch1 = vim.fn.chansend(job_id, "touchDown 1188 252\n")
    local sendTouch2 = vim.fn.chansend(job_id, "touchUp 1188 252\n")
    print(sendTouch1, sendTouch2)
  end, { noremap=true })
end

-- gg and G to top and bottom
-- bigger motion events (e.g 10j)
-- record and play macros?!

return idb
