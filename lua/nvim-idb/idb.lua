local json = require"nvim-idb.json"
local idb = {}

local run_shell_command = function(command)
  local handle = io.popen(command, "r") -- Open the process for reading
  local result = handle:read("*a") -- Read all output from the process
  handle:close() -- Close the process handle
  return result -- Return the output of the command
end

function idb.getInteractableElements()
  local uiElements = run_shell_command("idb ui describe-all")
  return json.parse(uiElements)
end

function idb.tapOnElement(element)
  print(vim.inspect(element))
  local xCoord = math.ceil(element.frame.x)
  local yCoord = math.ceil(element.frame.y)
  run_shell_command("idb ui tap "..xCoord.." "..yCoord)
end

return idb
