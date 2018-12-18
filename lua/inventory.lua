--! #textdomain "wesnoth-loti"
--
-- Implementation of the "display inventory" dialog (shows items currently on the unit).
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

-- The following variable contains "moddable" options of the inventory UI,
-- so that scenarios like Tutorial could override them.
local inventory_config = {

	-- Action buttons are buttons below the inventory dialog, e.g. "Disable retaliation attacks".
	action_buttons = {
		{ id = "storage", label = _"Item storage" },
		{ id = "crafting", label = _"Crafting" },
		{ id = "unit_information", label = _"Unit information" },
		{ spacer = true },
		{ id = "retaliation", label = _"Select weapons for retaliation" },
		{ id = "unequip_all", label = _"Unequip (store) all items" },
		{ id = "recall_list_items", label = _"Items on units on the recall list" },
		{ id = "ground_items", label = _"Pick up items on the ground" },
		{ spacer = true },
		{ id = "ok", label = _"Close" }
	},

	-- Maps the id= of action button (see inventory_config.action_buttons)
	-- to a Lua function that is called when this button gets clicked.
	action_button_callbacks = {
		storage = function() wesnoth.log("debug", "Clicked on storage button!") end,

		-- Special callback 'default' is called when no callback has been defined for this button.
		default = function(id) helper.wml_error("Button " .. id .. " is not yet implemented.") end
	},

	-- Background image behind the picture of the item (should look like a button)
	slot_background_image = "buttons/button_square/button_square_60.png"
}

-- These variables are for translation of strings that depend on a parameter.
-- NO_ITEM_TEXT must list all item types that have a slot (i.e. all except potion/limited).
local NO_ITEM_TEXT = {
	default = _"[no item]",
	ring = _"no ring",
	amulet = _"no amulet",
	cloak = _"no cloak",
	armour = _"no armour",
	helm = _"no helm",
	gauntlets = _"no gauntlets",
	boots = _"no boots",
	sword = _"no sword",
	axe = _"no axe",
	staff = _"no staff",
	xbow = _"no crossbow",
	bow = _"no bow",
	dagger = _"no dagger",
	knife = _"no knife",
	mace = _"no mace",
	polearm = _"no polearm",
	claws = _"no metal claws",
	sling = _"no sling",
	essence = _"no essence",
	thunderstick = _"no thunderstick",
	spear = _"no spear"
}

-- Display the inventory dialog for a unit.
local function loti_inventory(unit)
	local equippable_sorts = loti_util_list_equippable_sorts(unit.type)

	-- Determine sorts of equippable weapons, e.g. { "sword", "spear", "staff" }.
	-- Elements from this array will then consumed (and deleted) in get_slot_widget() calls.
	local equippable_weapons = {}
	for item_sort in pairs(equippable_sorts) do
		if item_sort == "sword" or item_sort == "axe" or item_sort == "staff"
			or item_sort == "xbow" or item_sort == "bow" or item_sort == "dagger"
			or item_sort == "knife" or item_sort == "mace" or item_sort == "polearm"
			or item_sort == "claws" or item_sort == "sling" or item_sort == "essence"
			or item_sort == "thunderstick"  or item_sort == "spear"
		then
			table.insert(equippable_weapons, item_sort)
		end
	end

	-- Array of slots, in order added via get_slot_widget().
	-- Each element is the item_sort of this slot.
	-- E.g. { "amulet", "helm", "ring", ... }
	-- Note: element #5 can be found by id "slot5" in wesnoth.set_dialog_*() methods.
	local slots = {}

	-- Make a wml.tag.column that would display one currently equipped item.
	-- Parameter item_sort is a type of the item (e.g. "amulet" or "gauntlets").
	-- Special value item_sort="weapon" is treated as "next equippable weapon".
	-- Only one slot can exist for each item_sort,
	-- so the slots can't be used to show orbs or books (they need another widget).
	local function get_slot_widget(item_sort)
		if item_sort == "limited" then
			helper.wml_error("get_slot_widget(): books/orbs are not supported.")
		end

		if item_sort == "weapon" then
			-- Fake item_sort that means "whatever sort of weapon is allowed on this unit".
			-- We immediately replace this, unless all allowed weapon sorts
			-- have already been added (in this case the slot will be hidden).
			item_sort = table.remove(equippable_weapons, 1) or "weapon"
		end

		table.insert(slots, item_sort)

		local internal_widget = wml.tag.panel {
			id = "slot" .. #slots, -- Unique within the dialog
			wml.tag.grid {
				id = item_sort,
				wml.tag.row {
					wml.tag.column {
						border = "all",
						border_size = 5,
						horizontal_alignment = "left",
						wml.tag.image {
							id = "item_image",
							label = inventory_config.slot_background_image
						}
					}
				},
				wml.tag.row {
					wml.tag.column {
						border = "all",
						border_size = 5,
						wml.tag.label {
							id = "item_name",
							text_alignment = "center",
							wrap = "yes"
						}
					}
				}
			}
		}

		return wml.tag.column {
			grow_factor = 0,
			border = "all",
			border_size = 5,
			horizontal_alignment = "left",
			internal_widget
		}
	end

	-- Prepare the layout structure for wesnoth.show_dialog().
	local slots_grid = wml.tag.grid {
		id = "inventory",

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
		for _, button_config in ipairs(inventory_config.action_buttons) do
			local button
			if button_config.spacer then
				button = wml.tag.spacer { height = 20 }
			else
				button = wml.tag.button(button_config)
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

	-- UNUSED: horizontal version of get_action_menu_vertical().
	-- Will probably we removed, because text on the buttons is too long for the menu
	-- to be horizontal. Could have been useful if action buttons were icons.
	-- Return value: [grid] tag.
	local function get_action_menu_horizontal()
		local columns = get_action_buttons()
		return wml.tag.grid {
			wml.tag.row {
				wml.tag.column {
					wml.tag.grid {
						id = "inventory-actions",
						wml.tag.row(columns)
					}
				}
			}
		}
	end

	-- Menu that contains a vertical menu with action buttons.
	-- Return value: [grid] tag.
	local function get_action_menu_vertical()
		local columns = get_action_buttons()
		local rows = {}

		for _, column in ipairs(columns) do
			table.insert(rows, wml.tag.row { column })
		end

		rows.id = "inventory-actions"
		return wml.tag.grid {
			wml.tag.row {
				wml.tag.column {
					wml.tag.grid(rows)
				}
			}
		}
	end

	-- Contents of the inventory page - everything except the actions menu.
	local dialog_page_contents = wml.tag.grid {
		-- Row 1: header text ("what is this page for")
		wml.tag.row {
			wml.tag.column {
				border = "left,bottom",
				border_size = 10,
				wml.tag.label {
					id = "inventory_menu_top_label",
					label = "<span size='large' weight='bold'>" .. _"Items currently on the unit." .. "</span>"
				}
			}
		},

		-- Row2: inventory slots
		wml.tag.row {
			wml.tag.column {
				slots_grid
			}
		}
	}

	local dialog = {
		wml.tag.tooltip { id = "tooltip_large" },
		wml.tag.helptip { id = "tooltip_large" },
		wml.tag.grid {
			wml.tag.row {
				-- Column 1: vertical menu.
				wml.tag.column { get_action_menu_vertical() },

				-- Column 2: contents of the inventory.
				wml.tag.column { dialog_page_contents }
			}
		}
	}

	local function preshow()
		wesnoth.set_dialog_markup(true, "inventory_menu_top_label")

		-- Add callbacks for clicks on all action buttons.
		for _, button_config in ipairs(inventory_config.action_buttons) do
			if not button_config.spacer and button_config.id ~= "ok" then
				local id = button_config.id
				local callback = inventory_config.action_button_callbacks[id]

				if not callback then
					callback = inventory_config.action_button_callbacks["default"]
				end

				-- Additionally pass ID to the callback.
				local onclick = function(x)
					callback(id);
				end

				wesnoth.set_dialog_callback(onclick, id)
			end
		end

		-- Add placeholders into all slots.
		for index, item_sort in ipairs(slots) do
			local default_text = ""
			if equippable_sorts[item_sort] then
				-- "No such item" message: shown for items that are not yet equipped, but can be.
				default_text = NO_ITEM_TEXT[item_sort]

				if not default_text then
					helper.wml_error("NO_ITEM_TEXT is not defined for item_sort=" .. item_sort)
					default_text = NO_ITEM_TEXT["default"]
				end
			elseif item_sort == "weapon" or item_sort == "leftover" then
				-- These are fake sorts (no item actually uses them) that mean "unneeded slot":
				-- "weapon" is a second/weapon for a unit that only uses 1 weapon, etc.,
				-- "leftover" is a slot reserved for items that are not allowed on this unit,
				-- but are still equipped (for example, Elvish Outrider had a sword and
				-- then advanced to Gryphon Rider, but Gryphon Rider can't equip swords)
				wesnoth.set_dialog_visible(false, "slot" .. index)
			else
				-- Unequippable item, e.g. gauntlets for a Ghost.
				wesnoth.set_dialog_visible(false, "slot" .. index)
			end

			wesnoth.set_dialog_value( default_text, "slot" .. index, "item_name")
		end

		local modifications = helper.get_child(unit.__cfg, "modifications")
		for _, item in ipairs(helper.child_array(modifications, "object")) do
			-- There are non-items in object[] array, but they don't have 'sort' key.
			-- Also there are fake items (e.g. sort=quest_effect), but they have 'silent' key.
			-- We also ignore objects without name, because they can't be valid items.
			if item.sort and not item.silent and item.name and item.sort ~= "potion" and item.sort ~= "limited" then
				if not equippable_sorts[item.sort] then
					-- Non-equippable equipped item - e.g. sword on the Gryphon Rider.
					-- Shown in a specially reserved "leftover" slot.
					item.sort = "leftover"
				end

				-- Sanity check: ensure that we have a slot for this type of item.
				-- Because if not, wesnoth.set_dialog_value() would print a really non-helpful error.
				local found
				for index, slot in ipairs(slots) do
					if slot == item.sort then
						found=index
						break
					end
				end

				if not found then
					helper.wml_error("Error: found item of type=" .. item.sort ..
						", but the inventory screen doesn't have a slot for this type.")
				end

				wesnoth.set_dialog_value(item.name, item.sort, "item_name")
				wesnoth.set_dialog_value(
					inventory_config.slot_background_image ..
					"~BLIT(" .. item.image .. "~SCALE_INTO(60,60))",
					item.sort, "item_image")

				-- Unhide the slot (leftover slots are hidden by default)
				wesnoth.set_dialog_visible(true, "slot" .. found)
			end
		end
	end

	local result = wesnoth.show_dialog(dialog, preshow)
	print("show_dialog returned result=" .. result)
end

-- Tag [show_inventory] displays the inventory dialog for the unit.
-- Unit is identified by passing "cfg" parameter to wesnoth.get_units().
function wesnoth.wml_actions.show_inventory(cfg)
	local units = wesnoth.get_units(cfg)
	if #units < 1 then
		helper.wml_error("[show_inventory]: no units found.")
	end

	loti_inventory(units[1])
end
