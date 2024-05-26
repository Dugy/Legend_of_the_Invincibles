
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

local old_heal_unit = wesnoth.wml_actions.heal_unit
function wesnoth.wml_actions.heal_unit(cfg)
	cfg = cfg.__parsed
	if cfg.respect_unhealable == false then
		old_heal_unit(cfg)
		return
	end

	local filter = wml.get_child(cfg, "filter")
	table.insert(filter, {"not", {status = "unhealable"}})
	old_heal_unit(cfg)
end
