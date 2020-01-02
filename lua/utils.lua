local helper = wesnoth.require "lua/helper.lua"

-- Useful function taken from elsewhere, can be done also by copying it to WML and getting back, though this is probably faster
function wesnoth.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
	copy = {}
	for orig_key, orig_value in next, orig, nil do
	    copy[wesnoth.deepcopy(orig_key)] = wesnoth.deepcopy(orig_value)
	end
	setmetatable(copy, wesnoth.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, and so on
	copy = orig
    end
    return copy
end

-- Places a unit back to the game, on the map or to the recall list
loti.put_unit = function(unit)
	local proxy = wesnoth.get_unit(unit.id) or wesnoth.get_recall_units({ id = unit.id })[1]
	if not proxy then
		-- Unit hasn't been created in the game yet,
		-- e.g. this is WML of the updated unit in update_stats()
		return
	end

	local valid = proxy.valid
	if valid == "map" then
		wesnoth.put_unit(unit)
	elseif valid == "recall" then
		wesnoth.put_recall_unit(unit)
	end
end

-- Gets a unit and removes it from the game (usually to be placed later), from the map or from the recall list
loti.get_unit = function(unit)
	if unit.x > 0 and unit.y > 0 then
		unit = wesnoth.get_units{ id = unit.id }[1].__cfg
		wesnoth.erase_unit(unit)
	else
		unit = wesnoth.get_recall_units{ id = unit.id }[1]
		wesnoth.extract_unit(unit)
		unit= unit.__cfg
	end
	return unit
end

-- Executes a block of WML code
loti.execute = function(code)
	for i = 1,#code do
		wesnoth.fire(code[i][1], code[i][2])
	end
end
