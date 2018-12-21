--! #textdomain "wesnoth-loti"
--
-- Methods to manage the item storage (items that are currently NOT equipped by any unit).
---

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

function loti_item_storage()
	local storage = {}

	---------- 1. LOW-LEVEL FUNCTIONS -------------------------------------
	--- These functions don't affect any units.

	-- Add item_number to storage.
	storage.add = function(item_number)
		local list = wesnoth.get_variable("item_storage") or {}
		table.insert(list, {
			storage.sort_of(item_number),
			{ type = item_number }
		})

		-- Determine the order of two entries in item_storage[] array.
		local function compare_entries(a, b)
			-- Sort by item number.
			return a[2].type < b[2].type
		end

		table.sort(list, compare_entries)
		wesnoth.set_variable("item_storage", list)
	end

	-- Remove item_number from storage.
	-- If storage has many identical items, only one gets removed.
	storage.remove = function(item_number)
		local list = wesnoth.get_variable("item_storage")

		for index, elem in pairs(list) do
			if elem[2].type == item_number then
				table.remove(list, index)
				break -- Only one item should be removed.
			end
		end

		wesnoth.set_variable("item_storage", list)
	end

	-- Get the list of all items in the storage (Lua array, each element is item_number).
	storage.list_items = function(item_sort)
		-- TODO
		return {}
	end

	-----------------------------------------------------------------------
	---------- 2.HIGH-LEVEL FUNCTIONS -------------------------------------
	--- These functions allow a certain unit to interact with item storage.

	-- Remove all items from unit, place them to item storage.
	storage.undress_unit = function(unit)
		for _, item in ipairs(storage.list_items_on_unit(unit)) do
			storage.take_item_from_unit(unit, item.number)
		end
	end

	-- Remove one item from unit, place it to the item storage.
	storage.take_item_from_unit = function(unit, item_number)
		wesnoth.remove_modifications(unit, { number = item_number })
		storage.add(item_number)
	end

	-- Remove one item from storage, then open "Pick up item" dialog on behalf of unit.
	storage.get_item_from_storage = function(unit, item_number)
		storage.remove(item_number)
		wesnoth.fire_event("item pick", unit.x, unit.y)
	end

	-----------------------------------------------------------------------
	---------- 3. UTILITY FUNCTIONS----------------------------------------
	--- These functions don't use the item storage, but it's convenient to have them here.

	-- Get item sort (e.g. "bow") from item_number.
	storage.sort_of = function(item_number)
		local types = helper.get_variable_array("item_list.object")
		for _, item in ipairs(types) do
			if item_number == item.number then
				return item.sort
			end
		end

		helper.wml_error("sort_of(): item #" .. tostring(item_number) .. " is not found in item_list.");
	end

	-- Returns the list of all items on the unit (Lua array, each element is [object] tag).
	storage.list_items_on_unit = function(unit)
		local items = {}

		local modifications = helper.get_child(unit.__cfg, "modifications")
		for _, object in ipairs(helper.child_array(modifications, "object")) do
			-- There are non-items in object[] array, but they don't have 'sort' key.
			-- Also there are fake items (e.g. sort=quest_effect), but they have 'silent' key.
			-- We also ignore objects without name, because they can't be valid items.
			if object.sort and not object.silent and object.name then
				-- Don't list potions and books.
				if object.sort ~= "potion" and object.sort ~= "limited" then
					table.insert(items, object)
				end
			end
		end

		return items
	end

	-- Allow external caller to use loti_item_storage().list_items() syntax.
	return storage
end
