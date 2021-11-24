--! #textdomain "wesnoth-loti"
--
-- Methods that synchronize actions made in the Inventory dialog (e.g. "Unequip item")
-- by one player with other players (in a multiplayer game) to prevent OoS (out of sync).
--
-- How this works:
-- when player Bob: 1) unequips item A, 2) destroys item B and 3) equips item C,
-- the list of these 3 "operations" are written to array and passed to all other players,
-- and then their Wesnoth client does the same operations on their side, thus avoiding OoS.
--
-- So when Bob wants to run some operation, he uses mpsafety:queue(command).
-- After the Inventory dialog is closed, Bob returns mpsafety:export()
-- from the callback of wesnoth.sync.evaluate_single().
-- Then another player Alice uses mpsafety:synchronize(result) to apply all operations,
-- where "result" is the value that was returned by wesnoth.sync.evaluate_single().
-- For Bob, mpsafety:synchronize() does nothing, because we remember that it was Bob
-- who used the Inventory dialog (so we know that Bob already did these operations).
--
local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

local mpsafety = {}
mpsafety.__index = mpsafety

-- Return a new (blank) mpsafety log.
-- Used by the Inventory dialog.
function mpsafety:constructor()
	return setmetatable({ todo = {} }, mpsafety)
end

-- Queue "operation" to be performed for all players.
-- Immediately runs it for the current player.
function mpsafety:queue(operation)
	-- Encode certain values, so that operation would be a valid WML table.
	local unit = operation.unit
	if unit then
		if unit.valid == "map" then
			operation.x = unit.x
			operation.y = unit.y
		elseif unit.valid == "recall" then
			operation.recall_unit_id = unit.id
		end

		operation.unit = nil
	end

	-- Record this operation in the log. Will later be provided to other players.
	table.insert(self.todo, wml.tag.operation(operation))

	-- Perform this operation immediately. Also remember that this player is the one who used
	-- the Inventory dialog, so that synchronize() wouldn't repeat this operation.
	self:run_immediately(wesnoth.deepcopy(operation))
	self.this_player_already_did_it = true
end

-- Execute "operation" for the current player.
function mpsafety:run_immediately(operation)
	-- Unencode certain values, e.g. unit from coordinates.
	if operation.x then
		operation.unit = wesnoth.units.get(operation.x, operation.y)
	elseif operation.recall_unit_id then
		operation.unit = wesnoth.units.find_on_recall({ id = operation.recall_unit_id })[1]
	end

	-- Run the requested command
	local command = operation.command
	local unit = operation.unit

	if command == "undress" then
		-- Remove all items from unit.
		loti.item.util.undress_unit(unit)
	elseif command == "unequip" then
		-- Remove item from unit, add this item to storage.
		loti.item.util.take_item_from_unit(unit, operation.number, operation.sort)
	elseif command == "equip" then
		-- Remove item from storage, add this item to unit.
		loti.item.storage.remove(operation.number, operation.sort)
		loti.item.on_unit.add(unit, operation.number, operation.sort)
	elseif command == "store" then
		-- Store an item lying on the ground
		loti.item.on_the_ground.remove(operation.number, unit.x, unit.y, operation.sort)
		loti.item.storage.add(operation.number, operation.sort)
	elseif command == "equip_ground" then
		-- Equip an item lying on the ground
		loti.item.on_the_ground.remove(operation.number, unit.x, unit.y, operation.sort)
		loti.item.on_unit.add_with_replace(unit, operation.number, operation.sort)
	elseif command == "drop" then
		-- Remove item from storage, place it on the ground.
		loti.item.storage.remove(operation.number, operation.sort)
		loti.item.on_the_ground.add(operation.number, unit.x, unit.y, operation.sort)
	elseif command == "create_on_ground" then
		-- Creates an item lying on the ground. Used for crafting
		loti.item.on_the_ground.add(operation.number, unit.x, unit.y, operation.sort)
	elseif command == "gem_transmute" then
		-- Transmutation of gems
		loti.gem.add(operation.old_gem, -operation.old_count)
		loti.gem.add(operation.new_gem, operation.new_count)
	elseif command == "gem_remove" then
		-- When crafting
		loti.gem.add(operation.gem, -operation.count)
	elseif command == "unequip_drop" then
		-- Remove item from unit, place it on the ground.
		loti.item.on_unit.remove(unit, operation.number, operation.sort)
		loti.item.on_the_ground.add(operation.number, unit.x, unit.y, operation.sort)
	elseif command == "destroy" then
		-- Remove item from storage, add one gem as compensation.
		loti.item.storage.remove(operation.number, operation.sort)
		loti.gem.add(operation.gem, 1)
	elseif command == "unequip_destroy" then
		-- Remove item from unit, add one gem as compensation.
		loti.item.on_unit.remove(unit, operation.number, operation.sort)
		loti.gem.add(operation.gem, 1)
	elseif command == "destroy_ground" then
		-- Remove item from the ground, add one gem as compensation.
		loti.item.on_the_ground.remove(operation.number, unit.x, unit.y, operation.sort)
		loti.gem.add(operation.gem, 1)
	elseif command == "set_attacks_retal" then
		-- Enabling/disabling attack for retaliation
		local disabled_defences = {}
		for _, attack_tag in ipairs(operation) do
			local attack_index = attack_tag[2].index
			local weight = attack_tag[2].weight
			if weight == 1 then
				unit.attacks[attack_index].defense_weight = 1
			else
				unit.attacks[attack_index].defense_weight = 0

				-- Add to unit.variables.disabled_defences, so that we would later know
				-- that this is not an "attack only by design" weapon.
				table.insert(disabled_defences, {
					name = unit.attacks[attack_index].name,
					order = attack_index - 1 -- Backward compatibility with WML dialog
				})
			end
		end
		wml.array_access.set("disabled_defences", disabled_defences, unit)
	else
		helper.wml_error("mpsafety:run_immediately(): Unknown command: " .. tostring(command))
	end
end

-- Returns value that should be returned from wesnoth.sync.evaluate_single(),
-- then clears the existing log (because exported operations will immediately be done for all players),
-- so that next open_inventory_dialog() would start with an empty log.
function mpsafety:export()
	local result = self.todo
	self.todo = {}

	return result
end

-- Ensures that situation is synchronized for all players.
-- Parameter todo is the return value of wesnoth.sync.evaluate_single()
function mpsafety:synchronize(todo)
	if not self.this_player_already_did_it then
		for _, operation_tag in ipairs(todo) do
			self:run_immediately(operation_tag[2])
		end
	end

	-- Next time the Inventory dialog may be used by another player,
	-- so unset "this player is who used the dialog" flag after each synchronization.
	self.this_player_already_did_it = false
end

return function(inventory_dialog)
	-- Provide synchronized actions API to the Inventory dialog.
	inventory_dialog.mpsafety = mpsafety:constructor()
end
