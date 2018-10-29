local helper = wesnoth.require "lua/helper.lua"

function wesnoth.dbms(lua_var, clear, name, onscreen, wrap, only_return)
	if type(clear) ~= "boolean" then clear = true end
	if type(name) ~= "string" then name = "lua_var" end
	if type(onscreen) ~= "boolean" then onscreen = true end

	local function dump_userdata(data)
		local metatable = getmetatable(data)
		if metatable == "side" then return data.__cfg, true end
		if metatable == "unit" then return data.__cfg, true end
		local data_to_string = tostring(data)
		if metatable == "translatable string" then return data_to_string, false end
		if metatable == "wml object" then return data.__literal, false end
		return data_to_string, true
	end

	local is_wml_table = true
	local result
	local wml_table_error
	local base_indent = "    "
	local function table_to_string(arg_table, indent, introduces_subtag, indices)
		local is_filled = false

		local function check_subtag()
			local one, two = arg_table[1], arg_table[2]
			if type(two) == "userdata" then
				local invalidate_wml_table
				two, invalidate_wml_table = dump_userdata(two)
				if invalidate_wml_table then return false end
			end
			if type(one) ~= "string" or type(two) ~= "table" then return false end
			return true
		end
		if is_wml_table and introduces_subtag then
			if not check_subtag() then
				wml_table_error = string.format("table introducing subtag at %s is not of the form {\"tag_name\", {}}", indices)
				is_wml_table = false
			end
		end

		local index = 1
		for current_key, current_value in pairs(arg_table) do
			is_filled = true

			local current_key_type = type(current_key)
			local current_key_to_string = tostring(current_key)
			local current_type = type(current_value)
			local function no_wml_table(expected, index, type)
				if not index then index = current_key_to_string end
				if not type then type = current_type end
				wml_table_error = string.format("value at %s[%s]: %s expected, got %s", indices, index, expected, type)
				is_wml_table = false
			end

			if current_type == "userdata" then
				local  invalidate_wml_table
				current_value, invalidate_wml_table = dump_userdata(current_value)
				current_type = type(current_value)
				if is_wml_table and invalidate_wml_table then
					wml_table_error = string.format("userdata at %s[%s]", indices, current_key_to_string)
					is_wml_table = false
				end
			end

			if is_wml_table and not introduces_subtag then
				if current_key_type == "string" and (current_type == "table" or current_type == "function" or current_type == "thread") then
					no_wml_table("nil, boolean, number or string")
				elseif current_key_type == "number" then
					if current_type ~= "table" then
						no_wml_table("table")
					elseif current_key ~= index then
						no_wml_table("value", tostring(index), "nil or fields traversed out-of-order")
					end
					index = index + 1
				end
			end

			local length = 9
			local left_bracket, right_bracket = "[", "]"
			if current_key_type == "string" then
				left_bracket, right_bracket = "", ""; length = length - 2
			end
			if current_type == "table" then
				result = string.format("%s%s%s%s%s = {\n", result, indent, left_bracket, current_key_to_string, right_bracket)
				table_to_string(current_value, string.format("%s%s%s", base_indent, indent, string.rep(" ", string.len(current_key_to_string) + length)),
					not introduces_subtag, string.format("%s[%s]", indices, current_key_to_string))
				result = string.format("%s%s%s},\n", result, indent, string.rep(" ", string.len(current_key_to_string) + length))
			else
				local quote = ""; if current_type == "string" then quote = "\"" end
				result = string.format("%s%s%s%s%s = %s%s%s,\n", result, indent, left_bracket, current_key_to_string, right_bracket, quote, tostring(current_value), quote)
			end
		end
		if is_filled then result = string.sub(result, 1, string.len(result) - 2) .. "\n" end
	end

	local engine_is_wml_table
	if wesnoth then
		engine_is_wml_table = pcall(wesnoth.set_variable, "LUA_debug_msg", lua_var); wesnoth.set_variable("LUA_debug_msg")
	end

	local var_type, var_value = type(lua_var), tostring(lua_var)
	is_wml_table = var_type == "table"
	local invalidate_wml_table
	local metatable = getmetatable(lua_var)
	if var_type == "userdata" then
		lua_var, invalidate_wml_table= dump_userdata(lua_var)
		is_wml_table = not invalidate_wml_table
	end
	local new_var_type = type(lua_var)

	local format_string = "%s is of type %s, value %s"
	local format_string_length = format_string .. ", length %u"
	local format_string_length_newline = format_string_length .. ":\n%s"

	if new_var_type == "table" then
		local var_length = #lua_var
		result = "{\n"
		table_to_string(lua_var, base_indent, false, "")
		result = result .. "}"

		if is_wml_table then
			result = string.format(format_string_length_newline, name, "WML table", var_value, var_length, result)
		elseif wml_table_error then
			result = string.format(format_string_length .. ", but no WML table: %s:\n%s", name, "table", var_value, var_length, wml_table_error, result)
		else
			result = string.format(format_string_length_newline, name, var_type, var_value, var_length, result)
		end
	elseif new_var_type == "string" then
		result = string.format(format_string_length, name, var_type, var_value, #lua_var)
	else
		result = string.format(format_string, name, var_type, var_value)
	end

	if metatable then result = string.format("%s\nwith a metatable:\n", result) end

	if wesnoth and is_wml_table ~= engine_is_wml_table  and (var_type == "table" or var_type == "userdata" or var_type == "function" or var_type == "thread") then
		result = string.format("warning: WML table inconsistently predicted, script says %s , engine %s \n%s", tostring(is_wml_table), tostring(engine_is_wml_table), result)
	end

	if clear and wesnoth then wesnoth.clear_messages() end
	if not only_return then
		if wesnoth then wesnoth.message("dbms", result) end; print(result)
	end
	local continue = true
	if onscreen and wesnoth and not only_return then
		if wrap then wesnoth.wml_actions.message({ speaker = "narrator", image = "wesnoth-icon.png", message = result })
		else
			local wlp_utils = wesnoth.require "~add-ons/Wesnoth_Lua_Pack/wlp_utils.lua"
			local result = wlp_utils.message({ caption = "dbms", message = result })
			if result == -2 then continue = false end
		end
	end
	if metatable and continue then
		result = result .. wesnoth.dbms(metatable, false, string.format("The metatable %s", tostring(metatable)), onscreen, wrap, only_return)
	end
	return result
end

-- First, parse data into suitable structures

title_table = {}
flavours_table = { "chivalrous", "wizardly", "dark", "criminal", "warlike", "sneaky", "brutish", "ghostly" }

local title_data = helper.get_child(wesnoth.unit_types["Other Data Loader"].__cfg, "advancement")
for i = 1,#title_data do
	if title_data[i][1] == "nonterminal" then
		local made = {}
		for j = 1,#title_data[i][2] do
			if title_data[i][2][j][1] == "variation" then
				table.insert(made, title_data[i][2][j][2])
			end
		end
		title_table[title_data[i][2].name] = made
	end
end

function get_unit_flavour(u)
	-- Check its properties to calculate its flavour
	wesnoth.wml_actions.unit{ type = u.type, to_variable = "lua_unit_to_get_flavour"}
	local data = wesnoth.get_variable("lua_unit_to_get_flavour")
	wesnoth.set_variable("lua_unit_to_get_flavour", nil)

	local function has_attack(attack_name)
		local has = false
		for i = 1,#data do
			if data[i][1] == "attack" then
				if data[i][2].name == attack_name then
					has = true
				end
			end
		end
		return has
	end

	local function has_special(special_name)
		local has = false
		for i = 1,#data do
			if data[i][1] == "attack" then
				for j = 1,#data[i][2] do
					if data[i][2][j][2].id == special_name then
						has = true
					end
				end
			end
		end
		return has
	end

	local melee_damage = 0
	local ranged_damage = 0
	local spell_damage = 0
	for i = 1,#data do
		if data[i][1] == "attack" then
			local damage = data[i][2].damage * data[i][2].number
			if data[i][2].range == "melee" then
				if damage > melee_damage then
					melee_damage = damage
				end
			else
				local is_spell = false
				for j = 1,#data[i][2] do
					if data[i][2][j][2].id == "magical" then
						is_spell = true
					end
				end
				if is_spell then
					if damage > spell_damage then
						spell_damage = damage
					end
				else
					if damage > ranged_damage then
						ranged_damage = damage
					end
				end
			end
		end
	end
	local range
	if melee_damage > ranged_damage and melee_damage > 1.1 * spell_damage then
		range = "melee"
	elseif 1.1 * spell_damage > melee_damage and 1.1 * spell_damage > ranged_damage then
		range = "spell"
	else
		range = "ranged"
	end

	local defence = 0
	local terrains = 0
	local defences = helper.get_child(data, "defense")
	for k,v in pairs(defences) do
		defence = defence + v
		terrains = terrains + 1
	end
	defence = defence / terrains

	local resistances = helper.get_child(data, "resistance")
	local resistance = 100
	if resistances then
		resistance = (resistances.blade + resistances.impact + resistances.pierce) / 3
	end

	-- Calculate its flavour
	flavour = {}
	for i = 1,#flavours_table do
		flavour[flavours_table[i]] = 0
	end

	-- Alignment, take into consideration that chaotic outlaws and undead are different from general chaotic
	if data.alignment == "lawful" then
		flavour.chivalrous = flavour.chivalrous + 10
	elseif data.alignment == "chaotic" then
		-- Check if it's not living
		local race = wesnoth.races[data.race].__cfg
		local not_living = 0
		for i = 1,#race do
			if race[i][1] == "trait" and race[i][2].availability == "musthave" then
				for j = 1,#race[i][2] do
					if race[i][2][j][1] == "effect" and race[i][2][j][2].apply_to == "status" and (race[i][2][j][2].add == "unpoisonable" or race[i][2][j][2].add == "unplagueable" or race[i][2][j][2].add == "undrainable") then
						not_living = not_living + 1
					end
				end
			end
		end
		-- Act accordingly to the reason why it's chaotic, the unliving need more dark
		if not_living > 1 or has_attack("chill wave") or has_attack("shadow wave") or has_attack("curse") or has_special("plague") then
			flavour.dark = flavour.dark + 10
		else
			flavour.dark = flavour.dark + 3
			if data.race == "human" then
				flavour.criminal = flavour.criminal + 10
			end
		end
	end

	-- Abilities and some other properties
	local abilities = helper.get_child(data, "abilities")
	for i = 1,#abilities do
		if abilities[i][1] == "leadership" then
			flavour.warlike = flavour.warlike + 10
		end
		if abilities[i][1] == "heals" or abilities[i][1] == "illuminates" then
			flavour.chivalrous = flavour.chivalrous + 10
		end
		if abilities[i][1] == "skirmisher" or abilities[i][1] == "hides" then
			flavour.sneaky = flavour.sneaky + 10
		end
		if abilities[i][1] == "regenerates" then
			flavour.brutish = flavour.brutish + 10
		end
	end

	if range == "melee" and not has_special("backstab") then
		flavour.warlike = flavour.warlike + 5
		flavour.brutish = flavour.brutish + 5
	end

	if range == "ranged" then
		flavour.sneaky = flavour.sneaky + 5
		flavour.warlike = flavour.warlike + 5
	end

	if has_special("backstab") or has_special("poison") then
		if defence < 55 then
			flavour.sneaky = flavour.sneaky + 10
		end
		flavour.criminal = flavour.criminal + 10
	end

	if has_special("berserk") or has_special("damage") then
		flavour.warlike = flavour.warlike + 10
	end

	if data.race == "orc" then -- trolls get it because they regenerate
		flavour.brutish = flavour.brutish + 10
	end

	if data.race == "elf" then -- aren't lawful but are good
		flavour.chivalrous = flavour.chivalrous + 10
	end

	if range == "spell" then
		flavour.wizardly = flavour.wizardly + 10
	end

	if resistance < 60 and resistances.arcane > 120 and defence < 65 then
		flavour.ghostly = flavour.ghostly + 10
	end

	-- Traits
	local modifications = helper.get_child(u, "modifications")
	for i = 1,#modifications do
		if modifications[i][1] == "trait" then
			if modifications[i][2].id == "loyal" then
				flavour.chivalrous = flavour.chivalrous + 2
			end
			if modifications[i][2].id == "strong" then
				flavour.warlike = flavour.warlike + 2
			end
			if modifications[i][2].id == "resilient" or modifications[i][2].id == "healthy" or modifications[i][2].id == "dim" then
				flavour.brutish = flavour.brutish + 2
			end
			if modifications[i][2].id == "intelligent" then
				flavour.wizardly = flavour.wizardly + 2
			end
			if modifications[i][2].id == "quick" or modifications[i][2].id == "dextrous" then
				flavour.sneaky = flavour.sneaky + 2
			end
		end
	end

	return flavour
end

function normalise_flavour(flavour)
	local flavour_sum = 0
	for i = 1,#flavours_table do
		flavour_sum = flavour_sum + flavour[flavours_table[i]]
	end
	for i = 1,#flavours_table do
		flavour[flavours_table[i]] = flavour[flavours_table[i]] / flavour_sum * 10
	end
	return flavour
end

function assign_title(name, female, flavour)
	-- First, set up some functions

	local function parse_nonterminal(str)
		-- Parse the string in form: (name) the (something) who (does_something)
		local parts = {}
		local are_nonterminals = {}
		local translated = tostring(str)
		local length = tostring(str):len()
		local byte_string = {string.byte(tostring(str), 1, length)}
		local starting = string.byte("(")
		local ending = string.byte(")")
		local writing = ""
		local reading_nonterminal = false
		local function finish_writing(nonterminal)
			if #writing > 0 then
				table.insert(parts, writing)
				table.insert(are_nonterminals, nonterminal)
				writing = ""
			end
		end
		for i = 1,#byte_string do
			if byte_string[i] == starting then
				if reading_nonterminal == true then
					wesnoth.message("Error parsing title string " .. string)
				end
				finish_writing(false)
				reading_nonterminal = true
			elseif byte_string[i] == ending then
				if reading_nonterminal == false then
					wesnoth.message("Error parsing title string " .. string)
				end
				finish_writing(true)
				reading_nonterminal = false
			else
				writing = writing .. string.char(byte_string[i])
			end
		end
		finish_writing(reading_nonterminal)
		return parts, are_nonterminals
	end

	local function nonterminal_fitting(nonterminal, flavour)
		-- Checks how well a nonterminal fits the flavour, lower score is better
		local fitting = 0
		for i = 1,#flavours_table do
			local value_1 = nonterminal[flavours_table[i]]
			local value_2 = flavour[flavours_table[i]]
			if not value_1 then
				value_1 = 0
			end
			if not value_2 then
				value_2 = 0
			end
			fitting = fitting + math.abs(value_1 - value_2)
		end
		return fitting
	end

	local function assign_nonterminal(nonterminal, name, female, flavour)
		-- Recursive function that expands the nonterminals and returns text
		local data = title_table[nonterminal]
		if data then
			local suitable = {}
			for i = 1,#data do
				local fitting = nonterminal_fitting(data[i], flavour)
				local relevant
				if data[i].text then
					relevant = data[i].text
				elseif not female and data[i].male_text then
					relevant = data[i].male_text
				elseif female and data[i].female_text then
					relevant = data[i].female_text
				else
					wesnoth.wml_actions.chat{ message="Nonterminal variation for " .. nonterminal .. " lacks a text or a male_text and a female_text"}
					relevant = "(error)"
				end
				if suitable[fitting] then
					table.insert(suitable[fitting], relevant)
				else
					suitable[fitting] = { relevant }
				end
			end
			local depth = data.depth or math.ceil(#data / 5)
			local accepted = {}
			while depth > 0 do
				-- Sort of bubblesort, as we need only a few first elements
				local best
				local best_score = 9000
				for quality, variations in pairs(suitable) do
					if quality < best_score then
						best_score = quality
						best = variations
					end
				end
				suitable[best_score] = nil
				helper.shuffle(best)
				for i = 1,#best do
					if depth > 0 then
						table.insert(accepted, best[i])
						depth = depth - 1
					end
				end
			end
			local chosen = accepted[wesnoth.random(#accepted)]
			local parts, are_nonterminals = parse_nonterminal(chosen)
			local result = ""
			for i = 1,#parts do
				if are_nonterminals[i] then
					if parts[i] == "name" then
						result = result .. name
					else
						result = result .. assign_nonterminal(tostring(parts[i]), name, female, flavour)
					end
				else
					result = result .. parts[i]
				end
			end
			return result
		else
			wesnoth.wml_actions.chat{ message = "Nonterminal " .. nonterminal .. " not defined"}
			return "(error)"
		end
	end
	
	return assign_nonterminal("main", name, female, flavour)
end

-- wesnoth.dbms(assign_title("Joe", false, { dark=3, brutish=7 }))
