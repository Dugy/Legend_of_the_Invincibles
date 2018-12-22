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
		local list = wesnoth.get_variable("item_storage") or {}

		for index, elem in ipairs(list) do
			if elem[2].type == item_number then
				table.remove(list, index)
				break -- Only one item should be removed.
			end
		end

		wesnoth.set_variable("item_storage", list)
	end

	-- Get the list of all items in the storage (Lua array, each element is item_number).
	-- Optional parameter: item_sort (string, e.g. "sword") - only items of this sort are returned.
	-- If list_items() is called without parameters, all items in the storage are returned.
	storage.list_items = function(item_sort)
		local list = wesnoth.get_variable("item_storage") or {}
		local results = {}

		for _, elem in ipairs(list) do
			if not item_sort or elem[1] == item_sort then
				table.insert(results, elem[2].type)
			end
		end

		if not item_sort then
			-- Items with the same item_sort are already in correct order,
			-- but when we merge those arrays, result needs to be reordered again.
			-- NOTE: don't confuse item_sort (e.g. "sword") and array sorting.
			table.sort(results)
		end

		return results
	end

	-- Get the list of distinct sorts of all items that are currently in the storage.
	-- Counts the number of items of each sort.
	-- (Lua array, e.g. { "sword" => 10, "bow" => 12, "armour" => 5, ... }).
	storage.list_sorts = function()
		local list = wesnoth.get_variable("item_storage") or {}
		local results = {}

		for _, elem in ipairs(list) do
			local item_sort = elem[1]
			if not results[item_sort] then
				results[item_sort] = 0
			end

			results[item_sort] = results[item_sort] + 1
		end

		return results
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

		-- TODO: must place the item to unit.x, unit.y by putting it into "items" variable
		-- (which lists items on the ground)

		wesnoth.fire_event("item pick", unit.x, unit.y)
	end

	-----------------------------------------------------------------------
	---------- 3. UTILITY FUNCTIONS----------------------------------------
	--- These functions don't use the item storage, but it's convenient to have them here.

	-- Get item sort (e.g. "bow") from item_number.
	storage.sort_of = function(item_number)
		return storage.find_type_by_number(item_number).sort
	end

	-- Find item_number in the list of all known item types.
	-- Returns: [object] tag (with keys like "name", "sort", "flavour", "image", etc.)
	storage.find_type_by_number = function(item_number)
		local types = helper.get_variable_array("item_list.object")
		for _, item in ipairs(types) do
			if item_number == item.number then
				return item
			end
		end

		helper.wml_error("find_type_by_number(): item #" .. tostring(item_number) .. " is not found in item_list.");
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
