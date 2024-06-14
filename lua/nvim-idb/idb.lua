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

return idb
