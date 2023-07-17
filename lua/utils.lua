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

-- [deny_undo] tag to force disable undo
function wesnoth.wml_actions.deny_undo()
    wesnoth.allow_undo(false)
end

-- [is_in_list] tag checks to see if required string= is a member of a comma separated list=
-- Returns true/false (yes/no in wml) in required to_variable.
-- Does not handle empty entries ("" is NOT considered in "cat,,dog")
function wesnoth.wml_actions.is_in_list(cfg)
	local list=cfg.list or wml.error("[is_in_list]: missing required list=")
	local string=tostring(cfg.string) or wml.error("[is_in_list]: missing required string=")
	local to_variable=cfg.to_variable or wml.error("[is_in_list]: missing required to_variable=")

	local ret=false
	for w in string.gmatch(list, "[%w%s]+") do
		if (w == string) then
			ret=true
			break
		end
	end
	wml.variables[to_variable]=ret
end

-- [sort_unit_list] Sorts array of units by name/type
-- Requires unit_list=
-- Returns sorted list in WML variable to_variable, or in unit_list if to_variable not supplied
function wesnoth.wml_actions.sort_unit_list(cfg)
	local unit_list=cfg.unit_list or wml.error("[sort_unit_list]: missing required unit_list=")
	local to_variable=cfg.to_variable

	if not to_variable then to_variable=unit_list end

	local ul=wml.array_access.get(unit_list) or wml.error("[sort_unit_list]: error retrieving " .. unit_list)

	-- Sort units alphabetically with named units first as they are more likely to be used.
	-- If two units share the same name (including/especially ""), sort them by unit type.
	table.sort(ul, function (a, b)
		local aname=tostring(a.name)  -- sort gets mad if one name is translatable and the other is not
		local bname=tostring(b.name)  -- so compare aname/bname instead of a.name/b.name
		if ((a.name ~= "") and (b.name ~= "")) then
			return ((aname < bname) or ((aname == bname) and (a.language_name < b.language_name)))
		elseif ((a.name ~= "") and (b.name == "")) then return true
		elseif ((a.name == "") and (b.name ~= "")) then return false
		else return (a.language_name < b.language_name)
		end
	end )

	wml.array_access.set(to_variable, ul)
end
