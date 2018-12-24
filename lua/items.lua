--! #textdomain "wesnoth-loti"
--
-- Methods to manage the LotI items.
-- Compatible with the WML implementation (uses same Wesnoth variables, etc.).
--
-------------------------------------------------------------------------------
---
--- Glossary:
--- 1) item_sort: entire class of items, e.g. "sword", "armour", "helm", "cloak" (string).
---
--- 2) item_type: specific item, e.g. "Cunctator's sword".
--- Depending on context, represented by item_number or by WML [object] tag.
--- item_type as [object] tag is Lua table { sort = ..., number = ..., name = ..., ... }.
--- item_number is an integer (e.g. 100) that uniquely identifies item_type.
--- To get object from item_number: object = loti.item.type[item_number]
--- To get item_number from object: item_number = object.number
----
--- 3) item: individual item. There can be many items of the same item_type
--- (for example, two different units can carry Cunctator's sword),
--- but their properties are exactly the same.
--- Item is either an [object] tag or item_number (same as "item_type").
---
--- 4) item_storage: items that are currently NOT equipped by any unit.
--- Player has access to the storage and can retrieve any item from it.
--- Can store multiple items of the same type, e.g. five Cunctator's swords.
---
--- 5) items_on_the_ground: items that are lying on the map at certain coordinates.
--- Can be picked by unit if unit is standing on the same tile.
--- Unit can also place an item to the ground.
---
-------------------------------------------------------------------------------

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"
local wml_items = wesnoth.require "lua/wml/items.lua"

loti.item = {}
loti.item.storage = {}
loti.item.type = {}
loti.item.on_unit = {}
loti.item.on_the_ground = {}
loti.item.util = {}

-------------------------------------------------------------------------------
-- loti.item.storage: methods to work with the Item Storage
-------------------------------------------------------------------------------

-- Add item_number to storage.
loti.item.storage.add = function(item_number)
	local list = wesnoth.get_variable("item_storage") or {}
	table.insert(list, {
		loti.item.type[item_number].sort,
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
loti.item.storage.remove = function(item_number)
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
-- Optional parameter: item_sort (string, e.g. "sword") - if present, only items of this sort are returned.
-- Counts the number of items of each type.
-- Returns: Lua array, e.g. { "Cuctator's sword" => 1, "Ice Armour" => 5, ... }.
loti.item.storage.list_items = function(item_sort)
	local list = wesnoth.get_variable("item_storage") or {}
	local results = {}

	for _, elem in ipairs(list) do
		if not item_sort or elem[1] == item_sort then
			local item_number = elem[2].type
			if not results[item_number] then
				results[item_number] = 0
			end

			results[item_number] = results[item_number] + 1
		end
	end

	return results
end

-- Get the list of distinct sorts of all items that are currently in the storage.
-- Counts the number of items of each sort.
-- Returns: Lua array, e.g. { "sword" => 10, "bow" => 12, "armour" => 5, ... }.
loti.item.storage.list_sorts = function()
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

-------------------------------------------------------------------------------
-- loti.item.type: registry of all known item types
-------------------------------------------------------------------------------

-- Pseudo-array of all known item types.
-- Key is item_number.
-- Value is [object] tag (with keys like "name", "sort", "flavour", "image", etc.)
-- E.g. loti.item.type[100] returns { number = 100, name = "Cunctator's sword", sort = "sword", ... }
loti.item.type = setmetatable({}, {
	__index = function(_, item_number)
		local all_known_types = helper.get_variable_array("item_list.object")
		for _, item in ipairs(all_known_types) do
			if item_number == item.number then
				return item
			end
		end

		helper.wml_error("loti.item.type[" .. tostring(item_number) .. "]: not found in item_list.");
	end,
	__newindex = function() error("loti.item.type[] array is read-only.") end
})

-------------------------------------------------------------------------------
-- loti.item.on_unit: methods to work with items that are equipped by some unit
-------------------------------------------------------------------------------

-- Returns the list of all items on the unit (Lua array, each element is [object] tag).
loti.item.on_unit.list = function(unit)
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

-- Add one item to the unit.
-- Optional parameter "crafted_sort" changes the item_sort of item (only for crafted items).
loti.item.on_unit.add = function(unit, item_number, crafted_sort)
	local item = loti.item.type[item_number]

	if item.sort == "weaponword" or item.sort == "armourword" then
		-- Crafted item
		if not crafted_sort then
			helper.wml_error("loti.item.on_unit.add(): item #" .. item_number ..
				' is crafted, but required parameter "crafted_sort" hasn\'t been provided.')
		end

		item.sort = crafted_sort

		-- Crafted non-armours have only 1/3 of the defence of crafted armours.
		if item.sort == "helm" or item.sort == "boots" or item.sort == "gauntlets" then
			item.defence = item.defence / 3
		end
	end

	-- Add extra text to the description (if any).
	if item.flavour then
		item.description = item.description ..
			"\n<span color='#808080'><i>" .. item.flavour .. "</i></span>"
	end

	-- Store the fact "unit has this item" by adding a modification to this unit.
	wesnoth.add_modification(unit, "object", item)

	-- Special handling for Foul Potion (#16): initialize starving counter.
	if item.number == 16 then
		unit.variables.starving = 0
	end

	-- Special handling for Book of Courage (#89): add "fearless" trait.
	if item.number == 89 then
		wesnoth.add_modification(unit, "trait", {
			id = "fearless",
			male_name = _"fearless",
			female_name = _"female^fearless",
			description = _"Fights normally during unfavorable times of day/night",
			wml.tag.effect {
				apply_to = "fearless"
			}
		})
	end

	-- Update stats (recalculate damages, etc.)
	wesnoth.update_stats(unit.__cfg)
end

-- Remove one item from the unit.
loti.item.on_unit.remove = function(unit, item_number)
	wesnoth.remove_modifications(unit, { number = item_number })

	-- Update stats (recalculate damages, etc.)
	wesnoth.update_stats(unit.__cfg)
end

-------------------------------------------------------------------------------
-- loti.item.on_the_ground: methods to work with items lying on the ground
-------------------------------------------------------------------------------

-- Place item on the ground at coordinates (x,y).
loti.item.on_the_ground.add = function(item_number, x, y)
	local list = helper.get_variable_array("items")
	table.insert(list, {
		type = item_number,
		x = x,
		y = y
	})
	helper.set_variable_array("items", list)

	-- Draw the image of this item on the ground
	wml_items.place_image(x, y, loti.item.type[item_number].image)

	-- Enable "pick item" event when some unit walks onto this hex.
	-- (see PLACE_ITEM_EVENT for WML version)
	wesnoth.add_event_handler {
		id = "ie" .. x .. y,
		name = "moveto",
		first_time_only = "no",
		wml.tag.filter {
			x = x,
			y = y,
			wml.tag["not"] {
				wml.tag.filter_wml {
					wml.tag.variables {
						cant_pick = "yes"
					}
				}
			},
			wml.tag.filter_side {
				controller = "human"
			}
		},
		wml.tag.fire_event {
			name = "item_pick",
			wml.tag.primary_unit {
				x = x,
				y = y
			}
		}
	}
end

-- Remove one item from the ground at coordinates (x,y).
loti.item.on_the_ground.remove = function(item_number, x, y)
	local list = helper.get_variable_array("items")

	local index_to_remove = nil
	local items_found = 0

	for index, elem in ipairs(list) do
		if elem.x == x and elem.y == y and elem.type == item_number then
			index_to_remove = index
			items_found = items_found + 1
		end
	end

	if not index_to_remove then
		return
	end

	table.remove(list, index_to_remove)
	helper.set_variable_array("items", list)

	-- Remove the image from the map,
	-- but only if this hex doesn't have other items of the same type.
	if items_found == 1 then
		wml_items.remove(x, y, loti.item.type[item_number].image)
	end
end

-- Get the list of all items in the storage (Lua array, each element is item_number).
loti.item.on_the_ground.list = function(x, y)
	local list = helper.get_variable_array("items")
	local results = {}

	for _, elem in ipairs(list) do
		if elem.x == x and elem.y == y then
			table.insert(results, elem.type)
		end
	end

	return results
end

-------------------------------------------------------------------------------
-- loti.item.util: high-level functions
-- Common interactions between units, item storage and the ground.
-------------------------------------------------------------------------------

-- Remove all items from unit, place them to item storage.
loti.item.util.undress_unit = function(unit)
	for _, item in ipairs(loti.item.on_unit.list(unit)) do
		loti.item.util.take_item_from_unit(unit, item.number)
	end
end

-- Remove one item from unit, place it to the item storage.
loti.item.util.take_item_from_unit = function(unit, item_number)
	loti.item.on_unit.remove(unit, item_number)
	loti.item.storage.add(item_number)
end

-- Remove one item from storage, then open "Pick up item" dialog on behalf of unit.
loti.item.util.get_item_from_storage = function(unit, item_number)
	loti.item.storage.remove(item_number)
	loti.item.on_the_ground.add(item_number, unit.x, unit.y)
	wesnoth.fire_event("item pick", unit.x, unit.y)
end
