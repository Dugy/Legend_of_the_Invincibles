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

-- Setup useful item-related constants
sort_list = { "armour", "helm", "boots", "gauntlets", "boots", "gauntlets", "limited", "amulet", "ring", "cloak", "sword", "bow", "axe", "xbow", "dagger", "knife", "spear", "mace", "staff", "polearm", "sling", "exotic", "thunderstick", "claws", "essence" }

weapon_type_list = { "sword", "bow", "axe", "xbow", "dagger", "knife", "spear", "mace", "staff", "polearm", "sling", "exotic", "thunderstick", "claws", "essence" }
melee_type_list = { "sword", "axe", "dagger", "spear", "mace", "staff", "polearm", "exotic", "claws", "essence" }
ranged_type_list = { "bow", "xbow", "knife", "sling", "thunderstick" }

damage_type_list = { "blade", "pierce", "impact", "fire", "cold", "arcane" }
resist_type_list = { "blade_resist", "pierce_resist", "impact_resist", "fire_resist", "cold_resist", "arcane_resist" }
resist_type_descriptions = { _"Resistance to blade", _"Resistance to pierce", _"Resistance to impact", _"Resistance to fire", _"Resistance to cold", _"Resistance to arcane"}
resist_penetrate_list = { "blade_penetrate", "pierce_penetrate", "impact_penetrate", "fire_penetrate", "cold_penetrate", "arcane_penetrate" }
resist_penetrate_descriptions = { _"Enemy resistances to blade", _"Enemy resistances to pierce", _"Enemy resistances to impact", _"Enemy resistances to fire", _"Enemy resistances to cold", _"Enemy resistances to arcane"}

loti.item = {}
loti.item.storage = {}
loti.item.type = {}
loti.item.on_unit = {}
loti.item.on_the_ground = {}
loti.item.util = {}
loti.item.weapon_bindings = {}

-- Blinking animation on the ground hex if there is an item.
loti.item.halo = "halo/misc/leadership-flare-1.png:20,halo/misc/leadership-flare-2.png:20," ..
	"halo/misc/leadership-flare-3.png:20,halo/misc/leadership-flare-4.png:20," ..
	"halo/misc/leadership-flare-4.png:20,halo/misc/leadership-flare-6.png:20," ..
	"halo/misc/leadership-flare-7.png:20,halo/misc/leadership-flare-8.png:20," ..
	"halo/misc/leadership-flare-9.png:20,halo/misc/leadership-flare-10.png:20," ..
	"halo/misc/leadership-flare-11.png:20,halo/misc/leadership-flare-12.png:20," ..
	"halo/misc/leadership-flare-13.png:20,misc/blank-hex.png:1000"

-------------------------------------------------------------------------------
-- loti.item.storage: methods to work with the Item Storage
-------------------------------------------------------------------------------

-- Add item_number to storage.
-- Optional parameter crafted_sort: if present, overrides item_sort of the item.
loti.item.storage.add = function(item_number, crafted_sort)
	local item = loti.item.type[item_number]
	if item.sort == "gold" then
		-- Special case: gold is added directly, not stored in Item Storage.
		local side = wesnoth.sides[wesnoth.current.side]
		side.gold = side.gold + item.gold_quantity
		return
	end

	if item.sort == "gem" then
		-- Special case: gem is added into appropriate variable
		loti.gem.add (item_number - 520, 1)
		return
	end

	local list = wml.variables["item_storage"] or {}

	table.insert(list, {
		crafted_sort or item.sort,
		{ type = item_number }
	})

	-- Determine the order of two entries in item_storage[] array.
	local function compare_entries(a, b)
		-- Sort by item number.
		return a[2].type < b[2].type
	end

	table.sort(list, compare_entries)
	wml.variables["item_storage"] = list
	wesnoth.fire_event("added to storage")
end

-- Remove item_number from storage.
-- If storage has many identical items, only one gets removed.
-- Optional parameter crafted_sort: if present, only item with this item_sort will be removed.
loti.item.storage.remove = function(item_number, crafted_sort)
	local list = wml.variables["item_storage"] or {}

	for index, elem in ipairs(list) do
		if not crafted_sort or elem[1] == crafted_sort then
			if elem[2].type == item_number then
				table.remove(list, index)
				break -- Only one item should be removed.
			end
		end
	end

	wml.variables["item_storage"] = list
	wesnoth.fire_event("removed from storage") -- where is it used?
end

-- Get the list of all items in the storage.
-- Optional parameter: item_sort (string, e.g. "sword") - if present, only items of this sort are returned.
-- Counts the number of items of each type.
-- Returns: Lua array, e.g. { 100 => 1, 15 => 5 } (one Cunctator's sword (#100) and five Ice Armours (#15)).
loti.item.storage.list_items = function(item_sort)
	local list = wml.variables["item_storage"] or {}
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
	local list = wml.variables["item_storage"] or {}
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

-- Internal methods of loti.item.type. Don't use them directly.
loti.item.type = {
	-- Get the list of item types.
	-- Returns Lua table { item_number1 = object1, ... }
	_load = function()
		local self = loti.item.type
		return rawget(self, "_cache") or rawget(self, "_reload")()
	end,

	-- Load the cache of _load() from Wesnoth variable "item_list" (defined in [utils/item_list.cfg]).
	-- Returns Lua table { item_number1 = object1, ... }
	_reload = function()
		local cache = {}

		local all_known_types = wml.array_access.get('item_list.object')
		for _, item in ipairs(all_known_types) do
			cache[item.number] = item
		end

		rawset(loti.item.type, "_cache", cache)
		return cache
	end
}

-- List all valid item_numbers in [start_number; end_number) range.
-- Both parameters are optional.
-- Returns: Lua array { number1, number2, ... }, sorted by number.
loti.item.type.numbers_between = function(start_number, end_number)
	local numbers = {}
	for item_number in pairs(loti.item.type._load()) do
		if not start_number or item_number >= start_number then
			if not end_number or item_number < end_number then
				table.insert(numbers, item_number)
			end
		end
	end

	table.sort(numbers)
	return numbers
end

-- Pseudo-array of all known item types.
-- Key is item_number.
-- Value is [object] tag (with keys like "name", "sort", "flavour", "image", etc.)
-- E.g. loti.item.type[100] returns { number = 100, name = "Cunctator's sword", sort = "sword", ... }
setmetatable(loti.item.type, {
	__index = function(self, item_number)
		return self._load()[item_number] or wml.error(
			"loti.item.type[" .. tostring(item_number) .. "]: not found in item_list."
		)
	end,
	__newindex = function() error("loti.item.type[] array is read-only.") end,

	-- Support "for item_number, item in pairs(loti.item.type)"
	__pairs = function(self)
		return next, self._load(), nil
	end
})

-- WML action [loti_item_type] writes information from loti.item.type[number] into a WML variable.
function wesnoth.wml_actions.loti_item_type(cfg)
	local number = cfg.number or wml.error("[loti_item_type] lacks a required number= key")
	local to_variable = cfg.to_variable or "item_info"

	wml.variables[to_variable] = loti.item.type[number]
end

-------------------------------------------------------------------------------
-- loti.item.on_unit: methods to work with items that are equipped by some unit
-------------------------------------------------------------------------------

-- Returns the list of all items on the unit (Lua array, each element is [object] tag).
-- See also: list_regular().
loti.item.on_unit.list = function(unit)
	local items = {}

	for _, item in loti.unit.items(unit.__cfg) do
		table.insert(items, item)
	end

	return items
end

-- Returns the list of normal (able-to-unequip) items on the unit (Lua array, each element is [object] tag).
-- Unlike list(), this excludes books, potions and temporary items.
loti.item.on_unit.list_regular = function(unit)
	local items = {}

	for _, item in loti.unit.items(unit.__cfg) do
		-- Items without name are likely fake/invisible/temporary items.
		-- Also potions and books can't be unequipped, so we exclude them too.
		local listed = item.name and item.sort ~= "limited" and not item.sort:find("potion")

		if item.sort == "gem" or item.sort == "temporary" then
			listed = false
		end

		if listed then
			table.insert(items, item)
		end
	end

	return items
end

-- Returns the currently equipped item of a certain item_sort on the unit
-- Returns: [object] tag or nil (if not equipped).
loti.item.on_unit.find = function(unit, item_sort)
	for _, item in loti.unit.items(unit.__cfg) do
		if item.sort == item_sort then
			return item
		end
	end
end

-- Internal: call update_stats on Lua unit object.
local function update_stats(unit)
	loti.put_unit(wesnoth.update_stats(unit.__cfg))
end

-- Add one item to the unit.
-- Optional parameter "crafted_sort" changes the item_sort of item (only for crafted items).
loti.item.on_unit.add = function(unit, item_number, crafted_sort)
	-- Store the fact "unit has this item".
	loti.unit.add_item(unit.__cfg, item_number, crafted_sort)

	-- Update stats (recalculate damages, etc.)
	update_stats(unit)
end

-- The same as add but unequips items of this sort if there any (and sort is unequippable)
loti.item.on_unit.add_with_replace = function(unit, item_number, crafted_sort)
	local sort = loti.item.type[item_number]
	if crafted_sort then
		sort = crafted_sort
	end
	if (sort ~= "potion") and (sort ~= "limited") then
		local equipped = loti.item.on_unit.find(unit, sort)
		if equipped then
			loti.item.util.take_item_from_unit(unit, equipped.number, sort)
		end
	end
	-- Store the fact "unit has this item".
	loti.unit.add_item(unit.__cfg, item_number, crafted_sort)

	-- Update stats (recalculate damages, etc.)
	update_stats(unit)
end

-- Remove one item from the unit.
-- Optional parameter "crafted_sort" requires that only item of this sort gets removed.
-- (needed for crafted items: e.g. crafted armour/gauntlets have the same item_number)
-- Optional parameter skip_update (if set) prevents update_stats()
-- after the removal (for better performance when removing many items).
loti.item.on_unit.remove = function(unit, item_number, crafted_sort, skip_update)
	loti.unit.remove_item(unit.__cfg, item_number, crafted_sort)

	-- Update stats (recalculate damages, etc.)
	if not skip_update then
		update_stats(unit)
	end
end

-------------------------------------------------------------------------------
-- loti.item.on_the_ground: methods to work with items lying on the ground
-------------------------------------------------------------------------------

local item_generation_lists = {} -- Lazy loaded

local function randomly_pick_one(choices)
	 return choices[mathx.random(#choices)]
end

-- Randomly generates an item of the given group (each item has to be explicitly defined as part of some group) of one of the item types in the given table
-- Nil as a table does not discriminate by types, a subtable in the table triggers another selection recursively (if picked)
loti.item.on_the_ground.generate = function(group, item_types)
	while type(item_types) == "table" do
		item_types = randomly_pick_one(item_types)
	end

	local sort_selected = item_types or '_any'

	if not item_generation_lists[group] then
		-- This list is not yet calculated. Calculate it now.
		item_generation_lists[group] = { _any = {} }

		for _, item in pairs(loti.item.type) do
			if item[group] then
				if not item_generation_lists[group][item.sort] then
					item_generation_lists[group][item.sort] = {}
				end

				local weight = item[group]

				for _ = 1,weight do
					table.insert(item_generation_lists[group][item.sort], item.number)
					table.insert(item_generation_lists[group]._any, item.number)
				end
			end
		end
	end

	local candidates = item_generation_lists[group][sort_selected]
	if not candidates then
		wesnoth.log("warning", "Couldn't find possible drops of sort=" .. tostring(sort_selected) .. " in drop group=" .. tostring(group))
		candidates = item_generation_lists[group]._any
	end

	return randomly_pick_one(candidates)
end

-- Place item on the ground at coordinates (x,y).
-- Optional parameter crafted_sort: if present, overrides item_sort of the item.
-- Optional parameter turn: if present, overrides current turn.
loti.item.on_the_ground.add = function(item_number, x, y, crafted_sort, turn)
	local record = {
		type = item_number,
		x = x,
		y = y,
		turn = wml.variables["turn_number"]
	}
	if crafted_sort then
		record.sort = crafted_sort
	end
	if turn then
		record.turn = turn
	end

	local list = wml.array_access.get("items")
	table.insert(list, record)
	wml.array_access.set("items", list)

	-- Draw the image of this item on the ground,
	-- plus rare blinking animation (halo) on the same hex.
	wesnoth.wml_actions.item {
		x = x,
		y = y,
		image = loti.item.type[item_number].image,
		halo = loti.item.halo
	}

	if wml.variables["allied_sides"] then
		wesnoth.add_event_handler {
			id = "ie" .. x .. "|" .. y,
			name = "moveto",
			first_time_only = "no",
			wml.tag.filter {
				x = x,
				y = y,
				side = wml.variables["allied_sides"],
				wml.tag["not"] {
					wml.tag.filter_wml {
						wml.tag.variables {
							cant_pick = "yes"
						}
					}
				},
			},
			wml.tag.fire_event {
				name = "item_pick",
				wml.tag.primary_unit {
					x = x,
					y = y
				}
			}
		}
	else
	-- Enable "pick item" event when some unit walks onto this hex.
	-- (see PLACE_ITEM_EVENT for WML version)
	-- this is a LEGACY version, which uses the "controller" side filter
		wesnoth.add_event_handler {
			id = "ie" .. x .. "|" .. y,
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
	wesnoth.fire_event("item drop", x, y) -- where is it used?
end

-- Remove one item from the ground at coordinates (x,y).
-- Optional parameter crafted_sort: if present, only item with this item_sort will be removed.
loti.item.on_the_ground.remove = function(item_number, x, y, crafted_sort)
	local list = wml.array_access.get("items")
	local same_items_found = 0 -- Count the number of items on the same hex.

	local index_to_remove = nil
	for index, elem in ipairs(list) do
		if (elem.x == x) and (elem.y == y) and (elem.type == item_number) then
			-- here is the change in order to be able to pass crafted_sort even for non crafted items
			-- simplifies logic a bit
			if (loti.item.type[elem.type].sort == crafted_sort) or (elem.sort == crafted_sort) then
				index_to_remove = index
				same_items_found = same_items_found + 1
			end
		end
	end

	if not index_to_remove then
		return
	end

	table.remove(list, index_to_remove)
	wml.array_access.set("items", list)

	-- Remove the image from the map,
	-- but only if this hex doesn't have other items of the same type.
	if same_items_found == 1 then
		wesnoth.wml_actions.remove_item {
			x = x,
			y = y,
			image = loti.item.type[item_number].image
		}
	end
end

-- Get the list of all items on the ground at coordinates (x,y).
-- Returns: Lua array, each element is item_number.
loti.item.on_the_ground.list = function(x, y)
	local list = wml.array_access.get("items")
	local results = {}

	for _, elem in ipairs(list) do
		if elem.x == x and elem.y == y then
			table.insert(results, elem.type)
		end
	end

	return results
end

-- The same but returns sorts, useful for manipulating crafted items without workarounds
-- Returns: Lua array, each element is {number = ..., sort = ...}
loti.item.on_the_ground.list_with_sorts = function(x, y)
	local list = wml.array_access.get("items")
	local results = {}

	for _, elem in ipairs(list) do
		if elem.x == x and elem.y == y then
			local item_sort = elem.sort
			if item_sort == nil then
				item_sort = loti.item.type[elem.type].sort
			end
			table.insert(results, {number = elem.type, sort = item_sort})
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
	for _, item in ipairs(loti.item.on_unit.list_regular(unit)) do
		loti.item.util.take_item_from_unit(unit, item.number, item.sort, true)
	end

	update_stats(unit)
end

-- Remove one item from unit, place it to the item storage.
-- Optional parameter crafted_sort: if present, only item with this item_sort will be removed.
-- Optional parameter skip_update: if present, unit stats won't be recalculated afterwards.
loti.item.util.take_item_from_unit = function(unit, item_number, crafted_sort, skip_update)
	loti.item.on_unit.remove(unit, item_number, crafted_sort, skip_update)
	loti.item.storage.add(item_number, crafted_sort)
	wesnoth.fire_event("unequip", unit)
end

-- Remove one item from storage, then open "Pick up item" dialog on behalf of unit.
-- Optional parameter crafted_sort: if present, only item with this item_sort will be removed.
loti.item.util.get_item_from_storage = function(unit, item_number, crafted_sort)
	loti.item.storage.remove(item_number, crafted_sort)
	loti.item.on_the_ground.add(item_number, unit.x, unit.y, crafted_sort)
	wesnoth.fire_event("item pick", unit)
end

-------------------------------------------------------------------------------
-- WML tags based on loti.item methods.
-------------------------------------------------------------------------------

-- Tag [loti_item_storage_add] does the same as loti.item.storage.add().
-- Parameters: cfg.number and cfg.sort.
function wesnoth.wml_actions.loti_item_storage_add(cfg)
	loti.item.storage.add(cfg.number, cfg.sort)
end

-------------------------------------------------------------------------------
-- Generate item descriptions
-------------------------------------------------------------------------------

-- Generate the description of an item
loti.item.describe_item = function(number, sort, set_items)
	local item = loti.unit.item_with_set_effects(number, set_items, sort)
	if item.description_override then
		-- This item has constant (non-calculated) description.
		-- For example, this can be a gem or an item like Book of Courage
		-- ("Unit becomes fearless" instead of the calculated description).
		return item.description_override
	end

	local desc = {}

	if item.defence then
		local defence = math.floor(item.defence)
		if defence > 0 then
			table.insert(desc, "<span color='#60A0FF'>" .. _"Increases physical resistances by " .. tostring(defence) .. "% </span>")
		else
			table.insert(desc, "<span color='#FF60A0'>" .. _"Decreases physical resistances by " .. tostring(defence * -1) .. "% </span>")
		end
	end

	local function describe_damage_modification(variable, ending)
		if variable then
			if variable > 0 then
				table.insert(desc, "<span color='green'>" .. _"Damage increased by " .. tostring(variable) .. ending)
			elseif variable < 0 then
				table.insert(desc, "<span color='red'>" .. _"Damage decreased by " .. tostring(variable * -1) .. ending)
			end
		end
	end
	describe_damage_modification(item.damage, "%</span>")
	describe_damage_modification(item.damage_plus, "</span>")
	describe_damage_modification(item.melee_damage, _"% (melee weapons only)" .. "</span>")
	describe_damage_modification(item.melee_damage_plus, _" (melee weapons only)" .. "</span>")
	describe_damage_modification(item.ranged_damage, _"% (ranged weapons only)" .. "</span>")
	describe_damage_modification(item.ranged_damage_plus, _" (ranged weapons only)" .. "</span>")

	local is_weapon = false
	for i = 1,#weapon_type_list do
		if weapon_type_list[i] == item.sort then
			is_weapon = true
		end
	end
	if item.sort == "weaponword" then
		is_weapon = true
	end
	local function describe_attacks_modification(variable, ending_more, ending_plus_one, ending_fewer, ending_minus_one)
		if variable then
			local ending = ending_fewer
			local color = "red"
			if variable > 1 then
				ending = ending_more
				color = "green"
			elseif variable == 1 then
				ending = ending_plus_one
				color = "green"
			elseif variable == -1 then
				ending = ending_minus_one
				color = "red"
			end

			table.insert(desc, "<span color='" .. color .. "'>" .. math.abs(variable) .. ending .. " </span>")
		end
	end
	if is_weapon then
		describe_attacks_modification(item.attacks,
			_"% more attacks", _"% more attacks", _"% fewer attacks", _"% fewer attacks")
	else
		describe_attacks_modification(item.attacks,
			_" more attacks", _" more attack", _" fewer attacks", _" fewer attack")
	end

	describe_attacks_modification(item.attacks_plus,
		_" more attacks", _" more attack", _" fewer attacks", _" fewer attack")

	if item.merge then
		table.insert(desc, "<span color='green'>" .. _"Merges attacks" .. "</span>")
	end

	if item.damage_type then
		if item.damage_type == "fire" then table.insert(desc, "<span color='green'>" .. _"Sets weapon damage type to fire" .. "</span>")
		elseif item.damage_type == "cold" then table.insert(desc, "<span color='green'>" .. _"Sets weapon damage type to cold" .. "</span>")
		elseif item.damage_type == "arcane" then table.insert(desc, "<span color='green'>" .. _"Sets weapon damage type to arcane" .. "</span>")
		elseif item.damage_type == "blade" then table.insert(desc, "<span color='green'>" .. _"Sets weapon damage type to blade" .. "</span>")
		elseif item.damage_type == "impact" then table.insert(desc, "<span color='green'>" .. _"Sets weapon damage type to impact" .. "</span>")
		elseif item.damage_type == "pierce" then table.insert(desc, "<span color='green'>" .. _"Sets weapon damage type to pierce" .. "</span>")
		elseif item.damage_type == "lightning" then table.insert(desc, "<span color='green'>" .. _"Sets weapon damage type to lightning" .. "</span>") end
	end

	if item.suck then
		table.insert(desc, "<span color='green'>" .. _"Sucks " .. tostring(item.suck) .. _" health from targets with each hit" .. "</span>")
	end

	if item.spell_suck then
		table.insert(desc, "<span color='green'>" .. _"Spells suck " .. tostring(item.spell_suck) .. _" health from targets with each hit" .. "</span>")
	end

	if item.devastating_blow then
		table.insert(desc, "<span color='green'>" .. tostring(item.devastating_blow) .. _"% chance to strike a devastating blow" .. "</span>")
	end

	for i = 1,#damage_type_list do
		if item[resist_type_list[i]] then
			if item[resist_type_list[i]] > 0 then
				table.insert(desc, "<span color='#60A0FF'>" .. resist_type_descriptions[i] .. _" increased by " .. tostring(item[resist_type_list[i]]) .. _"%" .. "</span>")
			else
				table.insert(desc, "<span color='#FF60A0'>" .. resist_type_descriptions[i] .. _" decreased by " .. tostring(item[resist_type_list[i]] * -1) .. _"%" .. "</span>")
			end
		end
		if item[resist_penetrate_list[i]] then
			if item[resist_penetrate_list[i]] > 0 then
				table.insert(desc, "<span color='green'>" .. resist_penetrate_descriptions[i] .. _" decreased by " .. tostring(item[resist_penetrate_list[i]]) .. _"%" .. "</span>")
			else
				table.insert(desc, "<span color='red'>" .. resist_penetrate_descriptions[i] .. _" increased by " .. tostring(item[resist_penetrate_list[i]] * -1) .. _"%" .. "</span>")
			end
		end
	end

	local function add_specials(tag, ending)
		local specials = wml.get_child(item, tag)
		if specials then
			for i = 1,#specials do
				if specials[i][2].name then
					table.insert(desc, "<span color='#C0C000'>" .. _"New weapon special: " .. specials[i][2].name .. ending .. "</span>")
				end
			end
		end
	end
	add_specials("specials", "")
	add_specials("specials_melee", _" (melee weapons only)")
	add_specials("specials_ranged", _" (ranged weapons only)")

	if item.magic then
		table.insert(desc, "<span color='green'>" .. _"Damage of spells increased by " .. tostring(item.magic) .. _"%" .. "</span>")
	end

	if item.dodge then
		table.insert(desc, "<span color='#60A0FF'>" .. _"Chance to get hit decreased by " .. tostring(item.dodge) .. _"%" .. "</span>")
	end

	if item.vision then
		if item.vision > 0 then
			table.insert(desc, "<span color='#FF99CC'>" .. _"Increases vision range by " .. tostring(item.vision) .. "</span>")
		else
			table.insert(desc, "<span color='#804866'>" .. _"Decreases vision range by " .. tostring(item.vision * -1) .. "</span>")
		end
	end

	for i = 1,#item do
		local line
		local effect = item[i][2]
		if effect.desc then
			line = effect.desc -- Mostly for [latent] properties
		elseif item[i][2].apply_to then
			if effect.apply_to == "new_ability" then
				local abilities = wml.get_child(effect, "abilities")
				if abilities then
					for j = 1,#abilities do
						if abilities[j][2].name then
							local ability_desc = "<span color='#C0C000'>" .. _"New ability: " .. abilities[j][2].name .. "</span>"
							if not line then
								line = ability_desc
							else
								line = line .. "\n" .. ability_desc
							end
						end
					end
				end
			elseif effect.apply_to == "movement" then
				if effect.increase == 1 then
					line = "<span color='#FF99CC'>" .. _"1 extra movement point " .. "</span>"
				elseif effect.increase > 1 then
					line = "<span color='#FF99CC'>" .. tostring(effect.increase) .. _" more movement points" .. "</span>"
				elseif effect.increase == -1 then
					line = "<span color='#804866'>" .. _"1 less movement point " .. "</span>"
				else
					line = "<span color='#804866'>" .. tostring(effect.increase * -1) .. _" fewer movement points" .. "</span>"
				end
			elseif effect.apply_to == "hitpoints" then
				local ending
				if effect.times == "per level" then
					ending = _" per level" .. "</span>"
				else
					ending = _"</span>"
				end
				if effect.increase_total then
					if effect.increase_total > 0 then
						line = _"<span color='#60A0FF'>" .. tostring(effect.increase_total) .. _" more hitpoints" .. ending
					else
						line = _"<span color='#FF60A0'>" .. tostring(effect.increase_total * -1) .. _" fewer hitpoints" .. ending
					end
				end
			elseif effect.apply_to == "defense" and wml.get_child(effect, "defense") then
				local def = wml.get_child(effect, "defense")
				local function describe(tag, text)
					if def[tag] then
						if def[tag] > 0 then
							line = "<span color='#FF60A0'>" .. _"Chance to get hit " .. text .. _" increased by " .. tostring(def[tag]) .. "</span>"
						else
							line = "<span color='#60A0FF'>" .. _"Chance to get hit " .. text .. _" decreased by " .. tostring(def[tag] * -1) .. "</span>"
						end
					end
				end
				describe("forest", _"in forests")
				describe("frozen", _"on frozen places")
				describe("flat", _"on flat terrains")
				describe("cave", _"in caves")
				describe("fungus", _"in mushroom groves")
				describe("village", _"in villages")
				describe("castle", _"in castles")
				describe("shallow_water", _"in shallow waters")
				describe("reef", _"on coastal reefs")
				describe("deep_water", _"in deep water")
				describe("swamp_water", _"in swamps")
				describe("hills", _"on hills")
				describe("mountains", _"on mountains")
				describe("sand", _"on sands")
				describe("unwalkable", _"above unwalkable places")
				describe("impassable", _"inside impassable walls")
			elseif effect.apply_to == "movement_costs" and wml.get_child(effect, "movement_costs") then
				local mov = wml.get_child(effect, "movement_costs")
				local function describe(tag, text)
					if mov[tag] then
						if line then
							-- Found more than one "movement costs" bonus.
							line = line .. "\n"
						else
							line = ""
						end

						line = line .. "<span color='#FF99CC'>" .. _"Movement costs " .. text .. _" set to " .. tostring(mov[tag]) .. " " .. "</span>"
					end
				end
				describe("forest", _"through forests")
				describe("frozen", _"on frozen lands")
				describe("flat", _"on flat terrains")
				describe("cave", _"through dark caves")
				describe("fungus", _"through mushroom groves")
				describe("village", _"through villages")
				describe("castle", _"through castles")
				describe("shallow_water", _"in shallow waters")
				describe("reef", _"on coastal reefs")
				describe("deep_water", _"in deep waters")
				describe("swamp_water", _"through swampy places")
				describe("hills", _"on hills")
				describe("mountains", _"on mountains")
				describe("sand", _"across sands")
				describe("unwalkable", _"above unwalkable places")
				describe("impassable", _"through impassable walls")
			elseif effect.apply_to == "alignment" then
				if effect.alignment == "chaotic" then line = "<span color='yellow'>" .. _"Sets alignment to chaotic" .. "</span>"
				elseif effect.alignment == "liminal" then line = "<span color='yellow'>" .. _"Sets alignment to liminal" .. "</span>"
				elseif effect.alignment == "lawful" then line = "<span color='yellow'>" .. _"Sets alignment to lawful" .. "</span>"
				elseif effect.alignment == "neutral" then line = "<span color='yellow'>" .. _"Sets alignment to neutral" .. "</span>" end
			elseif effect.apply_to == "bonus_attack" then
				line = "<span color='green'>" .. _"Bonus attack: " .. effect.description .. "</span>"
			elseif effect.apply_to == "status" and effect.add == "not_living" then
				line = "<span color='#60A0FF'>" .. _"Unlife (immunity to poison, plague and drain)" .. "</span>"
			elseif effect.apply_to == "new_attack" then
				line = "<span color='green'>" .. _"New attack: " .. effect.name .. " (" .. tostring(effect.damage) .. " - " .. tostring(effect.number) .. ")</span>"
			elseif effect.apply_to == "new_advancement" then
				line = "<span color='yellow'>" .. _"New advancements: " .. effect.description .. "</span>"
			end
		end
		if set_items and (effect.required or effect.number_required) and item[i][1] == "effect" then
			line = "<b>" .. line .. "</b>"
		end
		table.insert(desc, line)
	end

	if item.flavour then
		local line = "<span color='#808080'><i>" .. item.flavour .. "</i></span>"
		table.insert(desc, line)
	end

	for i = 1,#desc do
		desc[i] = tostring(desc[i]) -- Convert from translatable string
	end
	local result = table.concat(desc, "\n")
	return result
end

function wesnoth.wml_actions.describe_all_objects(cfg)
	local arrayVar = cfg.array or wml.error("[describe_all_objects] lacks a required array= key")
	local array = wml.array_access.get_proxy(arrayVar)
	for _, item in ipairs(array) do
		item.description = loti.item.describe_item(item.number, item.sort)
	end
end

-- Invalidate cache of loti.item.type[].
-- Used at the end of GENERATE_ITEM_LIST macro,
-- after all [describe_object] tags (they change item descriptions in item_list).
function wesnoth.wml_actions.clear_item_list_cache()
	loti.item.type._reload()
	item_generation_lists = {}
end

function wesnoth.wml_actions.random_item(cfg)
	local item_types = nil
	local item_types_wml = wml.get_child(cfg, "types")
	if item_types_wml then
		item_types = {}
		for _, possibilities in pairs(item_types_wml) do
			local sort_group = {}
			for sort_subgroup in string.gmatch(possibilities, '([^,]+)') do
				table.insert(sort_group, sort_subgroup)
			end
			table.insert(item_types, sort_group)
		end
	end
	local group_name = cfg.group or "drop"
	local generated = loti.item.on_the_ground.generate(group_name, item_types)
	if cfg.variable then
		wml.variables[cfg.variable] = generated
	else
		loti.item.on_the_ground.add(generated, cfg.x, cfg.y, nil, cfg.turn)
	end
end

-- Add a binding "weapon name -> weapon type
function wesnoth.wml_actions.add_weapon_binding(cfg)
	local name = cfg.name or wml.error("[add_weapon_binding] lacks a required name= key")
	local type = cfg.type or "exotic"
	loti.item.weapon_bindings[name] = type
end
