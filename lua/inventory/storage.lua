--! #textdomain "wesnoth-loti"
--
-- "Item storage" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"
local util = wesnoth.require "./misc.lua"

-- Construct tab: "item storage".
-- Note: this only creates the widget. It gets populated with data in onshow().
-- Returns: top-level [grid] widget.
local function get_tab()
	local listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 10,
				horizontal_grow = true,
				wml.tag.label {
					id = "storage_text",
					text_alignment = "left"
				}
			}
		}
	}

	local listbox = wml.tag.listbox {
		id = "storage_listbox",
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					wml.tag.toggle_panel {
						listbox_template
					}
				}
			}
		}
	}

	return wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 15,
				wml.tag.label {
					label = _"Item storage"
				}
			}
		},
		wml.tag.row {
			wml.tag.column {
				horizontal_grow = true,
				listbox
			}
		},
		wml.tag.row {
			wml.tag.column {
				horizontal_alignment = "right",
				util.make_close_button()
			}
		}
	}
end

-- Callback that updates "Item storage" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow(unit)
	local listbox_id = "storage_listbox"

	-- Menu that selects subsection of Item Storage: "sword", "spear", etc.
	local sorts = loti.item.storage.list_sorts()
	local listbox_row = 1

	for item_sort, count in pairs(sorts) do
		-- TODO: print human-readable translatable name of item_sort.
		local text = item_sort .. " (" .. count .. ")"

		wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")
		listbox_row = listbox_row + 1
	end
end

-- Add this tab to the dialog.

return function(inventory_dialog)
	inventory_dialog.add_tab {
		id = "storage_tab",
		grid = get_tab(),
		onshow = onshow
	}
end
