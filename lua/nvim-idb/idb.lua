local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

local json = require"nvim-idb.json"
local idb = {}

local run_shell_command = function(command)
  local handle = io.popen(command, "r") -- Open the process for reading
  local result = handle:read("*a") -- Read all output from the process
  handle:close() -- Close the process handle
  return result -- Return the output of the command
end

local filter = function(t, filterFunc)
    local out = {}
    for k, v in pairs(t) do
        if filterFunc(k, v, t) then
            out[#out + 1] = v
        end
    end
    return out
end

function idb.getInteractableElements()
  local uiElements = run_shell_command("idb ui describe-all")
  local elementTable = json.parse(uiElements)
  local interactableElementTypes = {"Link", "TextField", "Button"}
  local filteredElements = filter(elementTable, function(key, value, table)
    local matchFound = false
    for _, allowedType in ipairs(interactableElementTypes) do
      if (value.type and value.type == allowedType) then
        matchFound = true
        break
      end
    end
    return matchFound
  end)
  return filteredElements
end

function idb.tapOnElement(element)
  if element.frame ~= nil then
    local xCoord = math.ceil(element.frame.x)
    local yCoord = math.ceil(element.frame.y)
    run_shell_command("idb ui tap "..xCoord.." "..yCoord)
    if element.type == "TextField" then
      print(element.AXValue)
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
            run_shell_command("idb ui text '"..value.."'")
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
  local bundleId = run_shell_command("idb list-apps | awk -F '|' '{if ($3 == \" user \" && $5 == \" Running \") { print $1; exit } }'")
  run_shell_command("idb terminate "..bundleId)
  run_shell_command("idb launch "..bundleId)
end

local function scrollDown()
  print('IDB: Scrolling down')
  run_shell_command('idb ui swipe --duration 0.1 300 800 300 700')
end
local function scrollUp()
  print('IDB: Scrolling up')
  run_shell_command('idb ui swipe --duration 0.1 300 700 300 800')
end

local function disableKeyMappings()
  print("Disabling IDB mappings, returning to vim-mode")
  vim.api.nvim_del_keymap('n', 'j')
  vim.api.nvim_del_keymap('n', 'k')
  vim.api.nvim_del_keymap('n', 'f')
  vim.api.nvim_del_keymap('n', '<esc>')
end

function idb.startSession()
  print('starting idb scroll session')
  vim.keymap.set('n', 'j', scrollDown, {noremap=true})
  vim.keymap.set('n', 'k', scrollUp, {noremap=true})
  vim.keymap.set('n', 'f', require('telescope').extensions["nvim-idb"].get_elements, {noremap=true})
  vim.keymap.set('n', 'r', idb.restartCurrentApp, {noremap=true})
  vim.keymap.set('n', '<esc>', disableKeyMappings, {noremap=true})
end

-- debounce scroll calls
-- make run_shell_command async
  -- call the getInteractableElements when IDBSessionStart is called so when f is pressed there is some data (and then refresh)
-- ~`a` and `i` calls enter insert mode (cancel mappings in normal mode too?)~ done!
-- gg and G to top and bottom
-- press period to repeat last command (scroll, button press, etc)!
-- u to swipe back
-- bigger motion events (e.g 10j)
-- record and play macros?!

return idb
