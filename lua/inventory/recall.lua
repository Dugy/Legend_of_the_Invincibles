--! #textdomain "wesnoth-loti"
--
-- "Items on units on the recall list" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"

local listbox_id = "recall_listbox"
local inventory_dialog -- Set below

-- Construct tab: "items on units on the recall list".
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
					id = "recall_list_line",
					use_markup = "yes",
					text_alignment = "left",
					characters_per_line = 66
				}
			}
		}
	}

	local listbox = wml.tag.listbox {
		id = listbox_id,
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

	local view_close_buttons = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				horizontal_alignment = "left",
				wml.tag.button {
					return_value_id = "ok",
					label = _"View"
				}
			},
			wml.tag.spacer {},
			wml.tag.column {
				horizontal_alignment = "right",
				wml.tag.button {
					id = "cancel",
					label = _"Close"
				}
			}
		}
	}

	return wml.tag.grid {
		-- Row 1: header label.
		wml.tag.row {
			wml.tag.column {
				border = "bottom",
				border_size = 10,
				horizontal_alignment = "left",
				wml.tag.label {
					id = "recall_header",
					use_markup = "yes",
					label = "<span size='x-large' color='#f47a7a'>" .. _"These units on recall list have items:" .. "</span>"
				}
			}
		},

		-- Row 2: list of geared units on the Recall List.
		wml.tag.row {
			wml.tag.column {
				horizontal_grow = true,
				border = "top",
				border_size = 5,
				listbox
			}
		},

		-- Row 3: "View" and "Close" buttons.
		wml.tag.row {
			wml.tag.column {
				horizontal_grow = true,
				border = "top",
				border_size = 10,
				view_close_buttons
			}
		}
	}
end

local shown_units -- Lua array of units currently displayed in listbox

-- Callback that updates "Items on units on the recall list" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow()
	wesnoth.remove_dialog_item(1, 0, listbox_id) -- Clear the listbox

	-- List all units who have at least 1 item.
	shown_units = wesnoth.get_recall_units({ trait = "geared" })

	for listbox_line, unit in ipairs(shown_units) do
		-- Show name/type of the geared unit.
		local text = unit.name .. " <span color='#88FCA0'>(" ..
			unit.__cfg['language_name'] .. ")</span>: "

		-- List items on this unit as text.
		local items = loti.item.on_unit.list_regular(unit)
		for index, item in ipairs(items) do
			text = text .. item.name
			if index < #items then
				text = text .. ", "
			end
		end

		wesnoth.set_dialog_value(text, listbox_id, listbox_line, "recall_list_line")
	end

	-- Handler for "View" button.
	-- Shows "items on the unit" tab with another unit.
	inventory_dialog.catch_enter_or_ok(listbox_id, function(selected_index)
		inventory_dialog.current_unit = shown_units[selected_index]
		inventory_dialog.goto_tab("items_tab")
	end)

	-- Allow player to use up/down buttons without clicking on listbox.
	wesnoth.set_dialog_focus(listbox_id)
end

-- Add this tab to the dialog.

return function(provided_inventory_dialog)
	-- Place this interface into the file-scope local variable,
	-- because some code above needs inventory_dialog.goto_tab(), etc.
	inventory_dialog = provided_inventory_dialog

	inventory_dialog.add_tab {
		id = "recall_tab",
		grid = get_tab,
		onshow = onshow
	}
end
