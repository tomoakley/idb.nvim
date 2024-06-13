local previewers = require("telescope.previewers")
local ts_utils = require "telescope.utils"
local defaulter = ts_utils.make_default_callable

local workflow = defaulter(function(opts)
  return previewers.new_buffer_previewer{
    title = 'On screen elements',
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,
    define_preview = function(self, entry)
      print(entry)
      local bufnr = self.state.bufnr
    end,
  }
end)

return {
  workflow = workflow
}
