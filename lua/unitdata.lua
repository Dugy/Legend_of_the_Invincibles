--! #textdomain "wesnoth-loti"
--
-- Functions that manipulate unit inventories and advancements.
-- Note: parameter "unit" can accept both WML table and unit ID (string).
--

local helper = wesnoth.require "lua/helper.lua"

-- Implementation based on the fact that items, effects, etc. are stored
-- as modifications within the WML of the unit.
local wml_based_implementation = wesnoth.require("./unitdata0.lua")

-- Implementation that efficiently stores items, effects, etc. in Lua array.
local lua_based_implementation = wesnoth.require("./unitdata1.lua")

-- Default implementation: WML based.
loti.unit = wml_based_implementation

-- This function is not dependent on implementation.
-- TODO: move it elsewhere (probably to loti.item): unitdata API is about operations on ONE specific unit.
loti.unit.item_with_set_effects =
	function(number, set_items, crafted_sort)
		local item = wesnoth.deepcopy(loti.item.type[number])
		local default_sort = item.sort

		if crafted_sort then
			item.sort = crafted_sort
		end

		if item.defence and default_sort == "armourword" and item.sort ~= "armour" then
			-- Crafted non-armours add only 1/3 of the defence of crafted armours
			item.defence = item.defence / 3
		end

		if not set_items then
			return item
		end

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
	end

-- Helper function to obtain a unit type's advancement with a given id
-- TODO: move it elsewhere: unitdata API is about operations on ONE specific unit.
function loti.util.get_type_advancement(unit_type, advancement_id)
	local model = wesnoth.unit_types["Advancing" .. unit_type] or wesnoth.unit_types[unit_type]
	if not model then
		helper.wml_error("get_type_advancement(): unit type " .. unit_type .. " is not found.")
	end

	for adv in helper.child_range(model.__cfg, "advancement") do
		if adv.id == advancement_id then
			return adv
		end
	end

	-- We must also support fake advancements like "particlestorm" or "ice_dragon_legacy".
	-- They are not selectable in AMLA menu (and are not listed in Advancing type),
	-- but are used as requirement for other advancements.
	-- They don't contain any information except the fact that they are unlocked for this unit.
	return { id = advancement_id }
end
