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
-- Note that this array is internal to Lua and is NOT a valid WML table,
-- but the elements "item1", 'adv1", "other1", etc. MUST BE valid WML tables.
local global_storage = {}

G = global_storage -- FIXME: Temporarily (for debugging), remove once not needed


-- Helper function.
-- Analyze "unit" parameter, which can be WML table or unit ID.
-- Returns its storage (Lua table).
local function find_storage_for(unit)
	local unit_id = unit.id or unit

	if not global_storage[unit_id] then
		global_storage[unit_id] = {
			items = {},
			advancements = {},
			other = {}
		}
	end

	return global_storage[unit_id]
end

-- When saving the game: serialize "global_storage" variable into the proper WML.
function wesnoth.persistent_tags.unitdata.write(add)
	if not next(global_storage) then
		return -- Empty (nothing to save), e.g. when WML implementation of unitdata is used.
	end

	for unit_id, storage in pairs(global_storage) do
		local serialized = { id = unit_id } -- Proper WML

		for category, elements in pairs(storage) do
			for _, element in ipairs(elements) do
				table.insert(serialized, wml.tag[category](element))
			end
		end

		add(serialized)
	end
end

-- When loading a save: populate "global_storage" variable from contents of save file.
function wesnoth.persistent_tags.unitdata.read(cfg)
	local storage = find_storage_for(cfg.id)

	for _, element in ipairs(cfg) do
		local category = element[1]
		local contents = element[2]

		table.insert(storage[category], contents)
	end
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
local function next_effect(modifications_array)
	local next_effect_internal = function() end
	local next_modification = nextval(modifications_array)

	local idx = 0
	return function()
		while true do
			local _, effect = next_effect_internal()
			if effect then
				idx = idx + 1
				return idx, effect -- Found another effect
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

	advancements = function(unit)
		local proxy = wesnoth.get_unit(unit.id or unit) -- FIXME: ugly. What about items on recall list?
		if not proxy then
			return function() end
		end

		return nextval(
			find_storage_for(unit).advancements,
			function(elem)
				return loti.util.get_type_advancement(proxy.type, elem.id)
			end
		)
	end,

	-- Iterator over ALL objects of this item, including items, advancements, etc.
	effect_containers = function(unit)
		local next_item = lua_based_implementation.items(unit)
		local next_advancement = lua_based_implementation.advancements(unit)
		local next_other = nextval(find_storage_for(unit).other)

		local next_wml_object = function() end

		local proxy = wesnoth.get_unit(unit.id or unit) -- FIXME: ugly (need normalize function like in WML implementation). What about items on recall list?
		if proxy then
			next_wml_object = nextval(helper.child_array(proxy.__cfg, "modifications"))
		end

		local idx = 0
		return function()
			local _, val = next_wml_object()

			if val then
				if not val[1] then -- WML sometimes has empty [modification] tags, skip them
					val = nil
				else
					-- Remove the WML wrapper over the tag:
					-- must return { id=something }, not { [1] = { "trait", { id=something... } } }
					val = val[1][2]
				end
			end

			if not val then _, val = next_advancement() end
			if not val then _, val = next_item() end
			if not val then _, val = next_other() end

			if val then
				idx = idx + 1
				return idx, val
			end
		end
	end,

	effects = function(unit)
		local containers = {}
		for _, object in lua_based_implementation.effect_containers(unit) do
			table.insert(containers, object)
		end

		return next_effect(containers)
	end,

	list_unit_item_numbers = function(unit)
		local retval = {}
		for _, item in ipairs(find_storage_for(unit).items) do
			table.insert(retval, item.number)
		end
		return retval
	end,

	add_advancement = function(unit, advancement_id)
		table.insert(find_storage_for(unit).advancements, { id = advancement_id })
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

	remove_all_items = function(unit, filter_func)
		local storage = find_storage_for(unit)

		for idx = #storage.items, 1, -1 do
			if not filter_func or filter_func(storage.items[idx]) then
				table.remove(storage.items, idx)
			end
		end
	end,

	add_item = function(unit, item_number, item_sort)
		table.insert(find_storage_for(unit).items, {
			number = item_number,
			sort = item_sort or loti.item.type[item_number].sort
		})

		-- TODO: call on_equip(), like in WML implementation.
		-- FIXME: calling on_equip() should be an external function that we'll call here!
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
