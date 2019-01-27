--! #textdomain "wesnoth-loti"
--
-- Functions that manipulate unit inventories and advancements.
-- Note: parameter "unit" can accept both WML table and unit ID (string).
--

local helper = wesnoth.require "lua/helper.lua"

-- Helper function.
-- Analyze "unit" parameter, which can be WML table or unit ID.
-- Returns WML table.
local function normalize_unit_param(unit)
	if type(unit) == 'table' then
		-- WML table.
		return unit
	end

	-- Unit ID
	return wesnoth.get_unit(unit).__cfg
end

-- Helper function.
-- Construct iterator around some modifications of the unit.
-- Parameters:
-- tag - name of WML tag inside [modifications], e.g. "object" or "advancement".
-- filter (optional) - function that:
-- 1) receives one result (e.g. [object] WML table) as parameter,
-- 2) returns the value that should be returned by iterator, or false if this result must be skipped.
-- (if filter isn't specified, then all values are returned "as is", and nothing gets skipped)
-- Sample usage: for _, advancement in wml_modification_iterator(unit, "advancement")
local function wml_modification_iterator(unit, tag, filter)
	local wml = normalize_unit_param(unit)
	local modifications = helper.get_child(wml, "modifications")
	local elements = helper.child_array(modifications, tag)

	local idx = 0
	return function()
		idx = idx + 1
		while elements[idx] do
			local result = elements[idx]
			if filter then
				-- Allow callback to modify the result
				-- (or return false, which would mean "skip this result")
				result = filter(result)
			end

			if result then
				return idx, result
			end

			-- Element didn't pass a filter function,
			-- e.g. [object] without "sort" key when listing items.
			-- Try the next element.
			idx = idx + 1
		end
	end
end

-- Helper function to obtain a unit type's advancement with a given id

local function get_type_advancement(unit_type, advancement_id)
	local model = wesnoth.unit_types["Advancing" .. unit_type]
	if not model then
		helper.wml_error("get_type_advancement(): advancing unit type for " .. unit_type .. " is not found.")
	end

	for adv in helper.child_range(model.__cfg, "advancement") do
		if adv.id == advancement_id then
			return adv
		end
	end
end

-- Implementation based on the fact that items, effects, etc. are stored
-- as modifications within the WML of the unit.
local wml_based_implementation = {

	-- Get a list of numbers of items on a unit
	list_unit_item_numbers = function(unit)
		local wml = normalize_unit_param(unit)
		local retval = {}
		local mods = helper.get_child(wml, "modifications")
		for i = 1,#mods do
			if mods[i][1] == "object" and mods[i][2].number then
				table.insert(retval, mods[i][2].number)
			end
		end
		return retval
	end,

	-- Transforms latent effects with filled requirements to regular effects
	item_with_set_effects = function(number, set_items)
		local got = loti.item.type[number]
		if not got then
			return nil
		end
		local item = wesnoth.deepcopy(got)

		for i = 1,#item do
			if item[i][1] == "latent" then
				local latent = item[i][2]
				local has = 0
				local required = latent.required or latent.number_required
				if not required then
					helper.wml_error("[latent] of item " .. tostring(item.number) .. " lacks the necessary required= attribute")
				end
				for t in string.gmatch(required, "[^%s,][^,]*") do
					local needed = tonumber(t)
					for j = 1,#set_items do
						if set_items[j] == needed then
							has = has + 1
							break
						end
					end
				end
				local needed = latent.needed or 1
				if has >= needed then
					item[i][1] = "effect"
				end
			end
		end

		return item
	end,

	-- Returns iterator over items of this unit.
	items = function(unit)
		local wml = normalize_unit_param(unit)
		local set_items = loti.unit.list_unit_item_numbers(wml)
		return wml_modification_iterator(wml, "object", function(elem)
			if not elem.number then
				return nil
			end
			local item = loti.unit.item_with_set_effects(elem.number, set_items)
			if item then
				item = wesnoth.deepcopy(item)
				if elem.sort then
					item.sort = elem.sort
				end
				return item
			end
			-- Return nil on failure
		end)
	end,

	-- Returns iterator over advancements of this unit.
	advancements = function(unit)
		local wml = normalize_unit_param(unit)
		local model = wesnoth.unit_types[wml.type]
		return wml_modification_iterator(wml, "advancement", function(elem)
			return get_type_advancement(wml.type, elem.id)
		end)
	end,

	-- Returns iterator over effects of this unit.
	effects = function(unit)
		local wml = normalize_unit_param(unit)
		local model = wesnoth.unit_types[wml.type]
		local modifications = helper.get_child(wml, "modifications")
		local set_items = loti.unit.list_unit_item_numbers(wml)
		local advs = {}
		local objs = {}
		local others = {}
		for i = 1,#modifications do
			if modifications[i][1] == "advancement" then
				table.insert(advs, modifications[i][2])
			elseif modifications[i][1] == "object" then
				table.insert(objs, modifications[i][2])
			else
				table.insert(others, modifications[i][2])
			end
		end
		local adv_ord = 1
		local obj_ord = 1
		local other_ord = 1
		local eff_ord = 0
		local current
		local retval
		local doing = "advs"
		local function add_effect(bump)
			while current[eff_ord] and current[eff_ord][1] ~= "effect" do
				eff_ord = eff_ord + 1
			end
			if not current[eff_ord] then
				current = nil
				bump()
				return retval()
			else
				return current[eff_ord]
			end
		end
		
		retval = function()
			if adv_ord <= #advs then
				if not current then
					current = get_type_advancement(wml.type, advs[adv_ord].id)
					while not current and adv_ord < #advs do
						adv_ord = adv_ord + 1
						current = get_type_advancement(wml.type, advs[adv_ord].id)
					end
					eff_ord = 0
				end
				eff_ord = eff_ord + 1
				if current then
					return add_effect( function() adv_ord = adv_ord + 1 end )
				end
			end
			doing = "objs"
			if obj_ord <= #objs then
				while not current and obj_ord < #objs do
					if objs[obj_ord].number then
						current = loti.unit.item_with_set_effects(objs[obj_ord].number, set_items)
						local sort = objs[obj_ord]
						if current == "armourword" and current.defence and (sort == "boots" or sort == "helm" or sort == "gauntlets") then
							current.defence = current.defence / 3
						end
					else
						current = objs[obj_ord]
					end
					eff_ord = 0
				end
				eff_ord = eff_ord + 1
				if current then
					return add_effect( function() obj_ord = obj_ord + 1 end )
				end
			end
			doing = "others"
			if other_ord <= #others then
				if not current then
					current = others[other_ord]
					eff_ord = 0
				end
				eff_ord = eff_ord + 1
				return add_effect( function() other_ord = other_ord + 1 end )
			end
		end
		return retval
	end,

	-- Add advancement to unit.
	add_advancement = function(unit, advancement_id)
		unit = normalize_unit_param(unit)
		local mods = helper.get_child(unit, "modifications")
		local advancement = get_type_advancement(unit.type, advancement_id)

		if not advancement then
			helper.wml_error("Trying to add non-existent advancement \"" .. tostring(advancement_id) ..
				" to unit " .. unit.id)
		end
		
		table.insert(mods, { "advancement", advancement })
			
		-- Place updated unit back onto the map.
		loti.put_unit(unit)
	end,

	-- Remove advancement from unit.
	remove_advancement = function(unit, advancement_id)
		unit = normalize_unit_param(unit)
		local mods = helper.get_child(unit, "modifications")
		for i = 1,#mods do
			if mods[i][1] == "advancement" and mods[i][2].id == advancement_id then
				table.remove(mods, i)
				break
			end
		end
		
		-- Place updated unit back onto the map.
		loti.put_unit(unit)
	end,

	-- Remove all advancements from unit.
	remove_all_advancements = function(unit)
		unit = normalize_unit_param(unit)
		local mods = helper.get_child(unit, "modifications")
		for i = #mods,1,-1 do
			if mods[i][1] == "advancement" then
				table.remove(mods, i)
			end
		end
		
		-- Place updated unit back onto the map.
		loti.put_unit(unit)
	end,

	-- Add item to unit.
	add_item = function(unit, item_number, item_sort)
		unit = normalize_unit_param(unit)
		local modifications = helper.get_child(unit, "modifications")

		local item = wesnoth.deepcopy(loti.item.type[item_number])
		if item_sort then
			item.sort = item_sort
		end

		table.insert(modifications, wml.tag.object(item))

		-- Place updated unit back onto the map.
		loti.put_unit(unit)
	end,

	-- Remove item from unit.
	remove_item = function(unit, item_number, item_sort)
		unit = normalize_unit_param(unit)
		local mods = helper.get_child(unit, "modifications")
		for i = 1,#mods do
			if mods[i][1] == "object" and mods[i][2].number == item_number and (not item_sort or mods[i][2].sort == item_sort) then
				table.remove(mods, i)
				break
			end
		end
		
		-- Place updated unit back onto the map.
		loti.put_unit(unit)
	end,

	-- Remove all items from unit.
	-- Returns a Lua array of items that were removed.
	remove_all_items = function(unit)
		unit = normalize_unit_param(unit)
		local mods = helper.get_child(unit, "modifications")
		for i = #mods,1,-1 do
			if mods[i][1] == "object" then
				table.remove(mods, i)
			end
		end
		
		-- Place updated unit back onto the map.
		loti.put_unit(unit)
	end,
}

-- Implementation that efficiently stores items, effects, etc. in Lua array.
local lua_based_implementation = {
	-- TODO: implement same methods as in wml_based_implementation.
}

-- Default implementation: WML based.
loti.unit = wml_based_implementation
