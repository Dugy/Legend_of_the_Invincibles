-- Some libraries place utility functions into this array,
-- e.g. loti.item.storage.add()
loti = {}

-- Syntax sugar to make GUI2 dialogs more compact, e.g. T.column, T.row, etc.
T = wml.tag

wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/debug.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/utils.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/items.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/inventory/dialog.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/unitdata.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/crafting.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/titles.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/redeem.lua")
wesnoth.dofile("~add-ons/Legend_of_the_Invincibles/lua/stats.lua")

--! #textdomain "wesnoth-loti"

local _ = wesnoth.textdomain "wesnoth-loti"

local helper = wesnoth.require "lua/helper.lua"

local old_unit_status = wesnoth.theme_items.unit_status
function wesnoth.theme_items.unit_status()
     local u = wesnoth.get_displayed_unit()
     if not u then return {} end
     local s = old_unit_status()
     if u.status.infected then
         table.insert(s, { "element", {
             image = "misc/infected.png",
             tooltip = _"infected: This unit is infected. It will become undead after death, unless cured by a healer or by standing on a village."
         } })
     end
     if u.status.incinerated then
	 table.insert(s, { "element", {
	     image = "misc/incinerated.png",
	     tooltip = _"in flames: This unit is in flames. It will lose 16 HP per turn, unless cured by a healer or by standing on a village."
	} })
     end
     return s
end

function wesnoth.wml_actions.get_unit_resistance(cfg)
	local damage_type = cfg.damage_type or helper.wml_error "[get_unit_resistance] has no damage type specified"
	local to_variable = cfg.to_variable or "resistance_obtained"
	local unit = wesnoth.get_units(cfg)[1] or wesnoth.set_variable( to_variable , 100 ) --It's mainly used for weapon specials, and the target might be already killed
	if unit then
		local result = wesnoth.unit_resistance( unit, damage_type )
		wesnoth.set_variable( to_variable , result )
	end
end

function wesnoth.wml_actions.harm_unit_loti(cfg)
	-- Most of this is pasted from core, but I needed to do some edits that could not have been done without this unpleasant violation of the DRY (Don't Repeat Yourself) rule
	-- To be honest, there are parts I don't even understand
	-- It's meant to harm units but give experience only on kill, works only when used by weapon specials

	-- These two functions were copied from wml-tags.lua too
	local function start_var_scope(name)
		local var = helper.get_variable_array(name) --containers and arrays
		if #var == 0 then var = wesnoth.get_variable(name) end --scalars (and nil/empty)
		wesnoth.set_variable(name)
		return var
	end
	local function end_var_scope(name, var)
		wesnoth.set_variable(name)
		if type(var) == "table" then
			helper.set_variable_array(name, var)
		else
			wesnoth.set_variable(name, var)
		end
	end

	local filter = helper.get_child(cfg, "filter") or helper.wml_error("[harm_unit_loti] missing required [filter] tag")
	-- we need to use shallow_literal field, to avoid raising an error if $this_unit (not yet assigned) is used
	if not cfg.__shallow_literal.amount then helper.wml_error("[harm_unit_loti] has missing required amount= attribute") end
	local variable = cfg.variable -- kept out of the way to avoid problems
	local _ = wesnoth.textdomain "wesnoth"
	local harmer

	local function toboolean( value ) -- helper for animate fields
		-- units will be animated upon leveling or killing, even
		-- with special attacker and defender values
		if value then return true
		else return false end
	end

	local this_unit = start_var_scope("this_unit")

	for index, unit_to_harm in ipairs(wesnoth.get_units(filter)) do
		if unit_to_harm.valid then
			-- block to support $this_unit
			wesnoth.set_variable ( "this_unit" ) -- clearing this_unit
			wesnoth.set_variable("this_unit", unit_to_harm.__cfg) -- cfg field needed
			local amount = tonumber(cfg.amount)
			local animate = cfg.animate -- attacker and defender are special values
			local delay = cfg.delay or 500
			local fire_event = cfg.fire_event
			local primary_attack = helper.get_child(cfg, "primary_attack")
			local secondary_attack = helper.get_child(cfg, "secondary_attack")
			local harmer_filter = helper.get_child(cfg, "filter_second")
			local resistance_multiplier = tonumber(cfg.resistance_multiplier) or 1
			if harmer_filter then harmer = wesnoth.get_units(harmer_filter)[1] end
			-- end of block to support $this_unit

			if animate then
				if animate ~= "defender" and harmer and harmer.valid then
					wesnoth.scroll_to_tile(harmer.x, harmer.y, true)
					wesnoth.wml_actions.animate_unit( { flag = "attack", hits = true, { "filter", { id = harmer.id } },
						{ "primary_attack", primary_attack },
						{ "secondary_attack", secondary_attack }, with_bars = true,
						{ "facing", { x = unit_to_harm.x, y = unit_to_harm.y } } } )
				end
				wesnoth.scroll_to_tile(unit_to_harm.x, unit_to_harm.y, true)
			end

			-- the two functions below are taken straight from the C++ engine, util.cpp and actions.cpp, with a few unuseful parts removed
			-- may be moved in helper.lua in 1.11
			local function round_damage( base_damage, bonus, divisor )
				local rounding
				if base_damage == 0 then return 0
				else
					if bonus < divisor or divisor == 1 then
						rounding = divisor / 2 - 0
					else
						rounding = divisor / 2 - 1
					end
					return math.max( 1, math.floor( ( base_damage * bonus + rounding ) / divisor ) )
				end
			end

			local function calculate_damage( base_damage, alignment, tod_bonus, resistance, modifier )
				local damage_multiplier = 100
				if alignment == "lawful" then
					damage_multiplier = damage_multiplier + tod_bonus
				elseif alignment == "chaotic" then
					damage_multiplier = damage_multiplier - tod_bonus
				elseif alignment == "liminal" then
					damage_multiplier = damage_multiplier - math.abs( tod_bonus )
				else -- neutral, do nothing
				end
				local resistance_modified = resistance * modifier
				damage_multiplier = damage_multiplier * resistance_modified
				local damage = round_damage( base_damage, damage_multiplier, 10000 ) -- if harmer.status.slowed, this may be 20000 ?
				return damage
			end

			local damage = calculate_damage( amount,
							 ( cfg.alignment or "neutral" ),
							 wesnoth.get_time_of_day( { unit_to_harm.x, unit_to_harm.y, true } ).lawful_bonus,
							 wesnoth.unit_resistance( unit_to_harm, cfg.damage_type or "dummy" ),
							 resistance_multiplier
						       )

			if unit_to_harm.hitpoints <= damage then
				damage = unit_to_harm.hitpoints
			end

			unit_to_harm.hitpoints = unit_to_harm.hitpoints - damage
			local text = string.format("%d%s", math.floor(damage), "\n")
			local add_tab = false
			local gender = unit_to_harm.__cfg.gender

			local function set_status(name, male_string, female_string, sound)
				if not cfg[name] or unit_to_harm.status[name] then return end
				if gender == "female" then
					text = string.format("%s%s%s", text, tostring(female_string), "\n")
				else
					text = string.format("%s%s%s", text, tostring(male_string), "\n")
				end

				unit_to_harm.status[name] = true
				add_tab = true

				if animate and sound then -- for unhealable, that has no sound
					wesnoth.play_sound (sound)
				end
			end

			if not unit_to_harm.status.unpoisonable then
				set_status("poisoned", _"poisoned", _"female^poisoned", "poison.ogg")
			end
			set_status("slowed", _"slowed", _"female^slowed", "slowed.wav")
			set_status("petrified", _"petrified", _"female^petrified", "petrified.ogg")
			set_status("unhealable", _"unhealable", _"female^unhealable")

			-- Extract unit and put it back to update animation if status was changed
			wesnoth.extract_unit(unit_to_harm)
			wesnoth.put_unit(unit_to_harm, unit_to_harm.x, unit_to_harm.y)

			if add_tab then
				text = string.format("%s%s", "\t", text)
			end

			if animate and animate ~= "attacker" then
				if harmer and harmer.valid then
					wesnoth.wml_actions.animate_unit( { flag = "defend", hits = true, { "filter", { id = unit_to_harm.id } },
						{ "primary_attack", primary_attack },
						{ "secondary_attack", secondary_attack }, with_bars = true },
						{ "facing", { x = harmer.x, y = harmer.y } } )
				else
					wesnoth.wml_actions.animate_unit( { flag = "defend", hits = true, { "filter", { id = unit_to_harm.id } },
						{ "primary_attack", primary_attack },
						{ "secondary_attack", secondary_attack }, with_bars = true } )
				end
			end

			wesnoth.float_label( unit_to_harm.x, unit_to_harm.y, string.format( "<span foreground='red'>%s</span>", text ) )

			if unit_to_harm.hitpoints < 1 then
				local uth_cfg = unit_to_harm.__cfg
				local added_exp
				if uth_cfg.level > 0 then
					added_exp = uth_cfg.level * 8
				else
					added_exp = 4
				end
				if harmer then
					wesnoth.wml_actions.store_unit { { "filter", { id = harmer.id } }, variable = "Lua_store_unit", kill = false }
					local harmer_variables = helper.get_child(harmer.__cfg, "variables")
					if harmer_variables.lua_delayed_exp then
						wesnoth.wml_actions.set_variable { name="Lua_store_unit.variables.lua_delayed_exp", add = added_exp }
					else
						wesnoth.wml_actions.set_variable { name="Lua_store_unit.variables.lua_delayed_exp", value = added_exp }
					end -- The exp will be added when combat ends
					wesnoth.wml_actions.unstore_unit { variable = "Lua_store_unit",
									find_vacant = false,
									animate = toboolean( animate ),
									fire_event = toboolean(fire_event) }
					wesnoth.set_variable ( "Lua_store_unit", nil )
				end
				wesnoth.wml_actions.kill({
					id = unit_to_harm.id,
					{ "filter_second", {
						id=harmer.id
					}},
					{ "secondary_unit", {
						id=harmer.id
					}},
					animate = toboolean( animate ),
					fire_event = toboolean(toboolean(fire_event))
				})
			end

			if animate then
				wesnoth.delay(delay)
			end

			if variable then
				wesnoth.set_variable(string.format("%s[%d]", variable, math.floor(index - 1)), { harm_amount = damage })
			end
		end

		wesnoth.wml_actions.redraw {}
	end

	wesnoth.set_variable ( "this_unit" ) -- clearing this_unit
	end_var_scope("this_unit", this_unit)
end

-- This is used in global_events.cfg, check there what it actually does

function unit_information_part_1()
    local max_devour_count = wesnoth.get_variable("unit.variables.max_devour_count")
    local devour_count = wesnoth.get_variable("unit.variables.devour_count")
    local max_redeem_count = wesnoth.get_variable("unit.variables.max_redeem_count")
    local redeem_count = wesnoth.get_variable("unit.variables.redeem_count")
    local max_lesser_redeem_count = wesnoth.get_variable("unit.variables.max_lesser_redeem_count")
    local lesser_redeem_count = wesnoth.get_variable("unit.variables.lesser_redeem_count")
    local starving = wesnoth.get_variable("unit.variables.starving")
    local wrath_intensity = wesnoth.get_variable("unit.variables.wrath_intensity")
    local from_the_ashes_used = wesnoth.get_variable("unit.variables.from_the_ashes_used")
    local from_the_ashes_cooldown = wesnoth.get_variable("unit.variables.from_the_ashes_cooldown")
    local wrath = wesnoth.get_variable("unit.variables.wrath_intensity")

    local result = ""
    local span = "<span font_weight='bold'>"
    result = result .. span .. _"Hitpoints:</span> "
    .. string.format("%u/%u", wesnoth.get_variable("unit.hitpoints"), wesnoth.get_variable("unit.max_hitpoints")) .. " \n"
    local span = "<span font_weight='bold'>"
    result = result .. span .. _"Experience:</span> "
    .. string.format("%u/%u", wesnoth.get_variable("unit.experience"), wesnoth.get_variable("unit.max_experience")) .. " \n"
    if max_devour_count ~= nil and max_devour_count > 0 then
      result = result .. span .. _"Soul eater score:</span> "
      .. string.format("%u/%u", devour_count, max_devour_count) .. " \n"
    end
    if max_redeem_count ~= nil and max_redeem_count > 0 then
      result = result .. span .. _"Redeem score:</span> "
      .. string.format("%u/%u", redeem_count, max_redeem_count) .. " \n"
    end
    if max_lesser_redeem_count ~= nil and max_lesser_redeem_count > 0 then
      result = result .. span .. _"Lesser redeem score:</span> "
      .. string.format("%u/%u", lesser_redeem_count, max_lesser_redeem_count) .. " \n"
    end
    if starving ~= nil and starving > 0 then
      result = result .. span .. _"Starving:</span> "
      .. starving .. " \n"
    end
    if from_the_ashes_used ~= nil then
      result = result .. span .. _"Turns until From The Ashes will be usable:</span> "
      .. from_the_ashes_cooldown .. " \n"
    end
    if wrath ~= nil then
      if wrath > 0 then
        result = result .. span .. _"Wrath increasing damage by:</span> "
        .. wrath .. " \n"
      else
        result = result .. span .. _"Lethargy reducing damage by:</span> "
        .. -1 * wrath .. " \n"
      end
    end

    wesnoth.set_variable("desc_prefix", result)
end

function unit_information_part_2()
    function remove_duplicates(t)
      local new_table = {}
      local hash = {}
      for _, v in ipairs(t) do
        if not hash[v] then
          table.insert(new_table, v)
          hash[v] = true
        end
      end
      return new_table
    end

    -- Count the number of pairs in a Lua table
    function len(t)
      local count = 0
      for _ in pairs(t) do count = count + 1 end
      return count
    end


    -- This function creates a 7 character monospace summary of the unit's
    -- attacks.  By using string.format we can make sure that everything lines
    -- up nicely regardless of whether an attack deals <10 or >=10 damage.
    function get_attack_damage_summary(attack)
      function round(number)
        if number > 0 and number < 1 then
          return 1
        end
        return math.floor(number)
      end
      local damage = attack["damage"]
      local number = attack["number"]
      local format_string = "<span font_family='monospace' font_weight='bold'>%4d"
      .. "-"
      .. "%-2d</span>"
      return string.format(format_string, math.floor(damage), math.floor(number))
    end

    -- Each attack has two different names in this context:
    --    * The "name" field is the name which is displayed in the wesnoth menu
    --    * The "description" field is a short name for the attack
    -- Equipping a weapon may change the name of an attack, but it won't change
    -- the description.
    -- If the name and description of an attack are different, this function
    -- will display them both.  This means that we don't have to worry about
    --  a unit having 3 attacks all of which are called "Dugi's Wrath"
    function get_attack_name(attack)
      local description = tostring(attack["description"])
      local name = tostring(attack["name"])
      local result = "<span color='#60A0FF' font_weight='bold'>" .. name .. "</span>"
      if description then
      	result = "<span color='#60A0FF' font_weight='bold'>" .. description .. "</span>"
      end
      return result
    end

    -- This function summarizes three things:
    --     * Is the attack ranged or melee?
    --     * Is the attack blade/pierce/...?
    --     * Can the attack only be used when attacking/defending/not at all?
    function get_attack_range_and_type(attack)
      local attack_weight = attack["attack_weight"]
      local defense_weight = attack["defense_weight"]

      local attack_status = ""
      if attack_weight == 0 and defense_weight == 0 then
        attack_status = tostring(_", inactive")
      elseif attack_weight == 0 then
        attack_status = tostring(_", defense only")
      elseif defense_weight == 0 then
        attack_status = tostring(_", attack only")
      end

      local range
      if attack["range"] == "melee" then range = _"melee"
      elseif attack["range"] == "ranged" then range = _"ranged" end

      local dmgType = _"werd damage type"
      if attack["type"] == "blade" then dmgType = _"blade"
      elseif attack["type"] == "impact" then dmgType = _"impact"
      elseif attack["type"] == "pierce" then dmgType = _"pierce"
      elseif attack["type"] == "fire" then dmgType = _"fire"
      elseif attack["type"] == "cold" then dmgType = _"cold"
      elseif attack["type"] == "arcane" then dmgType = _"arcane"
      elseif attack["type"] == "lightning" then dmgType = _"lightning" end

      return  "<span font_weight='bold' color='#60A0FF'>"
      .. range .. " - " .. dmgType
      .. "</span>"
      .. attack_status
    end

    -- An attack special is reported only if it has a valid "name" field.
    function get_attack_specials(attack)
      H = wesnoth.require "lua/helper.lua"
      local specials = H.get_child(attack, "specials")
      local result_table = {}

      for _, v in pairs(specials) do
         local special_name = v[1]
         local special_data = v[2]
         local special = special_data["name"]
         if special ~= nil then
           special = tostring(special)
         elseif special_name == "dummy" and special_data["id"] == "spell_suck" then
           special = "spell suck " .. tostring(special_data["suck"])
         elseif special_name == "dummy" and special_data["suck"] ~= nil then
           if attack["type"] == "blade"
           or attack["type"] == "pierce"
           or attack["type"] == "impact" then
             special = "suck " .. tostring(special_data["suck"])
           end
         elseif special_name == "dummy" and special_data["devastating_blow"] ~= nil then
           special = tostring(special_data["devastating_blow"]) .. "% devastating blow"
         elseif special_name == "dummy" and special_data["lethargy"] ~= nil then
           special = "lethargy"
         end
         if special ~= nil and special ~= "" then
           table.insert(result_table, "<span color='#88FCA0'>" .. special .. "</span>")
         end
      end

      -- We need to remove duplicates from our list of specials, since it's
      -- possible that both an AMLA and a weapon (for example) may have added the
      -- same special.
      result_table = remove_duplicates(result_table)
      if len(result_table) == 0 then
        return ""
      else
        return "<span font_family='monospace'>       </span> "
             .. table.concat(result_table, ", ")
      end
    end

    -- This is a simple helper function we use to summarize each individual attack
    function list_one_attack(attack)
      local result = get_attack_damage_summary(attack) .. " "
      .. get_attack_name(attack) .. ": "
      .. get_attack_range_and_type(attack) .. " \n"
      .. get_attack_specials(attack) .. " \n"
      return result
    end


    -- The entry point for this code block: a function to list all of a unit's attacks.
    function list_attacks()
      H = wesnoth.require "lua/helper.lua"
      local attacks = H.get_variable_array("unit.attack")
      local result = ""
      for i, v in ipairs(attacks) do
        result = result .. list_one_attack(v)
      end

      -- Remove the trailing newline, just to make things compact
      result = string.sub(tostring(result), 1, -2)
      -- Remove an extra trailing newline at the end
      -- This will happen if the last attack listed had no specials
      if string.sub(result, -1) == " \n" then
        result = string.sub(tostring(result), 1, -2)
      end
      return result
    end

    wesnoth.set_variable("attacks_list", list_attacks())
end

function unit_information_part_3()
    function list_one_ability(a)
      local ability_info = a[2]
      -- Abilities without descriptions shouldn't be reported to the user,
      -- they're for internal purposes.
      if ability_info["description"] == nil or ability_info["description"] == "" then
        return nil
      end

      local result = "<span color='#60A0FF' weight='bold'>"
      .. tostring(ability_info["name"])
      .. "</span>: " ..  tostring(ability_info["description"])

      -- Replace all newlines in the abilities description with spaces.  This
      -- keeps the ability list much more compact.
      result = string.gsub(tostring(result), " \n", " ")
      return result
    end

    function list_abilities()
      local abilities = wesnoth.get_variable("unit.abilities")
      local result_list = {}
      if abilities ~= nil then
        for _, v in ipairs(abilities) do
          table.insert(result_list, list_one_ability(v))
        end
      end

      if next(result_list) == nil or result_list == ""  then
        return "none"
      else
        return table.concat(result_list, " \n")
      end
    end

    wesnoth.set_variable("abilities_list", list_abilities())
end

function unit_information_part_4()
  function form_one_line(type)
    local resist = 100 - wesnoth.get_variable("unit.resistance." .. type)
    local penetrate = 0
    H = wesnoth.require "lua/helper.lua"
    local resistances = H.get_variable_array("unit.abilities.resistance")

    for i, v in ipairs(resistances) do
      if (v["id"] == type .. "_penetrate") then
        penetrate = v["sub"]
      end
    end
    return string.format("%6d%%       %6d%%</span> \n", math.floor(resist), math.floor(penetrate))
  end

  local result = _"<span font_family='monospace' weight='bold' color='#60A0FF'>"
  ..                               _"    Damage      Resistance    Penetration</span> \n"
  .. _"<span font_family='monospace'>    Blade       " .. form_one_line("blade")
  .. _"<span font_family='monospace'>    Pierce      " .. form_one_line("pierce")
  .. _"<span font_family='monospace'>    Impact      " .. form_one_line("impact")
  .. _"<span font_family='monospace'>    Fire        " .. form_one_line("fire")
  .. _"<span font_family='monospace'>    Cold        " .. form_one_line("cold")
  .. _"<span font_family='monospace'>    Arcane      " .. form_one_line("arcane")

  -- Remove the last newline, just to make things compact
  result = string.sub(tostring(result), 1, -2)

  wesnoth.set_variable("resistances_list", result)
end

function unit_information_part_5()
  function form_one_line(type)
    local defence = 100 - (wesnoth.get_variable("unit.defense." .. type) or 0)
    local cost = wesnoth.get_variable("unit.movement_costs." .. type)
    if cost == nil then
	return "    none      inaccessible</span> \n"
    end
    return string.format("%6d%%       %6d</span> \n", math.floor(defence), math.floor(cost))
  end

  local result = _"<span font_family='monospace' weight='bold' color='#60A0FF'>"
  ..                               _"    Location              Defence     Movement cost</span> \n"
  .. _"<span font_family='monospace'>In forests              " .. form_one_line("forest")
  .. _"<span font_family='monospace'>In frozen places        " .. form_one_line("frozen")
  .. _"<span font_family='monospace'>On flat terrains        " .. form_one_line("flat")
  .. _"<span font_family='monospace'>In caves                " .. form_one_line("cave")
  .. _"<span font_family='monospace'>In mushroom grooves     " .. form_one_line("fungus")
  .. _"<span font_family='monospace'>In villages             " .. form_one_line("village")
  .. _"<span font_family='monospace'>In castles              " .. form_one_line("castle")
  .. _"<span font_family='monospace'>In shallow waters       " .. form_one_line("shallow_water")
  .. _"<span font_family='monospace'>On coastal reefs        " .. form_one_line("reef")
  .. _"<span font_family='monospace'>In deep water           " .. form_one_line("deep_water")
  .. _"<span font_family='monospace'>On hills                " .. form_one_line("hills")
  .. _"<span font_family='monospace'>On mountains            " .. form_one_line("mountains")
  .. _"<span font_family='monospace'>On sands                " .. form_one_line("sand")
  .. _"<span font_family='monospace'>Above unwalkable places " .. form_one_line("unwalkable")
  .. _"<span font_family='monospace'>Inside impassable walls " .. form_one_line("impassable")

  -- Remove the last newline, just to make things compact
  result = string.sub(tostring(result), 1, -2)
  wesnoth.set_variable("defences_list", result)
end

function unit_information_part_6()
    -- This table transforms an array like {'a', 'b', 'a'} into a table of
    -- counts like {'a': 2, 'b': 1}
    function count(t)
      local result = {}
      for _, v in ipairs(t) do
        v = tostring(v)
        if result[v] ~= nil then
          result[v] = result[v] + 1
        else
          result[v] = 1
        end
      end
      return result
    end

    -- Create a nice string representation of a table of counts (produced by
    -- the counts function above)
    function summarize_counts(t)
      local result = ""
      for abil, count in pairs(t) do
        result = result .. "<span font_family='monospace' font_weight='bold' color='#60A0FF'>    "
        .. string.format("%2dx ", math.floor(count)) .. "</span>" .. abil .. " \n"
      end
      return result
    end

    -- Main function for this block: create a nicely formatted list of all of a
    -- unit's advancements and the number of times it took each of them.
    -- AMLA advancements, and soul eating choices
    function list_amla()
      H = wesnoth.require "lua/helper.lua"
      local advances = H.get_variable_array("unit.modifications.advancement")
      local result_amla = ""
      local result_soul = ""
      local result_table = {}
      for _, v in pairs(advances) do
        if v.description ~= nil and v.description ~= "" then
          result_amla = result_amla
            .. tostring(v.description) .. " <span color='#A0A0A0'>"
            --.. "(" .. tostring(v.id) .. ")"
	    .. "</span>\n"
        elseif result_amla ~= "" or (helper.get_child(v, "effect") and helper.get_child(v, "effect").name == "redeem") then
            -- We wait until result_amla is not empty, because some soul eating
            -- advancements are automatically set when Preserved Liches are
            -- created (scenarios1/10_The_Poison, scenarios6/01_The_Awakening)
            -- IS IT CAUSING TROUBLE WITH REDEEM ADVANCEMENTS?
           v = tostring(v.id)
           if result_table[v] == nil then
              result_table[v] = 1
              result_soul = result_soul .. v .. "\n"
           end
        end
      end
      if result_soul ~= "" then
        result_soul = "<span size='large' weight='bold'>Soul eating/redeem/books advancement paths:</span>\n" .. result_soul
      end
      return result_amla, result_soul
    end

    result_amla, result_soul = list_amla()
    wesnoth.set_variable("advancements_taken", result_amla)
    wesnoth.set_variable("soul_eating", result_soul)
end


function clear_advancements(unit)
    for i = #unit, 1, -1 do
        v = unit[i]
        if v[1] == "advancement" then
            table.remove(unit, i)
        end
    end
    return unit
end

loti_needs_advance = nil

function wesnoth.wml_actions.pre_advance_stuff(cfg)
--    wesnoth.message("pre_advance_stuff")
    local unit = wesnoth.get_units(cfg)[1].__cfg
    local a = helper.get_child(unit, "advancement")
    local t = wesnoth.get_variable("side_number")
    if t == unit.side then
        if a ~= nil and a.id == "backup_amla" then
            unit = clear_advancements(unit)
            local u = wesnoth.create_unit { type = "Advancing" .. unit.type }
            for i, v in ipairs(u.__cfg) do
                if v[1] == "advancement" then
                    table.insert(unit, v)
                end
            end
            local v = helper.get_child(unit, "variables")
            v.achieved_amla = true
            wesnoth.put_unit(unit)
            loti_needs_advance = true
        end
    else
        local v = helper.get_child(unit, "variables")
        v.may_need_respec = true
	unit.hitpoints = unit.max_hitpoints
        wesnoth.put_unit(unit)
    end
end

function wesnoth.wml_actions.advance_stuff(cfg)
--    wesnoth.message("advance_stuff")
    local unit = wesnoth.get_units(cfg)[1].__cfg
    local m = helper.get_child(unit, "modifications")

	local function clear_potions()
		for i = #m, 1, -1 do
			if m[i][2].sort ~= nil and string.find(m[i][2].sort, "potion") then
				table.remove(m, i)
			end
		end
	end

    if loti_needs_advance == nil then
        if unit.type == "Elvish Assassin" then
--	    wesnoth.message("is assassin")
            local a = { "advancement", { max_times = 1, always_display = true, id = "execution", image = "attacks/bow-elven-magic.png", strict_amla = true, require_amla="",
                { "effect", { apply_to = "remove_attack", name = "execution" }},
                { "effect", { apply_to = "bonus_attack", name = "execution", description = _"execution", icon = "attacks/bow-elven-magic.png", range = "ranged", defense_weight = "0", damage = "-40", merge = true, force_original_attack = "longbow" }}
            }}
            table.insert(m, a)
	    clear_potions()
            wesnoth.put_unit(unit)
        end
        return
    end
    unit = clear_advancements(unit)
    clear_potions()
    for i = 1,#unit do
	if unit[i][1] == "status" then
		unit[i][2] = {}
	end
    end
    wesnoth.put_unit(unit)
    loti_needs_advance = nil
end

nameless_generator = wesnoth.name_generator("cfg", [[
main={prefix}{middle}{suffix}|{prefix}{suffix}
prefix=Marth|Orgh|Vazz|Mal|Horgh|Thar|Aath|Bohr|Dur|Kurg|Nerh|Roeg|Xen
middle=rho|maarg|vret|loeg|vurh|'gez|'eth|rug
suffix=roth|mortus|vath|'deth|arth|uth|grus|bul
]])

undead_names = wesnoth.name_generator("cfg", [[
main={title} {nickname}|{prefix}{suffix}
title=Mister|Doctor|Lord|Baron|Old
nickname=Bone|Skinny|Pale|Departed|Buried|von Bone|Dead|Boney|Holey|Phillip Marrow
prefix=Bone|Dust|Death|Rot|Rattle|Creak|Wrap|Hollow
suffix=face|bones|tooth|skin|ribs|soul|scratch|knuckle|femur
]])


function wesnoth.wml_actions.check_unit_title(cfg)
	local u
	if cfg.variable then
		u = wesnoth.get_variable(cfg.variable)
	else
		local units = wesnoth.get_units(cfg)
		if #units < 1 then
			return
		end
		u =  units[1].__cfg
	end
	if not u or not u.race or u.race == "" then
		return
	end
	local unit_variables = helper.get_child(u, "variables")

	-- Check if the unit should be given a title
	if unit_variables.been_given_title or u.unrenamable then
		return
	end
	unit_variables.been_given_title = true
	local deserves = false
	if not u.advances_to or u.advances_to == "null" or u.advances_to == "" then
		deserves = true
	elseif u.canrecruit then
		deserves = true
	elseif (u.overlays and u.overlays:find("misc/hero%-icon%.png")) or (u.ellipse and u.ellipse:find("misc/ellipse%-hero")) then
		deserves = true
	end
	if u.race == "demon-loti" or u.race == "demon lord-loti" or u.race == "demon-loti-secret" or u.race == "imp-loti" then
		deserves = false
	end
	if not deserves then
		return
	end

	-- If the unit has no name, give it one
	if u.name == "" then
		if u.race == "undead" then
			u.name = undead_names()
		else
			u.name = nameless_generator()
		end
	end
	
	local flavour = get_unit_flavour(u)

	-- Make legacy affect flavour, even unset one
	local function check_legacy(advancement_name, legacy_name, legacy_flavour)
		if advancement_name == legacy_name then
			for i = 1,#flavours_table do
				if legacy_flavour[flavours_table[i]] then
					flavour[flavours_table[i]] = flavour[flavours_table[i]] + legacy_flavour[flavours_table[i]]
				end
			end
		end
	end
	local modifications = helper.get_child(u, "modifications")
	for i = 1,#modifications do
		if modifications[i][1] == "advancement" then
			local name = modifications[i][2].id
			check_legacy(name, "fire_dragon_legacy", { chivalrous = 3, wizardly = 5, brutish = 2 })
			check_legacy(name, "ice_dragon_legacy", { chivalrous = 3, wizardly = 5, brutish = 2 })
			check_legacy(name, "dark_dragon_legacy", { dark = 5, wizardly = 5 })
			check_legacy(name, "undead_legacy", { dark = 7, ghostly = 3 })
			check_legacy(name, "legacy_of_kings", { chivalrous = 7, warlike = 3 })
			check_legacy(name, "legacy_of_titans", { brutish = 10 })
			check_legacy(name, "legacy_of_sorrow", { dark = 5, criminal = 5 })
			check_legacy(name, "legacy_of_light", { chivalrous = 10 })
			check_legacy(name, "legacy_of_phoenix", { chivalrous = 5, ghostly = 5 })
			check_legacy(name, "legacy_of_exile", { criminal = 10 })
			check_legacy(name, "legacy_of_the_freezing_north", { brutish = 3, dark = 3, warlike = 4 })
			check_legacy(name, "legacy_of_the_free", { criminal = 5, sneaky = 5 })
		end
	end
	
	-- Normalise flavour to have sum equal to 10
	flavour = normalise_flavour(flavour)	

	-- Finalise
	u.name = assign_title(u.name, u.gender, flavour)

	if cfg.variable then
		u = wesnoth.set_variable(cfg.variable, u)
	else
		wesnoth.put_unit(u)
	end
end

-- Picks random item (numeric ID) of requested type (cfg.item_sort) from the
-- list of all droppable items, excluding the items that are not allowed in this scenario.
-- (e.g. Gladiators scenario excludes Woodland Cloak, because it has no forests)
-- Variables "droppable_items" and "droppable_items_blacklist" are comma-separated numbers.
function wesnoth.wml_actions.pick_random_item(cfg)
	local item_sort = cfg.item_sort or helper.wml_error "[pick_random_item] has no item sort specified"
	local to_variable = cfg.to_variable or "item_type"

	local droppable_items = wesnoth.get_variable("droppable_items")[item_sort]

	-- Sanity check: available items should be listed in [item_list.cfg].
	if not droppable_items then
		helper.wml_error("pick_random_item(): no items of type [" .. item_sort .. "] were found in droppable_items variable.")
	end

	-- Comma-separated list for helper.rand()
	local options = droppable_items
	
	local blacklist = wesnoth.get_variable("droppable_items_blacklist")
	if blacklist then
		-- Remove each blacklisted number from "options" string
		options = "," .. options .. ","
		for item in string.gmatch(blacklist, "[^,]*") do
			options = options:gsub("," .. item .. ",", ",")
		end
		
		-- Strip leading/trailing commas.
		-- If all items were excluded, ignore the blacklist (allow all items to be dropped).
		options = options:gsub("^,", ""):gsub(",$", ""):gsub("^$", droppable_items)
	end

	-- Provide the item ID - randomly chosen number from "options" list.
	wesnoth.set_variable(to_variable, helper.rand(options));
end

-- Determine the list of item sorts (e.g. sword,staff,boots) that can be equipped by this unit.
-- Returns the Lua table { sword = 1, armour = 1, ... }.
function loti_util_list_equippable_sorts(unit)
	local unit_type = unit.type

	-- Doppelganger can't equip anything (but can drink potions).
	if unit_type:match( "doppelganger" ) then
		return { potion = 1 }
	end

	-- Everyone can equip rings/amulets/cloaks and use potions/books.
	local can_equip = { ring = 1, amulet = 1, cloak = 1, potion = 1, limited = 1 }

	-- All corporeal beings except bats can wear armour.
	if not ( unit_type == "Ghost" or unit_type == "Wraith" or unit_type == "Spectre"
		or unit_type == "Shadow" or unit_type == "Nightgaunt" or unit_type == "Dark Shade"
		or unit_type:match(" Bat$") )
	then
		can_equip.armour = 1
		can_equip.helm = 1
		can_equip.gauntlets = 1
		can_equip.boots = 1
	end

	-- Analyze the list of attacks. Allow weapons that are logical for this unit.
	for attack in pairs(loti_util_list_attacks(unit)) do
		if attack:match("sword$") or attack == "saber"
			or attack == "war talon" or attack == "war blade"
			or attack == "mberserk" or attack == "whirlwind"
			or attack == "spectral blades"
				then can_equip.sword = 1

		elseif attack:match("axe$") or attack == "berserker frenzy"
			then can_equip.axe = 1

		elseif attack:match("staff$")
			then can_equip.staff = 1

		elseif attack == "crossbow" or attack == "slurbow"
			then can_equip.xbow = 1

		elseif attack:match("bow$")
			then can_equip.bow = 1

		elseif attack == "dagger"
			then can_equip.dagger = 1

		elseif attack == "knife" or attack == "throwing knives"
			then can_equip.knife = 1

		elseif attack == "mace" or attack == "mace-spiked"
			or attack == "morning star" or attack == "club"
			or attack == "flail" or attack == "scourge"
			or attack == "mace_berserk" or attack == "hammer"
			or attack == "hammer_runic"
				then can_equip.mace = 1

		elseif attack == "halberd" or attack == "scythe"
			or attack == "scythe-whirlwind"
				then can_equip.polearm = 1

		elseif attack:match("claws$")
			then can_equip.claws = 1

		elseif attack == "sling" or attack == "bolas" or attack == "net"
			then can_equip.sling = 1

		elseif attack == "touch" or attack == "baneblade"
			or attack == "faerie touch" or attack == "vine"
			or attack == "torch"
				then can_equip.essence = 1

		elseif attack == "thunderstick" or attack == "dragonstaff"
			then can_equip.thunderstick = 1


		elseif attack == "spear" or attack == "javelin"
			or attack == "lance" or attack == "spike"
			or attack == "pike" or attack == "trident"
			or attack == "trident-blade"
				then can_equip.spear = 1
		end
	end

	-- Some magician-like units can carry a staff (even if they don't attack with it).
	if unit_type == "Lich" or unit_type == "09 Ancient Lich" or unit_type == "Lich King"
		or unit_type == "Demilich" or unit_type == "Infernal Knight"
		or unit_type == "Dark Adept" or unit_type == "Elvish Shyde"
		or unit_type == "Elvish Seer" or unit_type == "Elvish Sylph"
		or unit_type == "Celestial Messenger" or unit_type == "Prophet"
		or unit_type == "Mage of Light" or unit_type == "Stormrider"
		or unit_type == "Sword Mage" or unit_type == "Knight of Magic"
		or unit_type == "Warlock" or unit_type == "Faerie Incarnation"
		or unit_type == "Elvish Overlord" or unit_type == "Lethalia_lich_weakened"
	then
		can_equip.staff = 1
	end

	-- Return the list of equippable item sorts for this unit
	return can_equip
end

-- Check if certain unit can equip certain item.
-- Item is passed as cfg.item_number parameter (numeric ID of the item).
-- Unit is identified by cfg.find_in parameter (e.g. find_in=secondary_unit).
-- Result is either 1 (which means "can equip") or error string that explains why it can't be equipped.
-- Result is placed into Wesnoth variable cfg.to_variable.
function wesnoth.wml_actions.can_equip_item(cfg)
	local to_variable = cfg.to_variable or "can_take"

	local units = wesnoth.get_units(cfg)
	if #units < 1 then
		helper.wml_error("[can_equip_item]: no units found, may need find_in= parameter.")
	end

	local unit = units[1]
	local item = wesnoth.get_variable("item_list.object[" .. cfg.item_number .. "]")
	local result = 1

	if not loti_util_list_equippable_sorts(unit)[item.sort] then
		result = _"This unit can't equip this item."

		-- More specific error
		if item.sort == "armour"
			then result = _"This unit cannot wear armours."
		elseif item.sort == "helm"
			then result = _"This unit cannot wear armours, not even helms."
		elseif item.sort == "gauntlet"
			then result = _"This unit cannot wear armours, not even gauntlets."
		elseif item.sort == "boots"
			then result = _"This unit cannot wear armours, not even boots. It's a sad person, having to walk barefoot all the time..."
		elseif item.sort == "ring"
			then result = _"This unit cannot wear rings. It might make marriage problematic."
		elseif item.sort == "amulet"
			then result = _"This unit cannot wear amulets."
		elseif item.sort == "cloak"
			then result = _"This unit cannot wear cloaks. Winter is not coming, fortunately."
		elseif item.sort == "sword"
			then result = _"This unit cannot use swords."
		elseif item.sort == "axe"
			then result = _"This unit cannot use axes."
		elseif item.sort == "bow"
			then result = _"This unit cannot use bows."
		elseif item.sort == "staff"
			then result = _"This unit cannot use staves."
		elseif item.sort == "xbow"
			then result = _"This unit cannot use crossbows."
		elseif item.sort == "dagger"
			then result = _"This unit cannot use daggers. Probably prefers more honest combat tactics."
		elseif item.sort == "knife"
			then result = _"This unit cannot throw knives."
		elseif item.sort == "mace"
			then result = _"This unit cannot use maces."
		elseif item.sort == "polearm"
			then result = _"This unit cannot use polearms."
		elseif item.sort == "claws"
			then result = _"This unit cannot use metal claws."
		elseif item.sort == "sling"
			then result = _"This unit cannot use slings."
		elseif item.sort == "essence"
			then result = _"This unit cannot use otherworldly essences."
		elseif item.sort == "thunderstick"
			then result = _"This unit cannot use weapons that are so advanced."
		elseif item.sort == "spear"
			then result = _"This unit cannot use spears. Seems to prefer more advanced weapons."
		end
	end

	-- TODO: (when item.sort == "limited") check for "already has this book" here, not in WML

	wesnoth.set_variable(to_variable, result);
end

--
-- Utility function for [can_equip_item] and get_unit_flavour().
-- List the names of all attacks (e.g. "chill tempest") of a certain unit.
-- Parameter "unit" can be a WML table or Lua unit object.
-- Returns the Lua table { attack_name = 1, another_attack_name = 1, ... },
-- where attack names are untranslated (always English) and can therefore be used in conditionals.
--
function loti_util_list_attacks(unit)
	-- Normalize to Lua unit object (to get unit.attacks)
	if type(unit) == "table" then
		unit = wesnoth.get_unit(unit.id)
	end

	local has_attack = {}
	for _, attack in ipairs(unit.attacks) do
		-- Remove trailing numbers, e.g. bow2 -> bow.
		local name = attack.name:gsub('%d+$', '')
		has_attack[name] = true
	end

	return has_attack
end
