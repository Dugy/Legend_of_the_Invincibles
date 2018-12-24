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
					use_markup = "yes",
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

-- Show the menu that selects subsection of Item Storage: "sword", "spear", etc.
local function show_item_sorts()
	local listbox_id = "storage_listbox"
	local listbox_row = 1

	local sorts = loti.item.storage.list_sorts()
	for item_sort, count in pairs(sorts) do
		-- TODO: print human-readable translatable name of item_sort.
		local text = item_sort .. " (" .. count .. ")"

		wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")
		listbox_row = listbox_row + 1
	end
end

-- Returns human-readable description text of the item (string with Pango markup)
-- and all its special properties.
-- Optional parameter: if count>1, it will be shown that we have more than 1 of these items.
function get_item_description(item_number, count)
	local item = loti.item.type[item_number]

	local text = item.name
	if count > 1 then
		text = text .. " (" .. count .. ")"
	end

	text = text .. "\n" .. item.description

	return text
end

-- Callback that updates "Item storage" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow(unit, item_sort)
	if not item_sort then
		show_item_sorts()
		return
	end

	local listbox_id = "storage_listbox"
	local listbox_row = 1

	-- TODO: show currently equipped item (if any) and "Unequip" option
	-- TODO: show "Exit" option

	-- Show all stored items of the selected item_sort.
	local types = loti.item.storage.list_items(item_sort)
	for item_number, count in pairs(types) do
		local text = get_item_description(item_number, count)

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
