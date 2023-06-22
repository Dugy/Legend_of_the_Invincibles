--! #textdomain "wesnoth-loti"
--
-- "Item storage" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"

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

	-- Equip button + dropdown menu with "Drop" and "Destroy" buttons (for item in storage)
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

	-- Unequip button + dropdown menu with "Drop" and "Destroy" buttons (for item on unit)
	local unequip_dropdown_buttons = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.button {
					id = "unequip",
					label = _"Unequip"
				}
			},
			wml.tag.column {
				border = "left",
				border_size = 2,
				wml.tag.menu_button {
					id = "unequip_dropdown_menu",
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
				unequip_dropdown_buttons
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

	gui.add_widget_definition("menu_button", "dropdown_menu_thin", definition)
end

local listbox_row = 0
local shown_items -- Lua array of item numbers currently displayed in listbox, e.g. { 27, 34, 56}

-- Check if the scenario has progressed enough to disable unstoring items
local function is_too_progressed()
	if loti.during_tutorial then
		return false -- Unstoring is always allowed during the Tutorial
	end

	local unit = inventory_dialog.current_unit
	local terrain = wesnoth.current.map[unit]
	if string.sub(terrain, 1, 1) == "C" or string.sub(terrain, 1, 1) == "K" then
		return false
	end

	if wml.variables["turn_number"] <= 2 then
		return false
	end

	return true
end

-- Unhide the main listbox and focus on it.
-- Explain absence of listbox when Item Storage is empty.
-- Note: it's good for performance for listbox to be hidden until completely populated,
-- so that it won't be unnecessarily redrawn on every modification of "label".
local function unhide_listbox(dialog)
	if not shown_items[1] then
		if is_too_progressed() then
			dialog.storage_header.label = _"Cannot access item storage after turn 2 outside a castle."
		else
			dialog.storage_header.label = _"Item storage is empty."
		end
		return
	end

	dialog.storage_header.label = _"In the item storage:"

	-- Unhide/focus.
	dialog[listbox_id].visible = true
	dialog[listbox_id]:focus()
end

-- Show the menu that selects subsection of Item Storage: "sword", "spear", etc.
local function show_item_sorts(dialog)
	local sorts = loti.item.storage.list_sorts()
	local too_progressed = is_too_progressed()

        local a = {}
        for n in pairs(sorts) do table.insert(a, n) end
        table.sort(a)

	local item_sort, count
        for i in ipairs(a) do
	    item_sort=a[i]
            count=sorts[a[i]]
		if not too_progressed or item_sort == "potion" or item_sort == "limited" then
			-- TODO: print human-readable translatable name of item_sort.
			local text = item_sort .. " (" .. count .. ")"

			listbox_row = listbox_row + 1
			dialog[listbox_id][listbox_row].storage_text.label = text

			-- For callback of "View" to know which item_sort was selected.
			shown_items[listbox_row] = item_sort
		end
	end

	-- Listbox is completely populated, can show it now.
	unhide_listbox(dialog)

	-- Unhide "View" button.
	local empty = not shown_items[1]
	dialog.view.visible = not empty

	-- Hide "Equip" button and dropdown menu (not applicable).
	dialog.equip.visible = false
	dialog.storage_dropdown_menu.visible = false

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
local function get_item_description(item, count, set_items)
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

	if item and not string.match(item.sort, "potion") and item.sort ~= "limited" then
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
local function onshow(dialog, unit, item_sort)
	local listbox = dialog[listbox_id]

	-- Clear the form. Keep the listbox hidden until populated.
	listbox.visible = false
	if listbox_row > 0 then
		listbox:remove_items_at(1, 0)
		listbox_row = 0
	end

	-- Hide optional widgets until we know that they are needed.
	dialog.current_item.visible = false
	dialog.unequip.visible = false
	dialog.unequip_dropdown_menu.visible = false
	dialog.view.visible = false
	dialog.noequip_reason.visible = false

	-- Record things that will be needed in Equip/Unequip callbacks.
	shown_item_sort = item_sort
	shown_items = {}

	if not item_sort then
		return show_item_sorts(dialog)
	end

	-- Remember whether the items of this sort can be equipped.
	type_is_equippable = true
	if not loti.util.list_equippable_sorts(unit)[item_sort] then
		type_is_equippable = false
	end

	-- Calculate an array of currently equipped items,
	-- so that get_item_description() could show "item set" bonuses.
	local set_items = loti.unit.list_unit_item_numbers(unit.__cfg)

	-- Display currently equipped item (if any)

	local item = loti.item.on_unit.find(unit, item_sort)
	if item then
		local text = _"Currently equipped: " .. get_item_description(item, 1, set_items)
		dialog.current_item.label = text

		-- Show/hide fields related to current item
		dialog.current_item.visible = true

		if item_sort ~= "limited" and item_sort ~= "potion" then
			dialog.unequip.visible = true

			-- Note: Drop/Destroy dropdown menu near Unequip button is not yet supported in Tutorial,
			-- so we just leave it hidden.
			if not loti.during_tutorial then
				dialog.unequip_dropdown_menu.visible = true
			end
		end
	end

	-- Show all stored items of the selected item_sort.
	if not is_too_progressed() or item_sort == "potion" or item_sort == "limited" then
		local types = loti.item.storage.list_items(item_sort)


		-- Sort the items by name by creating { item_name = item_number, ... } table,
		-- then creating an array of { item_name1, item_name2, ... },
		-- then sorting this array alphabetically,
		-- and then obtaining the correct order of item numbers from the table.
		local item_name_to_number = {}
		local item_names = {}
		for item_number in pairs(types) do
			local name = loti.item.type[item_number].name
			item_name_to_number[name] = item_number
			table.insert(item_names, name)
		end

		table.sort(item_names)

		for _, item_name in ipairs(item_names) do
			local item_number = item_name_to_number[item_name]
			local count = types[item_number]

			listbox_row = listbox_row + 1

			local text = get_item_description(loti.item.type[item_number], count, set_items)
			listbox[listbox_row].storage_text.label = text

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

	dialog.equip.visible = can_equip
	if string.match(item_sort, "potion") then
		dialog.equip.label = _"Use"
	else
		dialog.equip.label = _"Equip"
	end
	dialog.storage_dropdown_menu.visible = not empty and present

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

		dialog.noequip_reason.label = _"This unit is currently not on the battlefield,\nso " .. pronoun ..
			_" can't take new items from the storage."
		dialog.noequip_reason.visible = true
	elseif not type_is_equippable then
		-- Explain that Equip is not allowed because this is a wrong type of weapon.
		dialog.noequip_reason.label = _"This unit can't equip such items.\n" ..
			_"They are unworthy of a mighty " .. unit.__cfg['language_name'] .. "."
		dialog.noequip_reason.visible = true
	end

	-- Listbox is completely populated, can show it now.
	unhide_listbox(dialog)
end

-- Handler for the "Unequip" button.
local function unequip()
	if not type_is_equippable then
		-- Leftover item. Warn that this item can't be re-equipped.
		local are_you_sure = "<span size='x-large'>" .. _"WARNING:" .. "</span> " ..
			_"this item is purely nostalgic (from the good old times when this unit needed it).\n" ..
			_"If you unequip it, this unit won't be able to equip it again.\n\n" ..
			_"Do you still want to unequip it?"

		if not gui.confirm(are_you_sure) then
			return
		end
	end

	unequip_internal()
	inventory_dialog.goto_tab("items_tab")
end

-- Determine selected element of the listbox.
-- Used in handlers of "Equip" and "View" buttons.
local function get_selected_item(dialog)
	local selected_index = dialog[listbox_id].selected_index
	return shown_items[selected_index]
end

-- Handler for "Drop to the ground" button.
local function drop_item(dialog)
	-- Remove item from storage and place it on the ground.
	inventory_dialog.mpsafety:queue({
		command = "drop",
		unit = inventory_dialog.current_unit, -- Only for coordinates where to drop
		number = get_selected_item(dialog),
		sort = shown_item_sort
	})
	inventory_dialog.goto_tab("items_tab")
end

-- Same as drop_item(), but for items currently on unit.
local function unequip_drop()
	-- Remove item from unit and place it on the ground.
	local unit = inventory_dialog.current_unit
	local item = loti.item.on_unit.find(unit, shown_item_sort)

	inventory_dialog.mpsafety:queue({
		command = "unequip_drop",
		unit = unit,
		number = item.number,
		sort = item.sort
	})
	inventory_dialog.goto_tab("items_tab")
end

-- Handler for "Destroy to get a random gem" button.
local function destroy_item(dialog)
	-- Remove item from storage, add 1 random gem.
	local gem = loti.gem.random()
	inventory_dialog.mpsafety:queue({
		command = "destroy",
		number = get_selected_item(dialog),
		sort = shown_item_sort,
		gem = gem
	})

	-- Tell player which gem was picked.
	loti.gem.show_gem_info_popup(gem)

	inventory_dialog.goto_tab("items_tab")
end

-- Same as destroy_item(), but for items currently on unit.
local function unequip_destroy()
	-- Remove item from unit, add 1 random gem.
	local unit = inventory_dialog.current_unit
	local item = loti.item.on_unit.find(unit, shown_item_sort)
	local gem = loti.gem.random()

	inventory_dialog.mpsafety:queue({
		command = "unequip_destroy",
		unit = unit,
		number = item.number,
		sort = item.sort,
		gem = gem
	})

	-- Tell player which gem was picked.
	loti.gem.show_gem_info_popup(gem)

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

	inventory_dialog.install_callbacks(function(dialog)
		-- Callback for Unequip button.
		dialog.unequip.on_button_click = overrides.unequip or unequip

		-- Callback for "Close" button.
		dialog.close_storage.on_button_click = function()
			inventory_dialog.catch_enter_or_ok(listbox_id, function() end)
			if overrides.close_storage then
				overrides.close_storage()
			else
				inventory_dialog.goto_tab("items_tab")
			end
		end

		-- Handler for Equip dropdown menu actions: "Drop item" and "Destroy item" (for item in storage).
		dialog.storage_dropdown_menu.on_modified = function()
			if dialog.storage_dropdown_menu.selected_index == 1 then
				-- First option on the menu
				if overrides.drop_item then
					overrides.drop_item(dialog)
				else
					drop_item(dialog)
				end
			else
				-- Second option in the menu
				if overrides.destroy_item then
					overrides.destroy_item(dialog)
				else
					destroy_item(dialog)
				end
			end
		end

		-- Handler for dropdown menu actions: "Drop item" and "Destroy item" (for item on unit).
		dialog.unequip_dropdown_menu.on_modified = function()
			if dialog.unequip_dropdown_menu.selected_index == 1 then
				-- First option on the menu
				unequip_drop()
			else
				-- Second option in the menu
				unequip_destroy()
			end
		end
	end)
end
