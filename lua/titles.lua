loti.flavours_table = { "chivalrous", "wizardly", "dark", "criminal", "warlike", "sneaky", "brutish", "ghostly" }

-- First, parse data into suitable structures
local title_table = {}
local flavours_table = loti.flavours_table

local title_data = wml.get_child(wesnoth.unit_types["Title Data Loader"].__cfg, "advancement")
for i = 1,#title_data do
	if title_data[i][1] == "nonterminal" then
		local made = {}
		for j = 1,#title_data[i][2] do
			if title_data[i][2][j][1] == "name_variation" then
				table.insert(made, title_data[i][2][j][2])
			end
		end
		title_table[title_data[i][2].name] = made
	end
end

function loti.util.get_unit_flavour(u)
	-- Check its properties to calculate its flavour
	wesnoth.wml_actions.unit{ type = u.type, to_variable = "lua_unit_to_get_flavour"}
	local data = wml.variables["lua_unit_to_get_flavour"]
	wml.variables["lua_unit_to_get_flavour"] = nil

	local has_attack = loti.util.list_attacks(u)

	local function has_special(special_name)
		local has = false
		for i = 1,#data do
			if data[i][1] == "attack" then
				for j = 1,#data[i][2] do
					for k = 1,#data[i][2][j][2] do
						if data[i][2][j][2][k][2].id == special_name then
							has = true
						end
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
					for k = 1,#data[i][2][j][2] do
						if data[i][2][j][2][k][2].id == "magical" then
							is_spell = true
						end
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
	local defences = wml.get_child(data, "defense")
	if defences then
		for _, v in pairs(defences) do
			defence = defence + v
			terrains = terrains + 1
		end
		defence = defence / terrains
	end

	local resistances = wml.get_child(data, "resistance")
	local resistance = 100
	if resistances then
		resistance = (resistances.blade + resistances.impact + resistances.pierce) / 3
	end

	-- Calculate its flavour
	local flavour = {}
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
		if not_living > 1 or has_attack["chill wave"] or has_attack["shadow wave"] or has_attack["curse"] or has_special("plague") then
			flavour.dark = flavour.dark + 10
		else
			flavour.dark = flavour.dark + 3
			if data.race == "human" then
				flavour.criminal = flavour.criminal + 10
			end
		end
	end

	-- Abilities and some other properties
	local abilities = wml.get_child(data, "abilities")
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
	local modifications = wml.get_child(u, "modifications")
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

function loti.util.normalise_flavour(flavour)
	local flavour_sum = 0
	for i = 1,#flavours_table do
		flavour_sum = flavour_sum + flavour[flavours_table[i]]
	end
	for i = 1,#flavours_table do
		flavour[flavours_table[i]] = flavour[flavours_table[i]] / flavour_sum * 10
	end
	return flavour
end

function loti.util.assign_title(Name, Gender, Flavour)
	-- First, set up some functions

	local function parse_nonterminal(str)
		-- Parse the string in form: (name) the (something) who (does_something)
		local parts = {}
		local are_nonterminals = {}
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
					wesnoth.interface.add_chat_message("Error parsing title string " .. string)
				end
				finish_writing(false)
				reading_nonterminal = true
			elseif byte_string[i] == ending then
				if reading_nonterminal == false then
					wesnoth.interface.add_chat_message("Error parsing title string " .. string)
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
					wesnoth.wml_actions.chat{ message="Nonterminal name_variation for " .. nonterminal .. " lacks a text or a male_text and a female_text"}
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
				mathx.shuffle(best)
				for i = 1,#best do
					if depth > 0 then
						table.insert(accepted, best[i])
						depth = depth - 1
					end
				end
			end
			local chosen = accepted[mathx.random(#accepted)]
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

	return assign_nonterminal("main", Name, Gender == "female", Flavour)
end

-- wesnoth.dbms(loti.util.assign_title("Joe", false, { dark=3, brutish=7 }))
