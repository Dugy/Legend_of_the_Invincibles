--! #textdomain "wesnoth-loti"
--
-- "Item storage" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"
local util = wesnoth.require "./misc.lua"

local listbox_id = "storage_listbox"
local inventory_dialog -- Set below

local override_unequippability = {}

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
					label = _"Equip",
					return_value_id = "ok"
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
					label = _"View",
					return_value_id = "ok"
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

-- Check if the scenario has progressed enough to disable unstoring items
local function is_too_progressed()
	local unit = inventory_dialog.current_unit
	local terrain = wesnoth.get_terrain(unit.x, unit.y)
	if string.sub(terrain, 1, 1) == "C" or string.sub(terrain, 1, 1) == "K" then
		return false
	end

	if wesnoth.get_variable("turn_number") <= 2 then
		return false
	end

	return true
end

-- Unhide the main listbox and focus on it.
-- Explain absence of listbox when Item Storage is empty.
-- Note: it's good for performance for listbox to be hidden until completely populated,
-- so that it won't be unnecessarily redrawn on every set_dialog_value().
local function unhide_listbox()
	if not shown_items[1] then
		if is_too_progressed() then
			wesnoth.set_dialog_value(_"Cannot access item storage after turn 2 outside a castle.", "storage_header")
		else
			wesnoth.set_dialog_value(_"Item storage is empty.", "storage_header")
		end
		return
	end

	wesnoth.set_dialog_value(_"In the item storage:", "storage_header")

	-- Unhide/focus.
	wesnoth.set_dialog_visible(true, listbox_id)
	wesnoth.set_dialog_focus(listbox_id)
end

-- Show the menu that selects subsection of Item Storage: "sword", "spear", etc.
local function show_item_sorts()
	local sorts = loti.item.storage.list_sorts()
	local too_progressed = is_too_progressed()
	for item_sort, count in pairs(sorts) do
		if not too_progressed or item_sort == "potion" or item_sort == "limited" then
			-- TODO: print human-readable translatable name of item_sort.
			local text = item_sort .. " (" .. count .. ")"

			listbox_row = listbox_row + 1
			wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")

			-- For callback of "View" to know which item_sort was selected.
			shown_items[listbox_row] = item_sort
		end
	end

	-- Listbox is completely populated, can show it now.
	unhide_listbox()

	-- Unhide "View" button.
	local empty = not shown_items[1]
	wesnoth.set_dialog_visible(not empty, "view")

	-- Hide "Equip" button and dropdown menu (not applicable).
	wesnoth.set_dialog_visible(false, "equip")
	wesnoth.set_dialog_visible(false, "storage_dropdown_menu")

	-- Handler for View button (shown in the menu of all item sorts,
	-- navigates to specific section of Item Storage, e.g. "polearm").
	if not empty then
		inventory_dialog.catch_enter_or_ok(listbox_id, function(selected_index)
			inventory_dialog.goto_tab("storage_tab", shown_items[selected_index])
		end)
	end
end

-- Returns human-readable description text of the item (string with Pango markup)
-- and all its special properties.
-- Parameter "item" is an [object] tag.
-- Optional parameter: if count>1, it will be shown that we have more than 1 of these items.
-- Optional parameter: set_items is an array of item numbers of all currently equipped items (used to show active set bonuses).
function get_item_description(item, count, set_items)
	local text = "<span font-weight='bold'>" .. item.name .. "</span>"
	if count and count > 1 then
		text = text .. " (" .. count .. ")"
	end

	text = text .. "\n" .. loti.item.describe_item(item.number, item.sort, set_items)

	return text
end

-- Last shown item_sort, used in Equip/Unequip callbacks.
local shown_item_sort
local type_is_equippable

-- Unequip the current item. Doesn't ask any questions. Doesn't leave the Storage tab.
-- Used in equip() and unequip().
local function unequip_internal()
	local unit = inventory_dialog.current_unit
	local item = loti.item.on_unit.find(unit, shown_item_sort)

	if item and not string.match(item.sort, "potion") then
		inventory_dialog.mpsafety:queue({
			command = "unequip",
			unit = unit,
			number = item.number,
			sort = item.sort
		})
	end
end

-- Handler for "Equip" button.
local function equip(item_number)
	-- Unequip the currently equipped item of the same sort (if any).
	-- For example, if we are equipping a new sword, then unequip the old sword.
	unequip_internal()

	-- Remove new item from storage and give it to the current unit.
	inventory_dialog.mpsafety:queue({
		command = "equip",
		unit = inventory_dialog.current_unit,
		number = item_number,
		sort = shown_item_sort
	})
	inventory_dialog.goto_tab("items_tab")
end

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
	type_is_equippable = true
	if not loti_util_list_equippable_sorts(unit)[item_sort] then
		type_is_equippable = false
	end

	-- Calculate an array of currently equipped items,
	-- so that get_item_description() could show "item set" bonuses.
	local set_items = loti.unit.list_unit_item_numbers(unit.__cfg)

	-- Display currently equipped item (if any)

	local item = loti.item.on_unit.find(unit, item_sort)
	if item then
		local text = _"Currently equipped: " .. get_item_description(item, 1, set_items)
		wesnoth.set_dialog_value(text, "current_item")

		-- Show/hide fields related to current item
		wesnoth.set_dialog_visible(true, "current_item")
		wesnoth.set_dialog_visible(true, "unequip")
	end

	-- Show all stored items of the selected item_sort.
	if not is_too_progressed() or item_sort == "potion" or item_sort == "limited" then
		local types = loti.item.storage.list_items(item_sort)
		for item_number, count in pairs(types) do
			listbox_row = listbox_row + 1

			local text = get_item_description(loti.item.type[item_number], count, set_items)
			wesnoth.set_dialog_value(text, listbox_id, listbox_row, "storage_text")

			-- For callback of "Equip" to know which item was selected.
			shown_items[listbox_row] = item_number
		end
	end

	-- Hide Equip button for: a) empty storage, b) unit on recall list,
	-- c) when viewing items that can't be equipped by current unit.
	local empty = not shown_items[1]
	local present = unit.valid ~= "recall"

	-- True if Equip operation is allowed, false otherwise.
	local can_equip = not empty and present and type_is_equippable or override_unequippability[item_sort] == true

	wesnoth.set_dialog_visible(can_equip, "equip")
	if string.match(item_sort, "potion") then
		wesnoth.set_dialog_value("Use", "equip")
	else
		wesnoth.set_dialog_value("Equip", "equip")
	end
	wesnoth.set_dialog_visible(not empty and present, "storage_dropdown_menu")

	if can_equip then
		-- Handler for Equip button.
		inventory_dialog.catch_enter_or_ok(listbox_id, function(selected_index)
			equip(shown_items[selected_index])
		end)
	elseif not present then
		-- Explain that Equip is not allowed for units on recall list.
		local pronoun = _"he"
		if unit.__cfg.gender == "female" then
			pronoun = _"she"
		end

		wesnoth.set_dialog_value(
			_"This unit is currently not on the battlefield,\nso " .. pronoun ..
			_" can't take new items from the storage.",
			"noequip_reason")
		wesnoth.set_dialog_visible(true, "noequip_reason")
	elseif not type_is_equippable then
		-- Explain that Equip is not allowed because this is a wrong type of weapon.
		wesnoth.set_dialog_value(
			_"This unit can't equip such items.\n" ..
			_"They are unworthy of a mighty " .. unit.__cfg['language_name'] .. ".",
			"noequip_reason")
		wesnoth.set_dialog_visible(true, "noequip_reason")
	end

	-- Listbox is completely populated, can show it now.
	unhide_listbox()
end

-- Handler for the "Unequip" button.
local function unequip()
	if not type_is_equippable then
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
	inventory_dialog.catch_enter_or_ok(listbox_id, function() end)
	inventory_dialog.goto_tab("items_tab")
end

-- Determine selected element of the listbox.
-- Used in handlers of "Equip" and "View" buttons.
local function get_selected_item()
	local selected_index = wesnoth.get_dialog_value(listbox_id)
	return shown_items[selected_index]
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
	local item = loti.item.type[520 + gem]
	wesnoth.show_popup_dialog(item.name, item.description, item.image)

	inventory_dialog.goto_tab("items_tab")
end

-- Add this tab to the dialog.

return function(provided_inventory_dialog)
	-- Place this interface into the file-scope local variable,
	-- because some code above needs inventory_dialog.goto_tab(), etc.
	inventory_dialog = provided_inventory_dialog

	inventory_dialog.add_tab {
		id = "storage_tab",
		grid = get_tab,
		onshow = onshow
	}

	inventory_dialog.add_tab {
		id = "blank_tab",
		grid = get_blank_tab,
		onshow = function() end
	}

	-- Widget for dropdown menu button.
	inventory_dialog.register_widgets(register_dropdown_widget)

	loti.config = loti.config or {}
	if not loti.config.inventory then loti.config.inventory = {} end
	local overrides = loti.config.inventory
	overrides.override_unequippability = override_unequippability

	inventory_dialog.install_callbacks(function()
		-- Callback for Unequip button.
		wesnoth.set_dialog_callback(overrides.unequip or unequip, "unequip")

		-- Callback for "Close" button.
		wesnoth.set_dialog_callback(
			function() 
				inventory_dialog.catch_enter_or_ok(listbox_id, function() end)
				if overrides.close_storage then
					overrides.close_storage()
				else
					inventory_dialog.goto_tab("items_tab")
				end
			end,
			"close_storage"
		)

		-- Handler for dropdown menu actions: "Drop item" and "Destroy item".
		wesnoth.set_dialog_callback(function()
			-- Note: value of the "dropdown menu" widget with only 2 items
			-- is false for option #1 and true for option #2.
			if not wesnoth.get_dialog_value("storage_dropdown_menu") then
				-- First option on the menu
				if overrides.drop_item then
					overrides.drop_item()
				else
					drop_item()
				end
			else
				-- Second option in the menu
				if overrides.destroy_item then
					overrides.destroy_item()
				else
					destroy_item()
				end
			end
		end, "storage_dropdown_menu")
	end)
end
