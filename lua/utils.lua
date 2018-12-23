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
