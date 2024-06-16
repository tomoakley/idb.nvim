local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local json = require"nvim-idb.json"
local utils = require"nvim-idb.utils"
local idb = {}

local elementsCache = {}


function idb.getInteractableElements(callback)
  utils.run_shell_command_async("idb ui describe-all", function(data)
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
    utils.run_shell_command_async("idb ui tap "..xCoord.." "..yCoord, callback)
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
            utils.run_shell_command_async("idb ui text '"..value.."'")
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

function idb.restartCurrentApp()
  utils.run_shell_command_async("idb list-apps | awk -F '|' '{if ($3 == \" user \" && $5 == \" Running \") { print $1; exit } }'", function(data)
    local bundleId = data[1]
    utils.run_shell_command_async("idb terminate "..bundleId, function()
      utils.run_shell_command_async("idb launch "..bundleId)
    end)
  end)
end

local function scrollDown()
  utils.debounce_trailing(function()
    utils.run_shell_command_async('idb ui swipe --duration 0.1 300 800 300 700')
  end, 500)()
end
local function scrollUp()
  utils.debounce_trailing(function()
    print("Scrolling up")
    utils.run_shell_command_async('idb ui swipe --duration 0.1 300 700 300 800')
  end, 500)()
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
