--! #textdomain "wesnoth-loti"
--
-- "Item storage" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"
local util = wesnoth.require "./misc.lua"

local listbox_id = "storage_listbox"
local inventory_dialog -- Set below

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

	-- Equip button + dropdown menu with "Drop" and "Destroy" buttons
	local equip_dropdown_buttons = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.button {
					id = "equip",
					label = _"Equip"
				}
			},
			wml.tag.column {
				border = "left",
				border_size = 2,
				wml.tag.menu_button {
					id = "storage_dropdown_menu",
					definition = "dropdown_menu_thin",
					wml.tag.option {
						label = _"Drop to the ground"
					},
					wml.tag.option {
						label = _"Destroy to get a random gem"
					}
				}
			}
		}
	}

	local yesno_buttons = wml.tag.grid {
		wml.tag.row {
			-- Only one of Equip and View buttons is shown at a time.
			-- They both may be hidden when viewing units on the recall list
			-- (it's illogical for absent unit to be able to take new items)
			wml.tag.column {
				equip_dropdown_buttons
			},

			wml.tag.column {
				border = "right,left",
				border_size = 20,
				wml.tag.label {
					id = "noequip_reason"
				}
			},
			wml.tag.column {
				wml.tag.button {
					id = "view",
					label = _"View"
				}
			},
			wml.tag.spacer {},
			wml.tag.column {
				wml.tag.button {
					id = "close_storage",
					label = _"Close"
				}
			}
		}
	}

	return wml.tag.grid {
		-- Row 1: current item (this row is hidden if there is no current item)
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 5,
				wml.tag.label {
					id = "current_item",
					use_markup = "yes"
				}
			}
		},

		-- Row 2: "Unequip" button (hidden if there is no current item)
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 5,
				horizontal_alignment = "right",
				wml.tag.button {
					id = "unequip",
					label = _"Unequip"
				}
			}
		},

		-- Row 3: header of the Item Storage
		wml.tag.row {
			wml.tag.column {
				border = "top",
				border_size = 10,
				horizontal_alignment = "left",
				wml.tag.label {
					id = "storage_header"
				}
			}
		},

		-- Row 4: list of items in Item Storage
		wml.tag.row {
			wml.tag.column {
				horizontal_grow = true,
				border = "top",
				border_size = 5,
				listbox
			}
		},

		-- Row 5: "Equip" and "Close" buttons.
		wml.tag.row {
			wml.tag.column {
				horizontal_grow = true,
				border = "top",
				border_size = 10,
				yesno_buttons
			}
		}
	}
end

-- Blank tab is used in equip() to hide the Item Storage tab
-- before showing "item pick" dialog (which is semi-transparent).
local function get_blank_tab()
	return wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.spacer { width = 10, height = 10 }
			}
		}
	}
end

-- Register custom GUI widget "dropdown_menu_thin": menu_button with reduced width (for icon only).
local function register_dropdown_widget()
	local size = 25

	local function draw(button_image, arrow_image)
		return {
			wml.tag.draw {
				wml.tag.image {
					name = button_image
				},
				wml.tag.rectangle {
					w = "(width)",
					h = "(height)",
					border_thickness = 1,
					border_color = "114, 79, 46, 255"
				},
				wml.tag.image {
					name = arrow_image
				}
			}
		}
	end

	local definition = {
		id = "dropdown_menu_thin",
		description = 'Dropdown menu button with reduced width (for icon only).',

		wml.tag.resolution {
			min_width = 25,
			min_height = 25,

			default_width = size,
			default_height = size,

			wml.tag.state_enabled(draw(
				"buttons/button_dropdown/button_dropdown.png",
				"icons/arrows/short_arrow_left_25.png~ROTATE(-90)"
			)),
			wml.tag.state_disabled(draw(
				"buttons/button_dropdown/button_dropdown.png~GS()",
				"icons/arrows/short_arrow_left_25.png~ROTATE(-90)~GS()"
			)),
			wml.tag.state_pressed(draw(
				"buttons/button_dropdown/button_dropdown-pressed.png",
				"icons/arrows/short_arrow_left_25-pressed.png~ROTATE(-90)"
			)),
			wml.tag.state_focused(draw(
				"buttons/button_dropdown/button_dropdown-pressed.png",
				"icons/arrows/short_arrow_left_25-active.png~ROTATE(-90)"
			))
		}
	}

	wesnoth.add_widget_definition("menu_button", "dropdown_menu_thin", definition)
end

local listbox_row = 0
local shown_items -- Lua array of item numbers currently displayed in listbox, e.g. { 27, 34, 56}

-- Show the menu that selects subsection of Item Storage: "sword", "spear", etc.
local function show_item_sorts()
	local sorts = loti.item.storage.list_sorts()
	for item_sort, count in pairs(sorts) do
		-- TODO: print human-readable translatable name of item_sort.
		local text = item_sort .. " (" .. count .. ")"

		listbox_row = listbox_row + 1
		wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")

		-- For callback of "View" to know which item_sort was selected.
		shown_items[listbox_row] = item_sort
	end

	wesnoth.set_dialog_visible(true, listbox_id)

	-- Unhide "View" button.
	-- Hide "Equip" button and dropdown menu (not applicable).
	wesnoth.set_dialog_visible(true, "view")
	wesnoth.set_dialog_visible(false, "equip")
	wesnoth.set_dialog_visible(false, "storage_dropdown_menu")
end

-- Returns human-readable description text of the item (string with Pango markup)
-- and all its special properties.
-- Parameter "item" is an [object] tag.
-- Optional parameter: if count>1, it will be shown that we have more than 1 of these items.
function get_item_description(item, count)
	local text = "<span font-weight='bold'>" .. item.name .. "</span>"
	if count and count > 1 then
		text = text .. " (" .. count .. ")"
	end

	text = text .. "\n" .. item.description

	return text
end

-- Last shown item_sort, used in Equip/Unequip callbacks.
local shown_item_sort
local can_equip

-- Callback that updates "Item storage" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow(unit, item_sort)
	-- Clear the form. Keep the listbox hidden until populated.
	wesnoth.set_dialog_visible(false, listbox_id)
	if listbox_row > 0 then
		wesnoth.remove_dialog_item(1, 0, listbox_id)
		listbox_row = 0
	end

	-- Hide optional widgets until we know that they are needed.
	wesnoth.set_dialog_visible(false, "current_item")
	wesnoth.set_dialog_visible(false, "unequip")
	wesnoth.set_dialog_visible(false, "view")
	wesnoth.set_dialog_visible(false, "noequip_reason")

	-- Record things that will be needed in Equip/Unequip callbacks.
	shown_item_sort = item_sort
	shown_items = {}

	if not item_sort then
		return show_item_sorts()
	end

	-- Remember whether the items of this sort can be equipped.
	can_equip = true
	if not loti_util_list_equippable_sorts(unit.type)[item_sort] then
		can_equip = false
	end

	-- Display currently equipped item (if any)
	local item = loti.item.on_unit.find(unit, item_sort)
	if item then
		local text = _"Currently equipped: " .. get_item_description(item)
		wesnoth.set_dialog_value(text, "current_item")

		-- Show/hide fields related to current item
		wesnoth.set_dialog_visible(true, "current_item")
		wesnoth.set_dialog_visible(true, "unequip")
	end

	-- Show all stored items of the selected item_sort.
	local types = loti.item.storage.list_items(item_sort)
	for item_number, count in pairs(types) do
		listbox_row = listbox_row + 1

		local text = get_item_description(loti.item.type[item_number], count)
		wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")

		-- For callback of "Equip" to know which item was selected.
		shown_items[listbox_row] = item_number
	end

	-- Hide Equip button for: a) empty storage, b) unit on recall list,
	-- c) when viewing items that can't be equipped by current unit.
	local empty = not shown_items[1]
	local present = unit.valid ~= "recall"

	wesnoth.set_dialog_visible(not empty and present and can_equip, "equip")
	wesnoth.set_dialog_visible(not empty and present, "storage_dropdown_menu")

	-- Show explanation why Equip is not available.
	local pronoun = _"he"
	if unit.__cfg.gender == "female" then
		pronoun = _"she"
	end

	if not present then
		wesnoth.set_dialog_value(
			_"This unit is currently not on the battlefield,\nso " .. pronoun ..
			_" can't take new items from the storage.",
			"noequip_reason")
		wesnoth.set_dialog_visible(true, "noequip_reason")
	elseif not can_equip then
		wesnoth.set_dialog_value(
			_"This unit can't equip such items.\n" ..
			_"They are unworthy of a mighty " .. unit.__cfg['language_name'] .. ".",
			"noequip_reason")
		wesnoth.set_dialog_visible(true, "noequip_reason")
	end

	if empty then
		wesnoth.set_dialog_value(_"Item storage is empty.", "storage_header")
	else
		wesnoth.set_dialog_value(_"In the item storage:", "storage_header")

		-- Unhide the listbox. Note: it's good for performance to show the listbox only
		-- when it's completely populated (i.e. here), so that
		-- it won't be unnecessarily redrawn on every set_dialog_value().
		wesnoth.set_dialog_visible(true, listbox_id)
	end
end

-- Unequip the current item. Doesn't ask any questions. Doesn't leave the Storage tab.
-- Used in equip() and unequip().
local function unequip_internal()
	local unit = inventory_dialog.current_unit
	local item = loti.item.on_unit.find(unit, shown_item_sort)

	if item then
		inventory_dialog.mpsafety:queue({
			command = "unequip",
			unit = unit,
			number = item.number,
			sort = item.sort
		})
	end
end

-- Handler for the "Unequip" button.
local function unequip()
	if not can_equip then
		-- Leftover item. Warn that this item can't be re-equipped.
		local are_you_sure = "<span size='x-large'>" .. _"WARNING:" .. "</span> " ..
			_"this item is purely nostalgic (from the good old times when this unit needed it).\n" ..
			_"If you unequip it, this unit won't be able to equip it again.\n\n" ..
			_"Do you still want to unequip it?"

		if not wesnoth.confirm(are_you_sure) then
			return
		end
	end

	unequip_internal()
	inventory_dialog.goto_tab("items_tab")
end

-- Determine selected element of the listbox.
-- Used in handlers of "Equip" and "View" buttons.
local function get_selected_item()
	local selected_index = wesnoth.get_dialog_value(listbox_id)
	return shown_items[selected_index]
end

-- Handler for "Equip" button.
local function equip()
	-- Unequip the currently equipped item of the same sort (if any).
	-- For example, if we are equipping a new sword, then unequip the old sword.
	unequip_internal()

	-- Remove new item from storage and give it to the current unit.
	inventory_dialog.mpsafety:queue({
		command = "equip",
		unit = inventory_dialog.current_unit,
		number = get_selected_item(),
		sort = shown_item_sort
	})
	inventory_dialog.goto_tab("items_tab")
end

-- Handler for "Drop to the ground" button.
local function drop_item()
	-- Remove item from storage and place it on the ground.
	inventory_dialog.mpsafety:queue({
		command = "drop",
		unit = inventory_dialog.current_unit, -- Only for coordinates where to drop
		number = get_selected_item(),
		sort = shown_item_sort
	})
	inventory_dialog.goto_tab("items_tab")
end

-- Handler for "Destroy to get a random gem" button.
local function destroy_item()
	-- Remove item from storage, add 1 random gem.
	local gem = loti.gem.random()
	inventory_dialog.mpsafety:queue({
		command = "destroy",
		number = get_selected_item(),
		sort = shown_item_sort,
		gem = gem
	})

	-- Tell player which gem was picked.
	-- TODO: double-check that this doesn't cause OoS.
	-- (this object is removed by the next update_stats() and doesn't affect anything, but still...)
	wesnoth.wml_actions.object(loti.item.type[520 + gem])
	inventory_dialog.goto_tab("items_tab")
end

-- Add this tab to the dialog.

return function(provided_inventory_dialog)
	-- Place this interface into the file-scope local variable,
	-- because some code above needs inventory_dialog.goto_tab(), etc.
	inventory_dialog = provided_inventory_dialog

	inventory_dialog.add_tab {
		id = "storage_tab",
		grid = get_tab(),
		onshow = onshow
	}

	inventory_dialog.add_tab {
		id = "blank_tab",
		grid = get_blank_tab(),
		onshow = function() end
	}

	-- Widget for dropdown menu button.
	inventory_dialog.register_widgets(register_dropdown_widget)

	inventory_dialog.install_callbacks(function()
		-- Callback for Equip/Unequip buttons.
		wesnoth.set_dialog_callback(unequip, "unequip")
		wesnoth.set_dialog_callback(equip, "equip")

		-- Callback for View button (shown in the menu of all item sorts,
		-- navigates to specific section of Item Storage, e.g. "polearm").
		wesnoth.set_dialog_callback(function()
			inventory_dialog.goto_tab("storage_tab", get_selected_item())
		end, "view")

		-- Callback for "Close" button.
		wesnoth.set_dialog_callback(
			function() inventory_dialog.goto_tab("items_tab") end,
			"close_storage"
		)

		-- Handler for dropdown menu actions: "Drop item" and "Destroy item".
		wesnoth.set_dialog_callback(function()
			-- Note: value of the "dropdown menu" widget with only 2 items
			-- is false for option #1 and true for option #2.
			if not wesnoth.get_dialog_value("storage_dropdown_menu") then
				-- First option on the menu
				drop_item()
			else
				-- Second option in the menu
				destroy_item()
			end
		end, "storage_dropdown_menu")
	end)
end
