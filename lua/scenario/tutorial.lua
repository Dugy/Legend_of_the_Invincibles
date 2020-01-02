--! #textdomain "wesnoth-loti"
--
-- Lua scripts for scenario [scenarios1/00_Tutorial.cfg].
-- Simplified crafting dialog, etc.
--
-------------------------------------------------------------------------------

local _ = wesnoth.textdomain "wesnoth-loti"

local crafting_done = false

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

local original_slot_callback = loti.config.inventory.slot_callback
local original_button_callbacks = {}
for _, button in ipairs(loti.config.inventory.action_buttons) do
	if button.id then
		original_button_callbacks[button.id] = { onsubmit = button.onsubmit, onclick = button.onclick }
	end
end

-- Simplified crafting dialog for Tutorial,
-- where Efraim has to craft 1 sword from 3 obsidians, and can't do anything else.
local function tutorial_craft()
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

		-- Hide type chooser (Sword/Spear/etc.), sword is the only thing we craft.
		wesnoth.set_dialog_visible(false, "gui_type_chosen")
--		wesnoth.set_dialog_visible(false, "gui_choose_type_label")

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

		-- When player clicks Exit.
		wesnoth.set_dialog_callback(function()
			Delly_says(_"Do not give up easily.")
		end, "cancel")

		-- When player clicks Transmute.
		wesnoth.set_dialog_callback(function()
			Delly_says(_"Alchemy is great, but we don't have enough gems for that.")
		end, "transmute")

		-- When player clicks Craft.
		wesnoth.set_dialog_callback(function()
			-- "Are you sure" dialog, but can't refuse.
			while not wesnoth.confirm(_"Are you sure you want to craft this item?") do
				Efraim_says(_"Wait, I actually want to craft it.")
			end

			-- Remove 3 obsidians
			wesnoth.set_variable("obsidians", 0)
			wesnoth.set_variable("tutorial.proceed", 1)

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

-- Simplified Inventory dialog for step 1 of the Tutorial,
-- where Efraim has to get to the crafting tab and can't do anything else.
local function inventory_step1()
	local config = loti.config.inventory

	for idx, button in ipairs(config.action_buttons) do
		if button.id == "storage" then
			button.onclick = function()
				Delly_says(_"No looking into your backpack, there is nothing relevant there anyway.")
			end
		elseif button.id == "retaliation" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"I do not need to retaliate, I have allies to do that while I flee.")
			end
		elseif button.id == "crafting" then
			button.onsubmit = nil
			button.onclick = function()
				if crafting_done == false then
					tutorial_craft()
					crafting_done = true
				else
					Efraim_says(_"I will have to improve my crafting skills before crafting something again in her proximity.")
				end
			end
		elseif button.id == "unit_information" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"Hm... I do not want her to learn everything about me at the moment.")
			end
		elseif button.id == "unequip_all" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"No, no, I do not want her to see so soon how I missed my exercise recently.")
			end
		end
	end

	config.slot_callback = function(item_sort)
		Delly_says(_"I think you will not sweat too much while crafting, so you do not need to remove anything you are wearing. Not that you ever did anything that could make you sweat anyway...")
	end
end

-- Simplified Inventory dialog for step 4 of the Tutorial,
-- where Efraim has to Unequip his Twinkling Sword, and can't do anything else.
local function inventory_step4()
	local config = loti.config.inventory

	for idx, button in ipairs(config.action_buttons) do
		if button.id == "storage" then
			button.onclick = function()
				Delly_says(_"Why... why do you still insist to look for something in your backpack?")
			end
		elseif button.id == "retaliation" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"Ohhh, not today.")
			end
		elseif button.id == "crafting" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"Who cares about crafting when she is nearby?")
			end
		elseif button.id == "unit_information" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"I think you talk about yourself often enough.")
			end
		elseif button.id == "unequip_all" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"No, those muscles of yours will not impress me.")
			end
		end
	end

	local done
	config.slot_callback = function(item_sort)
		if item_sort == "sword" and not done then
			original_slot_callback("sword")
			done = true
		else
			Efraim_says(_"I somehow think that her reaction to unequipping that would be too awkward")
		end
	end

	config.close_storage = function()
		Delly_says(_"Do it! Do it! Do it! DOOO EEET!")
	end

	config.drop_item = function()
		Delly_says(_"I think you were one of those who supported laws against littering, right?")
	end

	config.destroy_item = function()
		Delly_says(_"Were you listening to the song where they yelled <i>We were built for destrouction</i> too often?")
	end
end

-- Simplified Inventory dialog for step 6 of the Tutorial,
-- where Efraim has to give her a sword and can't do anything else.
local function inventory_step6()
	local config = loti.config.inventory

	for idx, button in ipairs(config.action_buttons) do
		if button.id == "retaliation" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"She would become ugly if she tried to retaliate.")
			end
		elseif button.id == "storage" then
			button.onsubmit = nil
			button.onclick = function()
				if wesnoth.get_variable("tutorial.proceed") == 0 then
					original_button_callbacks.storage.onclick()
				else
					Delly_says(_"Oh, yes, carry on giving me stuff. I would like money now. Preferably a lot of them. Sharing is caring, you know that?")
				end
			end
		elseif button.id == "crafting" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"Do I look like a mere blacksmith to you?")
			end
		elseif button.id == "unit_information" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"Why are you invading my privacy? Are you the Naga Security Agency?")
			end
		elseif button.id == "unequip_all" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"Definitely no.")
			end
		end
	end

	config.slot_callback = function(item_sort)
		Delly_says(_"No, no, no, no...")
	end

	config.override_unequippability.sword = true

	config.close_storage = function()
		Efraim_says(_"No coming back!")
	end

	config.drop_item = function()
		Efraim_says(_"Do not throw it away immediately!")
	end

	config.destroy_item = function()
		Efraim_says(_"It is not so worthless, by the way.")
	end
end

-- Simplified Inventory dialog for step 7 of the Tutorial,
-- where Efraim has to remove her armour and can't do anything else.
local function inventory_step7()
	local config = loti.config.inventory

	for idx, button in ipairs(config.action_buttons) do
		if button.id == "storage" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"Yes, yes, I never thought you would be such a good person to give me something new.")
			end
		elseif button.id == "crafting" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"Who cares about crafting now...")
			end
		elseif button.id == "retaliation" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"Nobody will think about attacking her when I am done.")
			end
		elseif button.id == "unit_information" then
			button.onsubmit = nil
			button.onclick = function()
				Delly_says(_"What would you like to know? Surely something you should not know...")
			end
		elseif button.id == "unequip_all" then
			button.onsubmit = nil
			button.onclick = function()
				Efraim_says(_"I would prefer if she kept the sword. I keep my promises, after all.")
			end
		end
	end

	config.slot_callback = function(item_sort)
		if item_sort == "armour" then
			if wesnoth.get_variable("tutorial.proceed") == 0 then
				original_slot_callback("armour")
			else
				Delly_says(_"Enough!")
			end
		elseif item_sort == "boots" then
			Efraim_says(_"I am not interested in seeing her socks!")
		elseif item_sort == "sword" then
			Delly_says(_"First you forced me to take that sword, now you are taking it back? Are you even sane?")
		else
			Efraim_says(_"I am interested in knowing what is under her armour, not elsewhere!")
		end
	end
end

-- Provide this method via wesnoth.require(...).craft
return { craft = tutorial_craft, inventory_step1 = inventory_step1, inventory_step4 = inventory_step4, inventory_step6 = inventory_step6, inventory_step7 = inventory_step7 }
