-- Useful function taken from elsewhere, can be done also by copying it to WML and getting back, though this is probably faster
function wesnoth.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
	copy = {}
	for orig_key, orig_value in next, orig, nil do
	    copy[wesnoth.deepcopy(orig_key)] = wesnoth.deepcopy(orig_value)
	end
	setmetatable(copy, {wesnoth.deepcopy(getmetatable(orig))})
    else -- number, string, boolean, and so on
	copy = orig
    end
    return copy
end

-- Places a unit back to the game, on the map or to the recall list
loti.put_unit = function(unit)
	if wesnoth.units.get(unit.id) then
		wesnoth.units.to_map(unit)
	elseif wesnoth.units.find_on_recall({ id = unit.id })[1] then
		wesnoth.units.to_recall(unit)
	end

	-- Nothing to do: unit hasn't been created in the game yet,
	-- e.g. this is WML of the updated unit in update_stats()
end

-- Gets a unit and removes it from the game (usually to be placed later), from the map or from the recall list
loti.get_unit = function(unit)
	if unit.x > 0 and unit.y > 0 then
		unit = wesnoth.units.find_on_map{ id = unit.id }[1].__cfg
		wesnoth.units.erase(unit)
	else
		unit = wesnoth.units.find_on_recall{ id = unit.id }[1]
		wesnoth.units.extract(unit)
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
