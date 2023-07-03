--! #textdomain "wesnoth-loti"
--
-- "Items on the unit" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local util = wesnoth.require "./misc.lua"

local inventory_dialog -- Set below

-- The following variable contains "moddable" options of the inventory UI,
-- so that scenarios like Tutorial could override them.
local inventory_config = {
	-- Action buttons are buttons in the left menu, e.g. "Unequip all items".
	action_buttons = {
		{
			id = "storage",
			label = _"Item storage",
			onclick = function(unit) -- luacheck: ignore 212/unit
				inventory_dialog.goto_tab("storage_tab")
			end
		},
		{
			id = "crafting",
			label = _"Crafting",
			onsubmit = function(unit)
				loti.gem.show_crafting_window(unit.x, unit.y)
			end
		},
		{
			id = "unit_information",
			label = _"Unit information",
			onsubmit = function(unit)
				-- This may be a unit on recall list, so make sure that "unit" variable
				-- (which is needed in unit_information_part_1()) gets populated anyway.
				wml.variables["unit"] = unit.__cfg
				wesnoth.fire_event("unit information", unit)
				wml.variables["unit"] = nil
			end,
		},
		{ spacer = true },
		{
			id = "retaliation",
			label = _"Select weapons for retaliation",
			onclick = function(unit) inventory_dialog.goto_tab("retaliation_tab") end -- luacheck: ignore 212/unit
		},
		{
			id = "unequip_all",
			label = _"Unequip (store) all items",
			onclick = function(unit)
				if gui.confirm(_"Are you sure? All items of this unit will be placed into the item storage.") then
					inventory_dialog.mpsafety:queue({ command = "undress", unit = unit })
					inventory_dialog.goto_tab("items_tab") -- redraw, items are no longer in the slots
				end
			end
		},
		{
			id = "recall_list_items",
			label = _"Items on units on the recall list",
			onclick = function(unit) inventory_dialog.goto_tab("recall_tab") end -- luacheck: ignore 212/unit
		},
		{ spacer = true },
		{
			id = "ground_items",
			label = _"Pick up items on the ground",
			onsubmit = function(unit)
				wesnoth.fire_event("item_pick_inventory", unit)
			end
		}
	},

	-- Called when clicking on action_buttons which don't have onsubmit/onclick callbacks.
	default_button_callback = function(unit, button_id) -- luacheck: ignore 212/unit
		wml.error("Button " .. button_id .. " is not yet implemented.")
	end
}

-- Array of slots, in order added via get_slot_widget().
-- Each element is the item_sort of this slot.
-- E.g. { "amulet", "weapon", "gauntlets", ... }
-- Element #5 can be found as dialog["slot5"].
-- NOTE: this array is unit-independent, meaning that exact weapons (e.g. sword or spear)
-- are unknown. This array will list them as a pseudo-sort "weapon".
-- Unit-specific weapon sort can be determined from the sort_by_slot_id[] array, see below.
local slots

-- Lua tables:
-- slot_id_by_sort = { 'sword' => 'slot2', 'armour' => 'slot5', ... }.
-- sort_by_slot_id = { 'slot2' => 'sword', 'slot5' => 'armour', ... }
-- Calculated in onshow().
local slot_id_by_sort
local sort_by_slot_id

-- Exact item_sort of the item in leftover slot (if any).
-- Always nil if there is no leftover item.
local leftover_sort

-- Lua function that is called when player clicks on an inventory slot
-- (e.g. on the image of gauntlets).
inventory_config.slot_callback = function(item_sort)
	if item_sort == "leftover" then
		item_sort = leftover_sort
	end

	inventory_dialog.goto_tab("storage_tab", item_sort)
end

-- Construct tab: "items on the unit".
-- Note: result is exactly the same for any unit. See onshow() for unit-specific logic.
-- Returns: top-level [grid] widget.
local function get_tab()
	slots = {}

	-- Make a wml.tag.column that would display one currently equipped item.
	-- Parameter item_sort is a type of the item (e.g. "amulet" or "gauntlets").
	-- Special value item_sort="weapon" is treated as "next equippable weapon".
	-- Only one slot can exist for each item_sort,
	-- so the slots can't be used to show orbs or books (they need another widget).
	local function get_slot_widget(item_sort)
		if item_sort == "limited" then
			wml.error("get_slot_widget(): books/orbs are not supported.")
		end

		table.insert(slots, item_sort)

		local internal_widget = wml.tag.panel {
			id = "slot" .. #slots, -- Unique within the dialog
			wml.tag.grid {
				wml.tag.row {
					wml.tag.column {
						horizontal_alignment = "left",
						wml.tag.button {
							id = "item_image",
							definition = "item_slot_button"
						}
					}
				},
				wml.tag.row {
					wml.tag.column {
						border = "top,bottom",
						border_size = 8,
						horizontal_alignment = "left",
						wml.tag.label {
							definition = "itemlabel",
							id = "item_name",
							wrap = "yes"
						}
					}
				}
			}
		}

		return wml.tag.column {
			grow_factor = 0,
			border = "left",
			border_size = 5,
			horizontal_alignment = "left",
			internal_widget
		}
	end

	-- Prepare the layout structure for gui.show_dialog().
	local slots_grid = wml.tag.grid {
		-- Slots (one per item_sort), arranged in a predetermined order
		-- (e.g. helm is the top-middle item, and boots are bottom-middle).
		wml.tag.row {
			get_slot_widget "amulet",
			get_slot_widget "helm",
			get_slot_widget "ring"
		},
		wml.tag.row {
			get_slot_widget "weapon", -- Depends on the unit
			get_slot_widget "armour",
			get_slot_widget "weapon" -- Depends on the unit
		},
		wml.tag.row {
			get_slot_widget "gauntlets",
			get_slot_widget "boots",
			get_slot_widget "cloak"
		},
		wml.tag.row {
			get_slot_widget "weapon", -- Depends on the unit
			get_slot_widget "weapon", -- Depends on the unit.
			                          -- No units have more than 3 weapons, so we have 4 slots to be on a safe side.
			get_slot_widget "leftover" -- E.g. sword on Gryphon Rider, already equipped but not equippable
		}
	}

	-- Returns Lua array of [column] tags with buttons like "View item storage".
	local function get_action_buttons()
		local columns = {}
		for _, config in ipairs(inventory_config.action_buttons) do
			local button
			if config.spacer then
				button = wml.tag.spacer { height = 20 }
			else
				-- Parameters of [button] tag.
				local params = {
					id = config.id,
					label = config.label
				}

				-- If the button has onsubmit callback, then it always closes the dialog.
				if config.onsubmit then
					params.return_value_id = "ok"
				end

				button = wml.tag.button(params)
			end

			table.insert(columns, wml.tag.column {
				border = "bottom",
				border_size = 5,
				horizontal_grow = true,
				button
			})
		end

		return columns
	end

	-- Menu that contains a vertical menu with action buttons.
	-- Return value: [grid] tag.
	local function get_action_menu()
		local columns = get_action_buttons()
		local rows = {}

		for _, column in ipairs(columns) do
			table.insert(rows, wml.tag.row { column })
		end

		rows.id = "inventory-actions"
		return wml.tag.grid {
			wml.tag.row {
				wml.tag.column {
					border = "right",
					border_size = 15,
					wml.tag.grid(rows)
				}
			}
		}
	end

	-- Contents of the inventory page - everything except the actions menu.
	local dialog_page_contents = wml.tag.grid {
		-- Row 1: inventory slots
		wml.tag.row {
			wml.tag.column {
				slots_grid
			}
		},

		-- Row 2: close button.
		wml.tag.row {
			wml.tag.column {
				horizontal_alignment = "right",
				util.make_close_button()
			}
		}
	}

	return wml.tag.grid {
		wml.tag.row {
			-- Column 1: vertical menu.
			wml.tag.column { get_action_menu() },

			-- Column 2: contents of the inventory.
			wml.tag.column { dialog_page_contents }
		}
	}
end

-- Callback that updates the "items on this unit" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow(dialog, unit)
	local equippable_sorts = loti.util.list_equippable_sorts(unit)

	-- Determine sorts of equippable weapons, e.g. { "sword", "spear", "staff" }.
	-- Elements from this array will then consumed (and deleted) in get_slot_widget() calls.
	local equippable_weapons = {}
	for item_sort in pairs(equippable_sorts) do
		if item_sort == "sword" or item_sort == "axe" or item_sort == "staff"
			or item_sort == "xbow" or item_sort == "bow" or item_sort == "dagger"
			or item_sort == "knife" or item_sort == "mace" or item_sort == "polearm"
			or item_sort == "claws" or item_sort == "sling" or item_sort == "essence"
			or item_sort == "thunderstick" or item_sort == "spear"
		then
			table.insert(equippable_weapons, item_sort)
		end
	end

	slot_id_by_sort = {}
	sort_by_slot_id = {}
	leftover_sort = nil

	-- Add placeholders into all slots.
	for index, item_sort in ipairs(slots) do
		local slot_id = "slot" .. index

		if item_sort == "weapon" then
			-- Fake item_sort that means "whatever sort of weapon is allowed on this unit".
			-- We immediately replace this, unless all allowed weapon sorts
			-- have already been added (in this case the slot will be hidden).
			item_sort = table.remove(equippable_weapons, 1) or "weapon"
		end

		slot_id_by_sort[item_sort] = slot_id
		sort_by_slot_id[slot_id] = item_sort

		-- Ensure that empty slots don't have any images.
		-- This is needed when we redraw the dialog after "Unequip all items".
		local slot = dialog[slot_id]
		slot.item_image.label = ''
		slot.item_image.tooltip = ''

		local default_text = ""
		if equippable_sorts[item_sort] then
			-- "No such item" message: shown for items that are not yet equipped, but can be.
			default_text = util.NO_ITEM_TEXT[item_sort]

			if not default_text then
				wml.error("NO_ITEM_TEXT is not defined for item_sort=" .. item_sort)
				default_text = util.NO_ITEM_TEXT["default"]
			end

			slot.visible = true
		else
			-- Can't equip this item (e.g. boots for a Ghost), so hide this slot.
			-- Note: if this is a leftover slot, it will become visible later, but only if needed.
			slot.visible = false
		end

		slot.item_name.label = default_text
	end

	-- Array of equipped items, can be passed to describe_item() to show set bonuses
	local set_items = loti.unit.list_unit_item_numbers(unit.__cfg)

	for _, item in ipairs(loti.item.on_unit.list_regular(unit)) do
		if not equippable_sorts[item.sort] then
			-- Non-equippable equipped item - e.g. sword on the Gryphon Rider.
			-- Shown in a specially reserved "leftover" slot.
			leftover_sort = item.sort
			item.sort = "leftover"
		end

		local slot_id = slot_id_by_sort[item.sort]
		if not slot_id then
			wml.error("Error: found item of type=" .. item.sort ..
				", but the inventory screen doesn't have a slot for this type.")
		end

		local slot = dialog[slot_id]
		slot.item_name.label = item.name
		slot.item_image.label = item.image
		slot.item_image.tooltip = loti.item.describe_item(item.number, item.sort, set_items)

		-- Unhide the slot (leftover slots are hidden by default).
		slot.visible = true
	end

	-- Disable action buttons that aren't applicable.
	-- For example, units on recall list can't pick items from the ground.
	local present = unit.valid ~= "recall"
	for _, button_id in ipairs({ "storage", "crafting", "ground_items" }) do
		dialog[button_id].enabled = present
	end

	-- Disable "Pick up items on the ground" button if the unit isn't standing on any items.
	if present then
		local lying_items = loti.item.on_the_ground.list(unit.x, unit.y)
		dialog.ground_items.enabled = ( #lying_items > 0 )
	end

	-- Disable "Items on units on the recall list" if none of those units have items.
	local geared_recall_units = wesnoth.units.find_on_recall({ trait = "geared" })
	dialog.recall_list_items.enabled = ( #geared_recall_units > 0 )
end

-- Last button that was clicked. Note: buttons with "onclick" are intentionally ignored.
-- Used to run onsubmit callbacks after the dialog is closed.
local clicked_button_id = nil

-- Install callbacks for all action buttons, slots, etc.
local function callbacks_install_function(dialog)
	-- Callbacks of action buttons.
	for _, button in ipairs(inventory_config.action_buttons) do
		if not button.spacer then
			if button.onsubmit then
				-- onsubmit callbacks are only called after the dialog is closed.
				-- The only thing we need here is to remember clicked_button_id.
				dialog[button.id].on_button_click = function()
					clicked_button_id = button.id
				end
			else
				-- Normal onclick callback (this button doesn't close the dialog).
				local callback = button.onclick or inventory_config.default_button_callback

				-- Note: we additionally pass Unit and button ID as parameters to callback.
				dialog[button.id].on_button_click = function()
					callback(inventory_dialog.current_unit, button.id)
				end
			end
		end
	end

	-- Callbacks for situation when player clicks on the slot.
	for index, _ in ipairs(slots) do
		local slot_id = "slot" .. index

		-- When we set "on_button_click", we don't yet know the exact item_sort,
		-- because for different units the "weapon" slot means different item_sorts,
		-- and we don't yet know which unit will be displayed.
		-- So we'll determine item_sort later, when the callback gets called,
		-- because at this point sort_by_slot_id[] array will be populated.
		dialog[slot_id].item_image.on_button_click = function()
			local item_sort = sort_by_slot_id[slot_id]
			inventory_config.slot_callback(item_sort)
		end
	end
end

-- Register custom GUI widget "item_slot_button":
-- button with the picture of some item drawn on top of it.
local function register_slot_widget()
	-- Image that displays the button itself (border, pressed/focused animation)
	local background = "buttons/button_square/button_square_60"
	local size = 60

	-- Image of the item that is currently in this item slot (if any)
	local item_picture= "(if(text!='',text,'misc/blank.png')) .. '~SCALE_INTO(" .. size .. "," .. size .. ")'"

	local definition = {
		id = "item_slot_button",
		description = "Clickable image of item (e.g. gauntlets) in LotI inventory dialog.",

		wml.tag.resolution {
			min_width = size,
			min_height = size,
			default_width = size,
			default_height = size,
			max_width = size,
			max_height = size,

			wml.tag.state_enabled {
				wml.tag.draw {
					wml.tag.image {
						w = "(width)",
						h = "(height)",
						name = background .. ".png"
					},
					wml.tag.image {
						name = item_picture
					}
				}
			},
			wml.tag.state_disabled {
				wml.tag.draw {
					wml.tag.image {
						w = "(width)",
						h = "(height)",
						name = background .. ".png~GS()"
					},
					wml.tag.image {
						name = item_picture .. "~GS()"
					}
				}
			},
			wml.tag.state_pressed {
				wml.tag.draw {
					wml.tag.image {
						w = "(width)",
						h = "(height)",
						name = background .. "-pressed.png"
					},
					wml.tag.image {
						name = item_picture
					}
				}
			},
			wml.tag.state_focused {
				wml.tag.draw {
					wml.tag.image {
						w = "(width)",
						h = "(height)",
						name = background .. "-active.png"
					},
					wml.tag.image {
						name = item_picture
					}
				}
			}
		}
	}

	gui.add_widget_definition("button", "item_slot_button", definition)
end

-- Register custom GUI widget "itemlabel": label with fixed width/height.
local function register_itemlabel_widget()
	local font_size = 14
	local width = 125
	local height = 60

	-- TODO: flexible height?
	-- (just setting max_height to 150 and height to 60 doesn't do the trick)

	local draw = wml.tag.draw {
		wml.tag.text {
			text = "(text)",
			font_size = font_size,
			maximum_width = "(width)",
			w = "(width)",
			h = "(text_height)"
		}
	}

	local definition = {
		id = "itemlabel",
		description = 'Label for item name in LotI inventory dialog.',

		wml.tag.resolution {
			min_width = width,
			min_height = height,
			default_width = width,
			default_height = height,
			max_width = width,
			max_height = height,

			wml.tag.state_enabled { draw },
			wml.tag.state_disabled { draw }
		}
	}

	gui.add_widget_definition("label", "itemlabel", definition)
end

-- Run onsubmit callback, assuming that the dialog was closed by click on the action button.
local function onsubmit_callback(unit)
	if clicked_button_id then
		for _, button in ipairs(inventory_config.action_buttons) do
			if button.id == clicked_button_id then
				button.onsubmit(unit, button.id)
			end
		end

		-- This click has been handled, don't repeat these callbacks until the next click.
		clicked_button_id = nil
	end
end

-- Add this tab to the dialog.

return function(provided_inventory_dialog)
	-- Place this interface into the file-scope local variable,
	-- because some code above needs inventory_dialog.goto_tab(), etc.
	inventory_dialog = provided_inventory_dialog

	inventory_dialog.add_tab {
		id = "items_tab",
		grid = get_tab,
		onshow = onshow
	}

	inventory_dialog.install_callbacks(callbacks_install_function)
	inventory_dialog.register_widgets(register_slot_widget)
	inventory_dialog.register_widgets(register_itemlabel_widget)
	inventory_dialog.add_onsubmit_callback(onsubmit_callback)

	-- Provide "inventory_config" variable to scenarios like Tutorial (they need to change it,
	-- e.g. display some message like "No, not this!" when player clicks the wrong button,
	-- not the button that was needed on the current step of the Tutorial).
	loti.config = loti.config or {}
	loti.config.inventory = inventory_config
end
