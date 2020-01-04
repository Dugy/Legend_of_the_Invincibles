-- TODO: implement same methods as in wml_based_implementation.
-- TODO: implement automatic import from WML storage to Lua storage (for existing saves)

local helper = wesnoth.require "lua/helper.lua"
local wml_based_implementation = wesnoth.require("./unitdata0.lua") -- Will be used for import

---------------------------------------------------------------------------------------------------

-- Format of this Lua storage:
-- global_storage = {
--	unit_id1 = { items = { item1, item2, ... }, advancements = { adv1, adv2, ... }, other = { other1, other2, ... } },
--	unit_id2 = ...
-- }
-- Note that this array is internal to Lua and is NOT a valid WML table.
local global_storage = {}

G = global_storage -- FIXME: Temporarily (for debugging), remove once not needed

-- Helper function.
-- Analyze "unit" parameter, which can be WML table or unit ID.
-- Returns its storage (Lua table).
local function find_storage_for(unit)
	unit = unit.id or unit

	if not global_storage[unit] then
		global_storage[unit] = {
			items = {},
			advancements = {},
			other = {}
		}
	end

	return global_storage[unit]
end

-- Utility function. Returns stateful version of next() for { number => value } array.
-- Example:
--	f = nextval({ 'a', 'b', 'c' })
--	print(f()) -- Prints "1 a"
--	print(f()) -- Prints "2 b"
-- Optional parameter "filter" - function that:
-- 1) receives one result (e.g. Lua table) as parameter,
-- 2) returns the value that should be returned by iterator, or false if this result must be skipped.
local function nextval(array, filter)
	local idx = 0
	return function()
		idx = idx + 1

		local result = array[idx]
		if result and filter then
			-- Allow callback to modify the result
			-- (or return false, which would mean "skip this result")
			result = filter(result)
		end

		if result then
			return idx, result
		end
	end
end

-- Returns stateful function that provides the next effect found in modifications_array.
-- Parameter: modifications_array - Lua array of elements that can have "effects" key.
-- Note: unlike normal iterators, returned function does NOT return the index, only the value.
local function next_effect(modifications_array)
	local next_effect_internal = function() end
	local next_modification = nextval(modifications_array)

	return function()
		while true do
			local _, effect = next_effect_internal()
			if effect then
				return effect -- Found another effect
			end

			-- Try next modification
			local _, modif = next_modification()
			if not modif then
				return -- Nothing more to return
			end

			-- First check the modern Lua storage format
			local effects = helper.child_array(modif, "effect")

			if not effects[1] and modif[1] and modif[2][1] then
				-- WML storage, still used for effects from [trait] tags, etc.,
				-- because traits like "strong" are added by Wesnoth itself (not our code).
				effects = helper.child_array(modif[2], "effect")
			end

			next_effect_internal = nextval(effects)
		end
	end
end

-- Implementation that efficiently stores items, effects, etc. in Lua array.
local lua_based_implementation = {
	items = function(unit)
		local set_items = lua_based_implementation.list_unit_item_numbers(unit)
		return nextval(
			find_storage_for(unit).items,
			function(elem)
				return loti.unit.item_with_set_effects(elem.number, set_items, elem.sort)
			end
		)
	end,

	advancements = function(unit) return nextval(find_storage_for(unit).advancements) end,

	effects = function(unit)
		local storage = find_storage_for(unit)

		-- TODO: avoid recalculation of items_with_set_effects[].
		-- This should be cached, and the cache should be invalidated in add_()/remove_() functions.
		local items_with_set_effects = {}
		for _, item in lua_based_implementation.items(unit) do
			table.insert(items_with_set_effects, item)
		end

		local item_effect = next_effect(items_with_set_effects)
		local adv_effect = next_effect(storage.advancements)
		local other_effect = next_effect(storage.other)

		local unit_wml = wesnoth.get_unit(unit.id or unit) -- FIXME: ugly (need normalize function like in WML implementation). What about items on recall list?
		local wml_based_effect = next_effect(helper.get_child(unit_wml.__cfg, "modifications"))

		local idx = 0
		return function()
			local val = wml_based_effect() or adv_effect() or item_effect() or other_effect()
			if val then
				idx = idx + 1
				return idx, val
			end
		end
	end,

	list_unit_item_numbers = function(unit)
		local retval = {}
		for _, item in ipairs(find_storage_for(unit).items) do
			table.insert(retval, item.number)
		end
		return retval
	end,

	-- TODO: effect_containers(unit) - ? (not documented in original API)

	add_advancement = function(unit, advancement_id)
		local unit_type = wesnoth.get_unit(unit.id or unit).type -- FIXME: ugly. What about items on recall list?
		local adv = loti.util.get_type_advancement(unit_type, advancement_id)
		table.insert(find_storage_for(unit).advancements, adv)
	end,

	-- Remove advancement from unit.
	remove_advancement = function(unit, advancement_id)
		local storage = find_storage_for(unit)

		for idx, adv in ipairs(storage.advancements) do
			if adv.id == advancement_id then
				table.remove(storage.advancements, idx)
				break
			end
		end
	end,

	remove_all_advancements = function(unit)
		find_storage_for(unit).advancements = {}
	end,

	remove_all_items = function(unit)
		find_storage_for(unit).items = {}
	end,

	add_item = function(unit, item_number, item_sort)
		local storage = find_storage_for(unit)

		local item = wesnoth.deepcopy(loti.item.type[item_number])
		if item_sort then
			item.sort = item_sort
		end

		-- TODO: call on_equip(), like in WML implementation.
		-- FIXME: calling on_equip() should be an external function that we'll call here!

		table.insert(storage.items, item)
	end,

	remove_item = function(unit, item_number, item_sort)
		local storage = find_storage_for(unit)

		for idx, item in ipairs(storage.items) do
			if item.number == item_number and (not item_sort or item.sort == item_sort) then
				table.remove(storage.items, idx)
				break
			end
		end
	end
}

return lua_based_implementation
