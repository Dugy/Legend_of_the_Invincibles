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

-- is_in_list checks to see if required cfg.string is a member of a comma separated l cfg.list
-- Does not handle empty entries ("" is NOT considered to be in "cat,,dog")
local function is_in_list(cfg)
	local list=cfg.list or wml.error("is_in_list: missing required cfg.list")
	local string=tostring(cfg.string) or wml.error("is_in_list: missing required cfg.string")

	for w in string.gmatch(list, "[%w%s%^]+") do
		if (w == string) then
			return true
		end
	end
	return false
end


-- [is_in_list] tag checks to see if required string= is a member of a comma separated list=
-- Returns true/false (yes/no in wml) in required to_variable.
-- Does not handle empty entries ("" is NOT considered to be in "cat,,dog")
function wesnoth.wml_actions.is_in_list(cfg)
	local to_variable=cfg.to_variable or wml.error("[is_in_list]: missing required to_variable=")
	if (cfg.list == nil) then wml.error("[is_in_list]: missing required list=") end
	if (cfg.string == nil) then wml.error("[is_in_list]: missing required string=") end

	local ret=is_in_list(cfg)
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

-- [make_units_wander] Moves units randomly around the map
function wesnoth.wml_actions.make_units_wander(cfg)
	local min_x=0
	if (cfg.min_x ~= nil) then min_x=cfg.min_x end
	local max_x=cfg.max_x  -- should get default from map size
	local min_y=0
	if (cfg.min_y ~= nil) then min_y=cfg.min_y end
	local max_y=cfg.max_y  -- should get default from map size
	local avoid_terrain_list=cfg.avoid_terrain_list
	local radius=3
	if (cfg.radius ~= nil) then radius=cfg.radius end
	local filter=wml.get_child(cfg, "filter")

	local units=wesnoth.units.find_on_map(filter)
	        if #units < 1 then
                wml.error("[make_units_wander]: no units found, check [filter]")
        end

	for _, unit in pairs(units) do

		--print(string.format("Considering unit %s, x,y=%d,%d",unit.id,unit.x,unit.y))
		local moveto_x=unit.__cfg.x + math.random(0-radius,radius)
		local moveto_y=unit.__cfg.y + math.random(0-radius,radius)

		local target_terrain=wesnoth.current.map[{moveto_x,moveto_y}]

		local doit=false
		if ((moveto_x>min_x) and (moveto_x<=max_x) and (moveto_y>min_y) and (moveto_y<=max_y)) then doit=true end

		if (avoid_terrain_list ~= nil) and (doit == true) then
			if is_in_list({list=avoid_terrain_list,string=target_terrain}) then doit=false end
		end

		--if not doit then print(string.format("    not moving %s from %d,%d to %d,%d",unit.id,unit.x,unit.y,moveto_x,moveto_y)) end
		if doit then
			--print(string.format("    moving %s from %d,%d to %d,%d",unit.id,unit.x,unit.y,moveto_x,moveto_y))
			wml.fire("move_unit",{id=unit.id, to_x=moveto_x, to_y=moveto_y})
		end
	end
end
