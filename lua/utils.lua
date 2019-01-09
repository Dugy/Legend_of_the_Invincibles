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
	local valid = wesnoth.get_unit(unit.id).valid
	if valid == "map" then
		wesnoth.put_unit(unit)
	elseif valid == "recall" then
		wesnoth.put_recall_unit(unit)
	end
end
