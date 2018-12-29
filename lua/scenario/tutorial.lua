--! #textdomain "wesnoth-loti"
--
-- Lua scripts for scenario [scenarios1/00_Tutorial.cfg].
-- Simplified crafting dialog, etc.
--
-------------------------------------------------------------------------------

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

-- Have Delenia say something
local function Delly_says(text)
	wesnoth.show_message_dialog({
		speaker = "Delenia",
		portrait = "portraits/humans/thief+female.png",
		message = text
	})
end

-- Have Efraim say something
local function Efraim_says(text)
	wesnoth.show_message_dialog({
		speaker = "Efraim_de_Ceise",
		portrait = "portraits/Efraim.png",
		message = text
	})
end

-- Simplified crafting dialog for Tutorial,
-- where Efraim has to craft 1 sword from 3 obsidians, and can't do anything else.
function tutorial_craft()
	local unit = wesnoth.get_units({ id = "Efraim_de_Ceise" })[1]
	local item = loti.item.type[606] -- Twinkling Sword

	-- Efraim's old sword.
	-- It's not really equipped on Efraim (Tutorial just says it is),
	-- but it should drop to the ground when newly crafted sword gets equipped.
	local old_sword = loti.item.type[605] -- Sword of Krux.

	-- This flag becomes true when player clicks Craft.
	-- (to reopen the dialog if it was closed by Enter/Escape).
	local successfully_crafted = false

	-- Populate the normal crafting dialog with Tutorial-related data.
	local function show_selected_item()
		loti.gem.show_crafting_report(item.number)

		wesnoth.set_dialog_value(item.name, "gui_recipe_chosen", 1, "gui_recipe_name")
		wesnoth.set_dialog_value("icons/unit-groups/era_default_knalgan_alliance_30-pressed.png", "gui_recipe_chosen", 1, "gui_recipe_icon")
	end

	-- Install callbacks, etc. in the crafting dialog.
	local function preshow()
		show_selected_item()

		-- Hide Transmute button.
		wesnoth.set_dialog_visible(false, "transmute")

		-- Hide type chooser (Sword/Spear/etc.), sword is the only thing we craft.
		wesnoth.set_dialog_visible(false, "gui_type_chosen")

		-- Select "Weapon" in "choose base type" listbox
		wesnoth.set_dialog_value(2, "gui_basetype_chosen")

		-- Don't allow to select "Armour" in "choose base type" listbox
		wesnoth.set_dialog_callback(function()
			if wesnoth.get_dialog_value("gui_basetype_chosen") == 1 then
				Delly_says(_"I am sorry, I do not remember any crafting constellation for an armour. Try to make a sword instead.")

				-- Select "Weapon" basetype again.
				wesnoth.set_dialog_value(2, "gui_basetype_chosen")
			end
		end, "gui_basetype_chosen")

		-- Don't allow to exit Crafting dialog until the sword is crafted.
		wesnoth.set_dialog_callback(function()
			Delly_says(_"Do not give up easily.")
			tutorial_craft() -- Reopen the dialog
		end, "cancel")

		-- When player clicks Craft.
		wesnoth.set_dialog_callback(function()
			-- "Are you sure" dialog, but can't refuse.
			while not wesnoth.confirm(_"Are you sure you want to craft this item?") do
				Efraim_says(_"Wait, I actually want to craft it.")
			end

			-- Remove 3 obsidians
			wesnoth.set_variable("obsidians", 0)

			-- Drop "Sword of Krux" to the ground, then give new sword to Efraim.
			-- Note: Efraim doesn't really have "Sword of Krux" in his inventory, so we don't remove it.
			loti.item.on_the_ground.add(old_sword.number, unit.x, unit.y, old_sword.sort)
			loti.item.on_unit.add(unit, item.number, item.sort)

			-- This part of the tutorial is completed.
			successfully_crafted = true
		end, "ok")
	end

	wesnoth.show_dialog(loti.gem.get_crafting_dialog(), preshow)
	if not successfully_crafted then
		-- Closed via Enter/Escape.
		-- Reopen until the player clicks Craft.
		tutorial_craft()
	end
end
