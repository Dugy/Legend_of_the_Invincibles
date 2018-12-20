--! #textdomain "wesnoth-loti"
--
-- Implementation of the "display inventory" dialog (shows items currently on the unit).
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"
local goto_tab -- Defined below

-- The following variable contains "moddable" options of the inventory UI,
-- so that scenarios like Tutorial could override them.
local inventory_config = {
	-- Action buttons are buttons in the left menu, e.g. "Unequip all items".
	action_buttons = {
		{
			id = "storage",
			label = _"Item storage"
		},
		{
			id = "crafting",
			label = _"Crafting",
			onclick = function(unit)
				helper.wml_error("Crafting is not yet implemented.")
			end
		},
		{
			id = "unit_information",
			label = _"Unit information",
			onsubmit = function(unit)
				wesnoth.fire_event("unit information", unit.x, unit.y)
			end,
		},
		{ spacer = true },
		{
			id = "retaliation",
			label = _"Select weapons for retaliation",
			onclick = function(unit) goto_tab("retaliation_tab") end
		},
		{
			id = "unequip_all",
			label = _"Unequip (store) all items"
		},
		{
			id = "recall_list_items",
			label = _"Items on units on the recall list"
		},
		{ spacer = true },
		{
			id = "ground_items",
			label = _"Pick up items on the ground",
			onsubmit = function(unit)
				wesnoth.fire_event("item_pick", unit.x, unit.y)
			end
		}
	},

	-- Called when clicking on action_buttons which don't have onsubmit/onclick callbacks.
	default_button_callback = function(unit, button_id)
		helper.wml_error("Button " .. button_id .. " is not yet implemented.")
	end,

	-- Lua function that is called when player clicks on an inventory slot
	-- (e.g. on the image of gauntlets).
	slot_callback = function(item_sort)
		helper.wml_error("Changing " .. item_sort .. " is not yet implemented.")
	end
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

-- Register custom GUI widget "item_slot_button":
-- button with the picture of some item drawn on top of it.
local function loti_register_slot_widget()

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

	wesnoth.add_widget_definition("button", "item_slot_button", definition)
end

-- Register custom GUI widget "itemlabel": label with fixed width/height.
local function loti_register_itemlabel_widget()
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

	wesnoth.add_widget_definition("label", "itemlabel", definition)
end

-- Flag to avoid calling loti_register_widgets() twice
local widgets_registered = false

-- Register all custom GUI widgets used by our inventory dialog.
local function loti_register_widgets()
	if widgets_registered then
		return
	end

	loti_register_slot_widget()
	loti_register_itemlabel_widget()

	widgets_registered = true
end

-- NOTE: the only reason we call this function here is because it's very convenient for debugging
-- (any errors in add_widget_definition() are discovered before the map is even loaded)
-- When the widgets are completely implemented, this function will only be called from loti_inventory().
loti_register_widgets()

-- Array of slots, in order added via get_slot_widget().
-- Each element is the item_sort of this slot.
-- E.g. { "amulet", "helm", "ring", ... }
-- Note: element #5 can be found by id "slot5" in wesnoth.set_dialog_*() methods.
local slots

-- Construct tab #1: "items on the unit".
-- Note: result is exactly the same for any unit. See onshow_items_tab() for unit-specific logic.
-- Returns: top-level [grid] widget.
local function get_items_tab()
	slots = {}

	-- Make a wml.tag.column that would display one currently equipped item.
	-- Parameter item_sort is a type of the item (e.g. "amulet" or "gauntlets").
	-- Special value item_sort="weapon" is treated as "next equippable weapon".
	-- Only one slot can exist for each item_sort,
	-- so the slots can't be used to show orbs or books (they need another widget).
	local function get_slot_widget(item_sort)
		if item_sort == "limited" then
			helper.wml_error("get_slot_widget(): books/orbs are not supported.")
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

	-- Prepare the layout structure for wesnoth.show_dialog().
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

	-- "Close" button in the bottom-right corner of the dialog.
	local close_button = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.spacer {}
			},
			wml.tag.column {
				wml.tag.button {
					id = "ok",
					label = _"Close"
				}
			}
		}
	}

	-- Contents of the inventory page - everything except the actions menu.
	local dialog_page_contents = wml.tag.grid {
		-- Row 1: header text ("what is this page for")
		wml.tag.row {
			wml.tag.column {
				border = "bottom",
				border_size = 10,
				wml.tag.label {
					id = "inventory_menu_top_label",
					label = "<span size='large' weight='bold'>" .. _"Items currently on the unit." .. "</span>"
				}
			}
		},

		-- Row 2: inventory slots
		wml.tag.row {
			wml.tag.column {
				slots_grid
			}
		},

		-- Row 3: close button.
		wml.tag.row {
			wml.tag.column {
				horizontal_alignment = "right",
				close_button
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

-- Construct tab #2: retaliation ("weapons for retaliation" screen).
-- Note: result is exactly the same for any unit. See onshow_retaliation_tab() for unit-specific logic.
-- Returns: top-level [grid] widget.
local function get_retaliation_tab()
	-- TODO
	return wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.label {
					label = _"Select weapons for retaliation"
				}
			}
		}
	}
end

-- Display the inventory dialog for a unit.
-- TODO: support changing the unit without closing this dialog,
-- which can be useful for features like "Items on units on the recall list".
local function open_inventory_dialog(unit)
	loti_register_widgets()

	-- Last button that was clicked. Note: buttons with "onclick" are intentionally ignored.
	-- Used to run onsubmit callbacks after the dialog is closed.
	local clicked_button_id = nil

	-- Callback that updates the "items on this unit" tab whenever it is shown.
	-- Note: see get_items_tab() for internal structure of this tab.
	local function onshow_items_tab()
		wesnoth.set_dialog_markup(true, "inventory_menu_top_label")

		local equippable_sorts = loti_util_list_equippable_sorts(unit.type)

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

		-- Lua table { 'sword' => 'slot2', 'armour' => 'slot5', ... }.
		-- Calculated below.
		local slot_id_by_sort = {}

		-- Add placeholders into all slots.
		for index, item_sort in ipairs(slots) do
			local slot_id = "slot" .. index

			-- Set callback for situation when player clicks on this slot.
			wesnoth.set_dialog_callback(
				function() inventory_config.slot_callback(item_sort) end,
				slot_id,
				"item_image"
			)

			if item_sort == "weapon" then
				-- Fake item_sort that means "whatever sort of weapon is allowed on this unit".
				-- We immediately replace this, unless all allowed weapon sorts
				-- have already been added (in this case the slot will be hidden).
				item_sort = table.remove(equippable_weapons, 1) or "weapon"
			end

			slot_id_by_sort[item_sort] = slot_id

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
				wesnoth.set_dialog_visible(false, slot_id)
			else
				-- Unequippable item, e.g. gauntlets for a Ghost.
				wesnoth.set_dialog_visible(false, slot_id)
			end

			wesnoth.set_dialog_value( default_text, slot_id, "item_name")
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

				local slot_id = slot_id_by_sort[item.sort]
				if not slot_id then
					helper.wml_error("Error: found item of type=" .. item.sort ..
						", but the inventory screen doesn't have a slot for this type.")
				end

				wesnoth.set_dialog_value(item.name, slot_id, "item_name")
				wesnoth.set_dialog_value(item.image, slot_id, "item_image")

				-- Unhide the slot (leftover slots are hidden by default)
				wesnoth.set_dialog_visible(true, slot_id)
			end
		end

		-- Add callbacks for clicks on action buttons.
		for _, button in ipairs(inventory_config.action_buttons) do
			if not button.spacer then
				if button.onsubmit then
					-- onsubmit callbacks are only called after the dialog is closed.
					-- The only thing we need here is to remember clicked_button_id.
					wesnoth.set_dialog_callback(
						function() clicked_button_id = button.id end,
						button.id
					)
				else
					-- Normal onclick callback (this button doesn't close the dialog).
					local callback = button.onclick or inventory_config.default_button_callback

					-- Note: we additionally pass Unit and button ID as parameters to callback.
					wesnoth.set_dialog_callback(
						function() callback(unit, button.id) end,
						button.id
					)
				end
			end
		end
	end

	local function onshow_retaliation_screen()
		-- TODO
	end

	-- List of all tabs in the Inventory dialog.
	-- Only one tab is visible at a time.
	-- Another tab can be opened via goto_tab("id_of_new_tab").
	local tabs = {
		{
			id = "items_tab",
			grid = get_items_tab(),
			onshow = onshow_items_tab
		},
		{
			id = "retaliation_tab",
			grid = get_retaliation_tab(),
			onshow = onshow_retaliation_screen
		}
	}

	-- Get widget that contains all tabs.
	-- (only one tab will be visible at the same time)
	-- Returns: [grid] widget.
	local function get_multitab_widget()
		-- Wrap every tab in [panel], because panels can be made hidden/visible,
		-- and place them all into one grid.
		local column_wrapped_tabs = {}
		for _, tab in ipairs(tabs) do
			table.insert(column_wrapped_tabs, wml.tag.column {
				wml.tag.panel {
					id = tab.id,
					tab.grid
				}
			})
		end

		return wml.tag.grid {
			wml.tag.row(column_wrapped_tabs)
		}
	end

	-- Show one tab (and call its "onshow" callback), hide all other tabs.
	-- Parameter: tab_id - string (e.g. "inventory"), must be one of the IDs in tabs[] array.
	function goto_tab(tab_id)
		-- Quick sanity check for whether tab_id exists,
		-- because trying to hide ALL widgets in a dialog crashes Wesnoth.
		local found
		for _, tab in ipairs(tabs) do
			if tab.id == tab_id then found = 1 break end
		end
		if not found then
			helper.wml_error("Error: goto_tab: tab \"" .. tab_id .. "\" doesn't exist.")
		end

		-- Actually hide/unhide the tabs.
		for _, tab in ipairs(tabs) do
			local should_show = tab.id == tab_id
			if should_show then
				tab.onshow()
			end

			wesnoth.set_dialog_visible(should_show, tab.id)
		end
	end

	local dialog = {
		wml.tag.tooltip { id = "tooltip_large" },
		wml.tag.helptip { id = "tooltip_large" },
		get_multitab_widget()
	}

	local function preshow()
		goto_tab("items_tab")
	end

	local result = wesnoth.show_dialog(dialog, preshow)

	-- Run onsubmit callback, assuming that the dialog was closed by click on the action button.
	if clicked_button_id then
		for _, button in ipairs(inventory_config.action_buttons) do
			if button.id == clicked_button_id then
				button.onsubmit(unit, button.id)
			end
		end
	end
end

-- Tag [show_inventory] displays the inventory dialog for the unit.
-- Unit is identified by passing "cfg" parameter to wesnoth.get_units().
function wesnoth.wml_actions.show_inventory(cfg)
	local units = wesnoth.get_units(cfg)
	if #units < 1 then
		helper.wml_error("[show_inventory]: no units found.")
	end

	open_inventory_dialog(units[1])
end
