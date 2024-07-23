
--! #textdomain "wesnoth-loti"

local _ = wesnoth.textdomain "wesnoth-loti"

local old_unit_status = wesnoth.interface.game_display.unit_status
function wesnoth.interface.game_display.unit_status()
	local u = wesnoth.interface.get_displayed_unit()
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
	if u.status.unslowable then
		table.insert(s, { "element", {
			image = "misc/unslowable.png",
			tooltip = _"unslowable: This unit cannot be affected by slow."
		} })
	end
	if u.status.unpoisonable then
		table.insert(s, { "element", {
			image = "misc/unpoisonable.png",
			tooltip = _"unpoisonable: This unit cannot be affected by poison."
		} })
	end
	if u.status.undrainable then
		table.insert(s, { "element", {
			image = "misc/undrainable.png",
			tooltip = _"undrainable: This unit cannot be drained."
		} })
	end
	if u.status.unplagueable then
		table.insert(s, { "element", {
			image = "misc/unplagueable.png",
			tooltip = _"unplagueable: This unit will not return as undead when killed by a plague weapon special."
		} })
	end
	if #s > 2 then -- Too long to fit the line
		local entire_string = s[2][2].tooltip
		for i = 3,#s do
			entire_string = entire_string .. "\n ----------\n\n" .. s[i][2].tooltip
		end
		local old_statuses = s
		s = {old_statuses[1], {"element", { image = "misc/icon-ellipsis.png", tooltip = entire_string }}}
	end
	return s
end

local old_unit_abilities = wesnoth.interface.game_display.unit_abilities
function wesnoth.interface.game_display.unit_abilities()
	local unit_hook = wesnoth.interface.get_displayed_unit()
	if not unit_hook then return {} end
	local unit = unit_hook.__cfg
	local abilities = wml.get_child(unit, "abilities")
	local buildup_table = {}
	for i = 1,#abilities do
		local function check_ability(id, getter, picture_positive, picture_negative, description)
			if abilities[i][2].id == id then
				local intensity = getter(abilities[i][2])
				if intensity > 0 then
					table.insert(buildup_table, { "element", { image = picture_positive, tooltip = string.format(description, intensity) } })
				elseif intensity < 0 then
					table.insert(buildup_table, { "element", { image = picture_negative, tooltip = string.format(description, intensity) } })
				end
			end
		end
		check_ability("latent_resolve", function(ability) return ability.add end, "misc/resolve.png", "misc/resolve_negative.png", _"%d%% to all resistances (halves every turn)")
		check_ability("latent_wrath", function(ability) return ability.add end, "misc/wrath.png", "misc/wrath_negative.png", _"%d to damage (halves every turn)")
		check_ability("latent_elusiveness", function(ability) return -ability.sub end, "misc/elusiveness.png", "misc/elusiveness_negative.png", _"%d%% enemy chance to hit (halves every turn)")
		check_ability("latent_precision", function(ability) return ability.add end, "misc/precision.png", "misc/precision_negative.png", _"%d%% chance to hit (halves every turn)")
		check_ability("latent_briskness", function(ability) return ability.add end, "misc/briskness.png", "misc/briskness_negative.png", _"%d to attack count (halves every turn)")
	end
	local displayed = old_unit_abilities()
	if #buildup_table > 0 then
		for i = 1,#displayed do
			table.insert(buildup_table, displayed[i])
		end
		displayed = buildup_table
	end
	return displayed
end

local old_heal_unit = wesnoth.wml_actions.heal_unit
function wesnoth.wml_actions.heal_unit(cfg)
	local respect_unhealable = cfg.respect_unhealable or true
	if respect_unhealable == false then
		old_heal_unit(cfg)
		return
	end

	if type(cfg) == "userdata" then
		cfg = cfg.__parsed
	end
	local filter = wml.get_child(cfg, "filter")
	table.insert(filter, {"not", {status = "unhealable"}})
	old_heal_unit(cfg)
end
