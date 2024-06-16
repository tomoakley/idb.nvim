local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local json = require"nvim-idb.json"
local utils = require"nvim-idb.utils"
local idb = {}

local interactableCommands = {"ui tap", "ui text", "ui swipe"}
local elementsCache = {}
local lastAction

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
    print("Scrolling down")
    runCommand('idb ui swipe --duration 0.1 300 800 300 700')
  end, 500)()
end
local function scrollUp()
  utils.debounce_trailing(function()
    print("Scrolling up")
    runCommand('idb ui swipe --duration 0.1 300 700 300 800')
  end, 500)()
end

local function swipeRight()
  runCommand("idb ui swipe --duration 0.1 0 300 500 300")
end

local function disableKeyMappings()
  print("Disabling IDB mappings, returning to vim-mode")
  vim.api.nvim_del_keymap('n', 'j')
  vim.api.nvim_del_keymap('n', 'k')
  vim.api.nvim_del_keymap('n', 'f')
  vim.api.nvim_del_keymap('n', '<esc>')
end

function idb.startSession()
  print('IDB: Starting session')
  idb.getInteractableElements()
  vim.keymap.set('n', 'j', scrollDown, {noremap=true})
  vim.keymap.set('n', 'k', scrollUp, {noremap=true})
  vim.keymap.set('n', 'f', require('telescope').extensions["nvim-idb"].get_elements, {noremap=true})
  vim.keymap.set('n', 'r', idb.restartCurrentApp, {noremap=true})
  vim.keymap.set('n', 't', idb.tapOnPoint, {noremap = true})
  vim.keymap.set('n', '.', idb.repeatLastAction, {noremap = true})
  vim.keymap.set('n', 'H', swipeRight, {noremap = true})
  vim.keymap.set('n', '<esc>', disableKeyMappings, {noremap=true})
end

-- debounce scroll calls
-- make utils.run_shell_command async
  -- call the getInteractableElements when IDBSessionStart is called so when f is pressed there is some data (and then refresh)
-- ~`a` and `i` calls enter insert mode (cancel mappings in normal mode too?)~ done!
-- gg and G to top and bottom
-- press period to repeat last command (scroll, button press, etc)!
-- u to swipe back
-- bigger motion events (e.g 10j)
-- record and play macros?!

return idb
