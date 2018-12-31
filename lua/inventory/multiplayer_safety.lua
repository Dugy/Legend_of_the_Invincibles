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
-- from the callback of wesnoth.synchronize_choice().
-- Then another player Alice uses mpsafety:synchronize(result) to apply all operations,
-- where "result" is the value that was returned by wesnoth.synchronize_choice().
-- For Bob, mpsafety:synchronize() does nothing, because we remember that it was Bob
-- who used the Inventory dialog (so we know that Bob already did these operations).
--
local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

local mpsafety = {}
mpsafety.__index = mpsafety

-- Return a new (blank) mpsafety object.
-- Automatically called each time new Inventory dialog is created.
function mpsafety:constructor()
	return setmetatable({ todo = {} }, mpsafety)
end

-- Queue "operation" to be performed for all players.
-- Immediately runs it for the current player.
function mpsafety:queue(operation)
	self:run_immediately(operation)

	-- Remember that it was this player who used the Inventory dialog,
	-- so that synchronize() wouldn't do anything for this player.
	self.this_player_already_did_it = true

	-- Encode certain values, so that operation would be a valid WML table.
	local unit = operation.unit
	if unit then
		operation.x = unit.x
		operation.y = unit.y
		operation.unit = nil
	end

	-- Record this operation in the log. Will later be provided to other players.
	table.insert(self.todo, wml.tag.operation(operation))
end

-- Execute "operation" for the current player.
function mpsafety:run_immediately(operation)
	-- Unencode certain values, e.g. unit from coordinates.
	if operation.x then
		operation.unit = wesnoth.get_unit(operation.x, operation.y)
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
	elseif command == "drop" then
		-- Remove item from storage, place it on the ground.
		loti.item.storage.remove(operation.number, operation.sort)
		loti.item.on_the_ground.add(operation.number, unit.x, unit.y, operation.sort)
	elseif command == "destroy" then
		-- Remove item from storage, add one gem as compensation.
		loti.item.storage.remove(operation.number, operation.sort)

		local gems = loti.gem.get_counts()
		gems[operation.gem] = gems[operation.gem] + 1
		loti.gem.set_counts(gems)
	else
		helper.wml_error("mpsafety:run_immediately(): Unknown command: " .. tostring(command))
	end
end

-- Returns value that should be returned from wesnoth.synchronize_choice()
function mpsafety:export()
	return self.todo
end

-- Ensures that situation is synchronized for all players.
-- Parameter todo is the return value of wesnoth.synchronize_choice()
function mpsafety:synchronize(todo)
	if not self.this_player_already_did_it then
		for _, operation_tag in ipairs(todo) do
			self:run_immediately(operation_tag[2])
		end
	end
end

return function(inventory_dialog)
	-- Provide synchronized actions API to the Inventory dialog.
	inventory_dialog.install_callbacks(function()
		inventory_dialog.mpsafety = mpsafety:constructor()
	end)
end
