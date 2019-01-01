--! #textdomain "wesnoth-loti"
--
-- Functions that manipulate unit inventories and advancements.
-- Note: parameter "user" can accept both WML table and user ID (string).
--

local helper = wesnoth.require "lua/helper.lua"

-- Helper function.
-- Analyze "unit" parameter, which can be WML table or user ID,
-- and return two values: 1) WML table, 2) true if this was user ID, false otherwise.
local function normalize_unit_param(unit)
	local is_user_id = false
	if type(unit) ~= 'table' then
		is_user_id = true
		unit = wesnoth.get_unit(unit).__cfg
	end

	return unit, is_user_id
end

-- Helper function.
-- Construct iterator around some modifications of the unit.
-- Parameters:
-- tag - name of WML tag inside [modifications], e.g. "object" or "advancement".
-- filter_func (optional) - callback which:
-- 1) receives one result (e.g. [object] WML table) as parameter,
-- 2) returns false if this result should be skipped, true otherwise.
-- Sample usage: for _, advancement in wml_modification_iterator(unit, "advancement")
local function wml_modification_iterator(unit, tag, filter_func)
	local wml = normalize_unit_param(unit)
	local modifications = helper.get_child(wml, "modifications")
	local elements = helper.child_array(modifications, tag)

	local idx = 0
	return function()
		idx = idx + 1
		while elements[idx] do
			if not filter_func or filter_func(elements[idx]) then
				return idx, elements[idx]
			end

			-- Element didn't pass a filter function,
			-- e.g. [object] without "sort" key when listing items.
			-- Try the next element.
			idx = idx + 1
		end
	end
end

-- Implementation based on the fact that items, effects, etc. are stored
-- as modifications within the WML of the unit.
local wml_based_implementation = {
	-- Returns iterator over items of this unit.
	items = function(unit)
		return wml_modification_iterator(unit, "object", function(elem) return elem.sort end)
	end,

	-- Returns iterator over advancements of this unit.
	advancements = function(unit)
		return wml_modification_iterator(unit, "advancement")
	end,

	-- Returns iterator over effects of this unit.
	effects = function(unit)
		return wml_modification_iterator(unit, "effect")
	end,

	-- Add advancement to unit.
	add_advancement = function(unit, advancement_id)
		-- TODO
	end,

	-- Remove advancement from unit.
	remove_advancement = function(unit, advancement_id)
		-- TODO
	end,

	-- Remove all advancements from unit.
	remove_all_advancements = function(unit)
		-- TODO
	end,

	-- Add item to unit.
	add_item = function(unit, item_number, item_sort)
		-- TODO
	end,

	-- Remove item from unit.
	remove_item = function(unit, item_number, item_sort)
		-- TODO
	end,

	-- Remove all items from unit.
	-- Returns a Lua array of items that were removed.
	remove_all_items = function(unit)
		-- TODO
	end,

	-- Returns human-readable description of item (string)
	-- with highlighted active bonuses from item sets on this unit.
	describe_equipped_item = function(unit, item_number, item_sort)
		-- TODO
	end
}

-- Implementation that efficiently stores items, effects, etc. in Lua array.
local lua_based_implementation = {
	-- TODO: implement same methods as in wml_based_implementation.
}

-- Default implementation: WML based.
loti.unit = wml_based_implementation
