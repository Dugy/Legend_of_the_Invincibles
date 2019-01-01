--! #textdomain "wesnoth-loti"
--
-- Functions that manipulate unit inventories and advancements.
-- Note: parameter "user" can accept both WML table and user ID (string).
--

-- Implementation based on the fact that items, effects, etc. are stored
-- as modifications within the WML of the unit.
local wml_based_implementation = {
	-- Returns iterator over items of this unit.
	items = function(unit)
		-- TODO
	end,

	-- Returns iterator over advancements of this unit.
	advancements = function(unit)
		-- TODO
	end,

	-- Returns iterator over effects of this unit.
	effects = function(unit)
		-- TODO
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
