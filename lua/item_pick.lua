--! #textdomain "wesnoth-loti"
local _ = wesnoth.textdomain "wesnoth-loti"
local item_picker = {} -- for its own mp safety queue
wesnoth.require("inventory/multiplayer_safety")(item_picker)
function loti.util.item_pick_menu (mpsafety, unit)
	local hex_items = loti.item.on_the_ground.list_with_sorts (unit.x, unit.y)
--	
	for __, elem in ipairs(hex_items) do
		
		local number = elem.number
		local sort = elem.sort
		local item = loti.item.type[elem.number]
		if (sort == "gold") or (sort == "gem") then
			-- will work for gold and gem as storage.add implements required logic
			mpsafety:queue({
				command = "store",
				unit = unit,
				number = number,
				sort = sort
			})
			-- will show info with gold, do we need it?
			wesnoth.show_popup_dialog(item.name, item.flavour or item.description, item.image)
			-- do we need to trigger it here? it's the original behaviour though
			wesnoth.wml_actions.fire_event{ name="item picked", { "primary_unit", { x=unit.x, y=unit.y } } }
		else
			-- if we can equip, will be nil
			local why_cant_equip = loti.util.can_equip_item (unit, number, sort)
			local replaced_item = _"irrelevant"
			if (why_cant_equip == nil) and (sort ~= "limited") and (sort ~= "potion") then
				local r_item = loti.item.on_unit.find (unit, sort)
				if r_item then
					replaced_item = r_item.name
				end
			end
			local count = 0
			local this_sort = loti.item.storage.list_items (sort)
			if this_sort[number] then
				count = this_sort[number]
			end
			--- actions:
			--- 0 is equip/use, 1 is to store, 2 is to destroy, 3 is to leave on the ground
			local show_picking_dialogue = function(item, sort, replaced_item, cant_equip, count)
				local description = loti.item.describe_item(item.number, sort)
				if item.sort == "potion" then
					local res = wesnoth.show_message_dialog ({
						title = item.name,
						portrait = item.image,
						message = description .. "\n\n" .. _"Use this potion?"
					}, {_"Use it.", _"Store it. Currently having "..count.._" ssuch items stored.", _"Leave it on the ground."})
					if res == 1 then
						return 0
					elseif res == 2 then
						return 1
					else
						return 3
					end
				end
				if cant_equip then
					local res = wesnoth.show_message_dialog ({
						title = item.name,
						portrait = item.image,
						message = description .. "\n\n" .. "<span color='red'>" .. cant_equip .. "</span>"
					}, {_"Store it. Currently having "..count.._" such items stored.", _"Smash it to get a random gem.", _"Leave it on the ground."})
					if res == 1 then
						return 1
					elseif res == 2 then
						return 2
					else
						return 3
					end
				end
				--in case we can equip
				local res = wesnoth.show_message_dialog ({
						title = item.name,
						portrait = item.image,
						message = description .. "\n\n" .. _ "Item of the same type that will be unequipped: " .. replaced_item .. "\n" .. _"Take this item?"
				}, {_"Take it.", _"Store it. Currently having "..count.._" such items stored.",_"Smash it to get a random gem.", _"Leave it on the ground."})
				if (res >= 1) and (res <= 4) then
					return res - 1
				else
					return 3
				end
					
			end
			local result = show_picking_dialogue(item, sort, replaced_item, why_cant_equip, count)
			if result == 0 then
				mpsafety:queue({
					command = "equip_ground",
					unit = unit,
					number = number,
					sort = sort
				})
				local description = loti.item.describe_item(item.number, sort)
				wesnoth.show_popup_dialog(item.name, description, item.image)
			elseif result == 1 then
				mpsafety:queue({
					command = "store",
					unit = unit,
					number = number,
					sort = sort
				})
			elseif result == 2 then
				local gem = loti.gem.random()
				mpsafety:queue({
					command = "destroy_ground",
					unit = unit,
					number = number,
					sort = sort,
					gem = gem
				})
			end -- if res == 3, do nothing
			if result ~= 3 then
				-- used in campaign, chapters 5 and 9
				wesnoth.wml_actions.fire_event{ name="item picked", { "primary_unit", { x=unit.x, y=unit.y } } }
			end
		end
	end
end


function wesnoth.wml_actions.item_pick_menu(cfg)
	local units = wesnoth.get_units(cfg)
	if #units < 1 then
		helper.wml_error("[item_pick_menu]: no units found.")
	end
	local result = wesnoth.synchronize_choice(function()
		loti.util.item_pick_menu(item_picker.mpsafety, units[1])

		-- Tell other players what changed (which items were equipped, etc.).
		return item_picker.mpsafety:export()
	end)

	-- Re-run the same operations (e.g. Equip/Unequip) for all other players.
	item_picker.mpsafety:synchronize(result)
end
