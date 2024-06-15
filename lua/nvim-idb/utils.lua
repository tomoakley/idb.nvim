local plenary = require('plenary')

local M = {}

local DEBOUNCE_DELAY = 600 -- Adjust the delay as needed
if not table.unpack then
    table.unpack = unpack
end
local function td_validate(fn, ms)
	vim.validate{
		fn = { fn, 'f' },
		ms = {
			ms,
			function(ms)
				return type(ms) == 'number' and ms > 0
			end,
			"number > 0",
		},
	}
end

function M.debounce_trailing(fn, ms, first)
  td_validate(fn, ms)
  local timer = vim.loop.new_timer()
  local timeoutId
  local wrapped_fn

  function wrapped_fn(...)
    local argv = {...}
    local argc = select('#', ...)
    if not timeoutId then
      pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      timeoutId = 1
      return
    end

    timeoutId = timer:start(ms, 0, function()
      pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      timeoutId = nil
    end)
  end
  return wrapped_fn
end

function M.run_shell_command(command)
  print("running shell command")
  local handle = io.popen(command, "r") -- Open the process for reading
  local result = handle:read("*a") -- Read all output from the process
  handle:close() -- Close the process handle
  print("completed shell command")
  return result -- Return the output of the command
end

function M.run_shell_command_async(command, callback)
  plenary.job:new({
    command = "sh",
    args = {'-c', command},
    on_exit = function(j, return_val)
      if callback then
        callback(j:result(), return_val)
      end
    end
  }):start()
end

function M.filter(t, filterFunc)
    local out = {}
    for k, v in pairs(t) do
        if filterFunc(k, v, t) then
            out[#out + 1] = v
        end
    end
    return out
end

return M
