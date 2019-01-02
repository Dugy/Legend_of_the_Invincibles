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

	local list = wesnoth.get_variable("item_storage") or {}

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
	wesnoth.set_variable("item_storage", list)
end

-- Remove item_number from storage.
-- If storage has many identical items, only one gets removed.
-- Optional parameter crafted_sort: if present, only item with this item_sort will be removed.
loti.item.storage.remove = function(item_number, crafted_sort)
	local list = wesnoth.get_variable("item_storage") or {}

	for index, elem in ipairs(list) do
		if not crafted_sort or elem[1] == crafted_sort then
			if elem[2].type == item_number then
				table.remove(list, index)
				break -- Only one item should be removed.
			end
		end
	end

	wesnoth.set_variable("item_storage", list)
end

-- Get the list of all items in the storage.
-- Optional parameter: item_sort (string, e.g. "sword") - if present, only items of this sort are returned.
-- Counts the number of items of each type.
-- Returns: Lua array, e.g. { 100 => 1, 15 => 5 } (one Cunctator's sword (#100) and five Ice Armours (#15)).
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
		local all_known_types = helper.get_variable_array("item_list.object")

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
		return self._load()[item_number] or helper.wml_error(
			"loti.item.type[" .. tostring(item_number) .. "]: not found in item_list."
		)
	end,
	__newindex = function() error("loti.item.type[] array is read-only.") end
})

-------------------------------------------------------------------------------
-- loti.item.on_unit: methods to work with items that are equipped by some unit
-------------------------------------------------------------------------------

-- Returns the list of all items on the unit (Lua array, each element is [object] tag).
-- See also: list_regular().
loti.item.on_unit.list = function(unit)
	local items = {}

	local modifications = helper.get_child(unit.__cfg, "modifications")
	for _, object in ipairs(helper.child_array(modifications, "object")) do
		-- There are non-items in object[] array, but they don't have 'sort' key.
		if object.sort then
			table.insert(items, object)
		end
	end

	return items
end

-- Returns the list of normal (able-to-unequip) items on the unit (Lua array, each element is [object] tag).
-- Unlike list(), this excludes books, potions and temporary items.
loti.item.on_unit.list_regular = function(unit)
	local items = {}

	for _, item in ipairs(loti.item.on_unit.list(unit)) do
		-- Items without name are likely fake/invisible/temporary items.
		-- Also potions and books can't be unequipped, so we exclude them too.
		local listed = item.name and item.sort ~= "limited" and not item.sort:find("potion")

		if listed then
			table.insert(items, item)
		end
	end

	return items
end

-- Returns the currently equipped item of a certain item_sort on the unit
-- Returns: [object] tag or nil (if not equipped).
loti.item.on_unit.find = function(unit, item_sort)
	local items = loti.item.on_unit.list(unit)
	for _, item in ipairs(items) do
		if item.sort == item_sort then
			return item
		end
	end

	return nil -- Not equipped
end

-- Internal: call update_stats on Lua unit object.
local function update_stats(unit)
	local updated = wesnoth.update_stats(unit.__cfg)
	if unit.valid == "map" then
		wesnoth.put_unit(updated)
	end
end

-- Add one item to the unit.
-- Optional parameter "crafted_sort" changes the item_sort of item (only for crafted items).
loti.item.on_unit.add = function(unit, item_number, crafted_sort)
	local item = wesnoth.deepcopy(loti.item.type[item_number])

	if item.sort == "weaponword" or item.sort == "armourword" then
		-- Crafted item
		if not crafted_sort then
			helper.wml_error("loti.item.on_unit.add(): item #" .. item_number ..
				' is crafted, but required parameter "crafted_sort" hasn\'t been provided.')
		end

		item.sort = crafted_sort
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
	update_stats(unit)
end

-- Remove one item from the unit.
-- Optional parameter "crafted_sort" requires that only item of this sort gets removed.
-- (needed for crafted items: e.g. crafted armour/gauntlets have the same item_number)
-- Optional parameter skip_update (if set) prevents update_stats()
-- after the removal (for better performance when removing many items).
loti.item.on_unit.remove = function(unit, item_number, crafted_sort, skip_update)
	local filter = { number = item_number }
	if crafted_sort then
		filter.sort = crafted_sort
	end

	wesnoth.remove_modifications(unit, filter)

	-- Update stats (recalculate damages, etc.)
	if not skip_update then
		update_stats(unit)
	end
end

-------------------------------------------------------------------------------
-- loti.item.on_the_ground: methods to work with items lying on the ground
-------------------------------------------------------------------------------

-- Place item on the ground at coordinates (x,y).
-- Optional parameter crafted_sort: if present, overrides item_sort of the item.
loti.item.on_the_ground.add = function(item_number, x, y, crafted_sort)
	local record = {
		type = item_number,
		x = x,
		y = y
	}
	if crafted_sort then
		record.sort = crafted_sort
	end

	local list = helper.get_variable_array("items")
	table.insert(list, record)
	helper.set_variable_array("items", list)

	-- Draw the image of this item on the ground,
	-- plus rare blinking animation (halo) on the same hex.
	wesnoth.wml_actions.item {
		x = x,
		y = y,
		image = loti.item.type[item_number].image,
		halo = loti.item.halo
	}

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
-- Optional parameter crafted_sort: if present, only item with this item_sort will be removed.
loti.item.on_the_ground.remove = function(item_number, x, y, crafted_sort)
	local list = helper.get_variable_array("items")
	local same_items_found = 0 -- Count the number of items on the same hex.

	local index_to_remove = nil
	for index, elem in ipairs(list) do
		if elem.x == x and elem.y == y and elem.type == item_number then
			if not crafted_sort or elem.sort == crafted_sort then
				index_to_remove = index
				same_items_found = same_items_found + 1
			end
		end
	end

	if not index_to_remove then
		return
	end

	table.remove(list, index_to_remove)
	helper.set_variable_array("items", list)

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
end

-- Remove one item from storage, then open "Pick up item" dialog on behalf of unit.
-- Optional parameter crafted_sort: if present, only item with this item_sort will be removed.
loti.item.util.get_item_from_storage = function(unit, item_number, crafted_sort)
	loti.item.storage.remove(item_number, crafted_sort)
	loti.item.on_the_ground.add(item_number, unit.x, unit.y, crafted_sort)
	wesnoth.fire_event("item pick", unit.x, unit.y)
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
-- Generate item desciptions
-------------------------------------------------------------------------------

-- Generate the description of an item
loti.item.describe_item = function(number, sort, set_items)
	local item = loti.item.type[number]
	if item.description then
		return item.description -- Already has one (for manually set one)
	end
	local desc = {}

	if item.defence then
		local defence = item.defence
		if item.sort == "armourword" and (sort == "boots" or sort == "helm" or sort == "gauntlets") then
			defence = defence / 3
		end
		if defence > 0 then
			table.insert(desc, _"<span color='#60A0FF'>Increases physical resistances by " .. tostring(defence) .. "% </span>")
		else
			table.insert(desc, _"<span color='#60A0FF'>Decreases physical resistances by " .. tostring(defence * -1) .. "% </span>")
		end
	end

	local function describe_damage_modification(variable, ending)
		if variable then
			if variable > 0 then
				table.insert(desc, _"<span color='green'>Damage increased by " .. tostring(variable) .. ending)
			else
				table.insert(desc, "<span color='green'>Damage decreased by " .. tostring(variable * -1) .. ending)
			end
		end
	end
	describe_damage_modification(item.damage, _"%</span>")
	describe_damage_modification(item.damage_plus, _"</span>")
	describe_damage_modification(item.melee_damage, _"% (melee attacks only)</span>")
	describe_damage_modification(item.melee_damage_plus, _" (melee attacks only)</span>")
	describe_damage_modification(item.ranged_damage, _"% (ranged attacks only)</span>")
	describe_damage_modification(item.ranged_damage_plus, _" (ranged attacks only)</span>")

	local is_weapon = false
	for i = 1,#weapon_type_list do
		if weapon_type_list[i] == item.sort then
			is_weapon = true
		end
	end
	local function describe_attacks_modification(variable, ending, ending_fewer)
		if variable then
			if variable > 0 then
				table.insert(desc, _"<span color='green'>" .. tostring(variable) .. ending)
			else
				table.insert(desc, _"<span color='green'>" .. tostring(variable * -1) .. ending_fewer)
			end
		end
	end	
	if is_weapon then
		describe_attacks_modification(item.attacks, _"% more attacks </span>", _"% fewer attacks </span>")
	else
		describe_attacks_modification(item.attacks, _" more attacks </span>", _" fewer attacks </span>")
	end
	describe_attacks_modification(item.attacks_plus, _" more attacks </span>", _" fewer attacks </span>")

	if item.merge then
		table.insert(desc, _"<span color='green'>Merges attacks</span>")
	end

	if item.damage_type then
		if item.damage_type == "fire" then table.insert(desc, _"<span color='green'>Sets weapon damage type to fire</span>")
		elseif item.damage_type == "cold" then table.insert(desc, _"<span color='green'>Sets weapon damage type to cold</span>")
		elseif item.damage_type == "arcane" then table.insert(desc, _"<span color='green'>Sets weapon damage type to arcane</span>")
		elseif item.damage_type == "blade" then table.insert(desc, _"<span color='green'>Sets weapon damage type to blade</span>")
		elseif item.damage_type == "impact" then table.insert(desc, _"<span color='green'>Sets weapon damage type to impact</span>")
		elseif item.damage_type == "pierce" then table.insert(desc, _"<span color='green'>Sets weapon damage type to pierce</span>")
		elseif item.damage_type == "lightning" then table.insert(desc, _"<span color='green'>Sets weapon damage type to lightning</span>") end
	end

	if item.suck then
		table.insert(desc, _"<span color='#60A0FF'>Sucks " .. tostring(item.suck) .. _" health from targets with each hit</span>")
	end

	if item.spell_suck then
		table.insert(desc, _"<span color='#60A0FF'>Spells suck " .. tostring(item.spell_suck) .. _" health from targets with each hit</span>")
	end

	if item.devastating_blow then
		table.insert(desc, _"<span color='#60A0FF'>" .. tostring(item.devastating_blow) .. _"% chance to strike a devastating blow</span>")
	end

	for i = 1,#damage_type_list do
		if item[resist_type_list[i]] then
			if item[resist_type_list[i]] > 0 then
				table.insert(desc, _"<span color='#60A0FF'>" .. resist_type_descriptions[i] .. _" increased by " .. tostring(item[resist_type_list[i]]) .. _"%</span>")
			else
				table.insert(desc, _"<span color='#60A0FF'>" .. resist_type_descriptions[i] .. _" decreased by " .. tostring(item[resist_type_list[i]] * -1) .. _"%</span>")
			end
		end
		if item[resist_penetrate_list[i]] then
			if item[resist_penetrate_list[i]] > 0 then
				table.insert(desc, _"<span color='green'>" .. resist_penetrate_descriptions[i] .. _" decreased by " .. tostring(item[resist_penetrate_list[i]]) .. _"%</span>")
			else
				table.insert(desc, _"<span color='green'>" .. resist_penetrate_descriptions[i] .. _" increased by " .. tostring(item[resist_penetrate_list[i]] * -1) .. _"%</span>")
			end
		end
	end

	local function add_specials(tag, ending)
		local specials = helper.get_child(item, tag)
		if specials then
			for i = 1,#specials do
				if specials[i][2].name then
					table.insert(desc, "<span color='green'>New weapon special: " .. specials[i][2].name .. ending)
				end
			end
		end
	end
	add_specials("specials", "</span>")
	add_specials("specials_melee", " (melee weapons only)</span>")
	add_specials("specials_ranged", " (ranged weapons only)</span>")

	if item.vision then
		if item.vision > 0 then
			table.insert(desc, _"<span color='#60A0FF'>Increases vision range by " .. tostring(item.vision) .. _"</span>")
		else
			table.insert(desc, _"<span color='#60A0FF'>Decreases vision range by " .. tostring(item.vision * -1) .. _"</span>")
		end
	end

	for i = 1,#item do
		local line
		local effect = item[i][2]
		if effect.desc then
			line = effect.desc -- Mostly for [latent] properties
		elseif item[i][2].apply_to then
			if effect.apply_to == "new_ability" then
				local abilities = helper.get_child(effect, "abilities")
				if abilities then
					for j = 1,#abilities do
						if abilities[j][2].name then
							line = _"<span color='#60A0FF'>New ability: " .. abilities[j][2].name .. _"</span>"
						end
					end
				end
			elseif effect.apply_to == "movement" then
				if effect.increase == 1 then
					line = _"<span color='#60A0FF'>1 extra movement point </span>"
				elseif effect.increase > 1 then
					line = _"<span color='#60A0FF'>" .. tostring(item.vision) .. _"more movement points</span>"
				elseif effect.increase == -1 then
					line = _"<span color='#60A0FF'>1 less movement point </span>"
				else
					line = _"<span color='#60A0FF'>" .. tostring(effect.increase * -1) .. _" fewer movement points</span>"
				end
			elseif effect.apply_to == "hitpoints" then
				local ending
				if effect.times == "per level" then
					ending = _" per level</span>"
				else
					ending = _"</span>"
				end
				if effect.increase_total then
					if effect.increase_total > 0 then
						line = _"<span color='#60A0FF'>" .. tostring(effect.increase_total) .. _" more hitpoints" .. ending
					else
						line = _"<span color='#60A0FF'>" .. tostring(effect.increase_total * -1) .. _" fewer hitpoints" .. ending
					end
				end
			elseif effect.apply_to == "defense" and helper.get_child(effect, "defense") then
				local def = helper.get_child(effect, "defense")
				local function describe(tag, text)
					if def[tag] then
						if def[tag] > 0 then
							line = _"<span color='#60A0FF'>Chance to get hit " .. text .. _" increased by " .. tostring(def[tag]) .. " </span>"
						else
							line = _"<span color='#60A0FF'>Chance to get hit " .. text .. _" decreased by " .. tostring(def[tag] * -1) .. " </span>"
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
			elseif effect.apply_to == "movement_costs" and helper.get_child(effect, "movement_costs") then
				local mov = helper.get_child(effect, "movement_costs")
				local function describe(tag, text)
					if mov[tag] then
						line = _"<span color='#60A0FF'>Movement costs " .. text .. _" set to " .. tostring(mov[tag]) .. " </span>"
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
				if effect.alignment == "chaotic" then line = _"<span color='green'>Sets alignment to chaotic</span>"
				elseif effect.alignment == "liminal" then line = _"<span color='green'>Sets alignment to liminal</span>"
				elseif effect.alignment == "lawful" then line = _"<span color='green'>Sets alignment to lawful</span>"
				elseif effect.alignment == "neutral" then line = _"<span color='green'>Sets alignment to neutral</span>" end
			elseif effect.apply_to == "bonus_attack" then
				line = _"<span color='geen'>Bonus attack: " .. effect.description .. " </span>"
			elseif effect.apply_to == "status" and effect.add == "not_living" then
				line = _"<span color='#60A0FF'>Unlife (immunity to poison, plague and drain)</span>"
			elseif effect.apply_to == "new_attack" then
				line = _"<span color='green'>New attack: " .. effect.name .. " (" .. tostring(effect.damage) .. _" - " .. tostring(effect.number) .. _")</span>"
			elseif effect.apply_to == "new_advancement" then
				line = _"<span color='yellow'>New advancements: " .. effect.description .. _"</span>"
			end
		end
		if effect.required and set_items then
			local fulfilled = 0
			for num in string.gmatch(effect.required, "[^%s,][^,]*") do
				local sought = tonumber(num)
				for i = 1,#set_items do
					if set_items[i] == sought then
						fulfilled = fulfilled + 1
						break
					end
				end
			end
			if (not effect.needed and fulfilled >= 1) or (effect.needed and fulfilled >= effect.needed) then
				line = "<b>" .. line .. "</b>"
			end
		end
		table.insert(desc, line)
	end
	for i = 1,#desc do
		desc[i] = tostring(desc[i]) -- Convert from translatable string
	end
	local result = table.concat(desc, "\n")
	return result
end

function wesnoth.wml_actions.describe_object(cfg)
	local number = cfg.number or helper.wml_error("[describe_object] lacks a required number= key")
	local sort = cfg.sort or "unspecified"
	local output = cfg.output or "object_description"
	local result = loti.item.describe_item(number, sort)
	wesnoth.set_variable(output, result)
end
