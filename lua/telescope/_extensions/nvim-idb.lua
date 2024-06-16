local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local state = require("telescope.state")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local action_set = require "telescope.actions.set"
local action_state = require "telescope.actions.state"

local idb = require("nvim-idb.idb")

local createPreview = function(bufnr, entry)
  if (entry ~= nil) then
      for k,v in ipairs(entry) do
        vim.api.nvim_buf_set_lines(bufnr, 0, k+1, false, {string.format(
          '%s, %s', v["AXLabel"], v["AXType"]
        )})
      end
    end
end

local get_tappable_items = function(opts)
  local displayer = require("telescope.pickers.entry_display").create {
        separator = " ",
        items = {
            { width = 30 },
            { width = 20 },
            { width = 30 },
            { width = 20 },
        },
    }
  local make_display = function(entry)
    return displayer {
      { entry.value.AXLabel },
      { entry.value.type },
      { entry.value.AXFrame },
      { entry.value.AXUniqueId or "Not set" }
    }
  end
  local currentPicker
  local refreshTableWithResults = function (data)
      currentPicker:refresh(finders.new_table({
          results = data,
          entry_maker = function(entry)
              -- Customize how entries are displayed
              return {
                value = entry,
                display = make_display,
                ordinal = entry.AXLabel
              }
          end
    }))
  end
  local cachedItems = idb.getInteractableElements(refreshTableWithResults)
  pickers.new(opts or {}, {
    prompt_title = "Interactable Elements",
    finder = finders.new_table {
      results = cachedItems,
      entry_maker = function(entry)
        return {
          value = entry,
          display = make_display,
          ordinal = entry.AXLabel
        }
      end,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
      currentPicker = current_picker
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection ~= nil then
          idb.tapOnElement(selection.value, function()
            idb.getInteractableElements(refreshTableWithResults)
          end)
        end
      end)
      map('i', '<c-r>', function()
        idb.getInteractableElements(refreshTableWithResults)
      end)
      return true
    end
  }):find()
end

return require("telescope").register_extension({
  exports = {
    get_elements = function(opts)
      get_tappable_items(opts)
    end
  }
})
