local _ = wesnoth.textdomain "wesnoth-loti"

local function call_event_on_unit(u, name)
	wml.variables["updated"] = u
	wesnoth.wml_actions.fire_event{ name = name }
	u = wml.variables["updated"]
	return u
end

loti.legacy_list = {"fire_dragon_legacy", "ice_dragon_legacy", "dark_dragon_legacy", "undead_legacy", "legacy_of_kings", "legacy_of_titans", "legacy_of_sorrow", "legacy_of_light", "legacy_of_phoenix", "legacy_of_exile", "legacy_of_the_freezing_north", "legacy_of_the_free"}

local function get_random_seed_from_unit(unit)
	local seed = unit.x
	seed = (seed << 3) ~ unit.y -- bit shift 3 and xor
	if unit.type and string.len(unit.type) > 0 then
		seed = (seed << 3) ~ string.byte(unit.type)
	end
	if unit.race and string.len(unit.race) > 0 then
		seed = (seed << 3) ~ string.byte(unit.race)
	end
	if unit.id and string.len(unit.id) > 0 then
		seed = (seed << 3) ~ string.byte(unit.id,string.len(unit.id))
	end
	local base_seed = wml.variables["base_seed"]
	if not base_seed then
		base_seed = 0
	end
	seed = base_seed ~ seed
	return seed
end

-- This will need more edits once that WML intercompatibility is not needed
-- Parameter: original - WML table of [unit] tag.
-- Returns: modified WML table of [unit] tag.
function wesnoth.update_stats(original)
	-- PART I: WML pre-update hook
--	wesnoth.dbms{original.x, original.y}
	original = loti.get_unit(original)
	original = call_event_on_unit(original, "pre stats update")
	if not wml.get_child(original, "resistance") or not wml.get_child(original, "movement_costs") or not wml.get_child(original, "defense") then
		return original -- Fake unit
	end

	local hitpoints_ratio = original.hitpoints / original.max_hitpoints

	-- PART II: Cleanup
	local vars = wml.get_child(original, "variables")
	vars.update_started = true -- Prevent recursion in unit_placed
	local visible_modifications = wml.get_child(original, "modifications") -- This is where modifications actually affecting visuals belong
	local events_to_fire = {}
	local set_items = loti.unit.list_unit_item_numbers(original)

	-- Delete temporary objects and gems
	-- (e.g. when the gem is picked up, old WML code adds it as an item)
	loti.unit.remove_all_items(original, function(item)
		return item.sort and (item.sort:match("gem") or item.sort:match("temporary"))
	end)

	-- Check if geared and has legacy and adjust modifications appropriately
	local geared = #(loti.unit.list_unit_item_numbers(original)) > 0
	local marked_as_geared = false
	local has_legacy = false

	for i, modif in ipairs(visible_modifications) do
		if modif[1] == "trait" and modif[2].id == "geared" then
			if not geared then
				table.remove(visible_modifications, i)
			else
				marked_as_geared = true
			end
		end

		if modif[1] == "advancement" and modif[2].id and string.find(modif[2].id, "legacy") then
			has_legacy = true
		end
	end
	if geared and not marked_as_geared then
		table.insert(visible_modifications, { "trait", { id = "geared", name = _"GEARED", description = _"Geared: This unit is equipped with items. This is just to easily identify it on the recall list."}})
	end
	if not has_legacy and original.race ~= "undead" then
		local seed = get_random_seed_from_unit(original)
		local index = seed % #loti.legacy_list
		table.insert(visible_modifications, { "advancement", { id = loti.legacy_list[index + 1] }})
	end

	-- Remove objects providing visual effects
	for i = #visible_modifications,1,-1 do
		if visible_modifications[i][2].visual_provider == true then
			table.remove(visible_modifications, i)
		end
	end

	for i, item in ipairs(visible_modifications) do -- Update objects to reflect set effects and update items
		if item[1] == "object" and item[2].number and item[2].sort then
			visible_modifications[i][2] = loti.unit.item_with_set_effects(item[2].number, set_items, item[2].sort)

			-- Legacy field: used by WML menu "Items" to show "Remove item" options
			visible_modifications[i][2].description = loti.item.describe_item(item[2].number, item[2].sort, set_items)
		end
	end

	-- PART III: Recreate the unit
	local remade = wesnoth.units.create{ type = original.type, side = original.side, x = original.x, y = original.y, goto_x = original.goto_x, goto_y = original.goto_y, experience = original.experience, canrecruit = original.canrecruit, variation = original.variation, id = original.id, role = original.role, moves = original.moves, hitpoints = original.hitpoints, attacks_left = original.attacks_left, gender = original.gender, name = original.name, facing = original.facing, extra_recruit = original.extra_recruit, underlying_id = original.underlying_id, unrenamable = original.unrenamable, random_traits = false, { "status", wml.get_child(original, "status")}, { "variables", vars}, { "modifications", visible_modifications}}.__cfg
	vars = wml.get_child(remade, "variables")
	visible_modifications = wml.get_child(remade, "modifications")
	vars.updated = true
	vars.geared = geared

	-- Remove temporary dummy attacks
	for i = #remade,1,-1 do
		if remade[i][1] == "attack" and remade[i][2].temporary == true then
			table.remove(remade, i)
		end
	end

	-- PART IV: Read item properties
	local penetrations = {}
	local resistances = {}
	for i = 1,#damage_type_list do
		penetrations[damage_type_list[i]] = 0
		resistances[damage_type_list[i]] = 0
	end

	local weapon_bonuses = {}
	for i = 1,#weapon_type_list do
		weapon_bonuses[weapon_type_list[i]] = { damage = 100, attacks = 100, damage_plus = 0, weapon_damage_plus = 0, attacks_plus = 0, other_damage_type = 0, suck = 0, devastating_blow = 0, specials = {} }
	end

	local vision = 0
	local magic = 100
	local spell_suck = 0
	local defence = 100
	local dodge = 100

	for _, obj in loti.unit.effect_containers(remade) do
		if obj.defence then
			defence = defence * (100 - obj.defence) / 100
		end
		if obj.dodge then
			dodge = dodge * (100 - obj.dodge) / 100
		end
		if obj.magic then
			magic = magic + obj.magic
		end
		if obj.spell_suck then
			spell_suck = spell_suck + obj.spell_suck
		end
		if obj.vision then
			vision = vision + obj.vision
		end
		for j = 1,#resist_type_list do
			if obj[resist_type_list[j]] then
				resistances[damage_type_list[j]] = resistances[damage_type_list[j]] + obj[resist_type_list[j]]
			end
		end
		for j = 1,#resist_penetrate_list do
			if obj[resist_penetrate_list[j]] then
				penetrations[damage_type_list[j]] = penetrations[damage_type_list[j]] + obj[resist_penetrate_list[j]]
			end
		end
		local is_a_weapon = false
		for weapon = 1,#weapon_type_list do
			if obj.sort == weapon_type_list[weapon] then
				is_a_weapon = true
				local target = weapon_bonuses[obj.sort]
				local function add_to_property(property)
					if obj[property] then
						target[property] = target[property] + obj[property]
					end
				end
				add_to_property("damage")
				add_to_property("suck")
				add_to_property("devastating_blow")
				add_to_property("damage_plus")
				add_to_property("attacks")
				add_to_property("attacks_plus")
				if obj.icon then
					target.icon = obj.icon
				end
				if obj.damage_type then
					target.damage_type = obj.damage_type
				end
				if obj.merge then
					target.merge = obj.merge
				end
				if obj.name then
					target.name = obj.name
				end
				local specials = wml.get_child(obj, "specials")
				if specials then
					for j = 1,#specials do
						table.insert(target.specials, specials[j])
					end
				end
			end
		end
		if is_a_weapon == false then
			local function add_to_property(types, property, target_property)
				if obj[property] then
					for j = 1,#types do
						weapon_bonuses[types[j]][target_property] = weapon_bonuses[types[j]][target_property] + obj[property]
					end
				end
			end
			add_to_property(weapon_type_list, "damage", "damage")
			add_to_property(weapon_type_list, "damage_plus", "damage_plus")
			add_to_property(melee_type_list, "melee_damage", "damage")
			add_to_property(melee_type_list, "melee_damage_plus", "damage_plus")
			add_to_property(ranged_type_list, "ranged_damage", "damage")
			add_to_property(ranged_type_list, "ranged_damage_plus", "damage_plus")
			add_to_property(weapon_type_list, "attacks", "attacks_plus")
			add_to_property(weapon_type_list, "suck", "suck")
			add_to_property(weapon_type_list, "devastating_blow", "devastating_blow")
			if obj.damage_type then
				for j = 1,#weapon_type_list do
					weapon_bonuses[weapon_type_list[j]].nonweapon_damage_type = obj.damage_type
				end
			end
			local function add_specials(name, list)
				local specials = wml.get_child(obj, name)
				if specials then
					for j = 1,#specials do
						for k = 1,#list do
							table.insert(weapon_bonuses[list[k]].specials, specials[j])
						end
					end
				end
			end
			add_specials("specials", weapon_type_list)
			add_specials("specials_melee", melee_type_list)
			add_specials("specials_ranged", ranged_type_list)
		end
	end

	-- PART V: Apply item properties
	for weap in wml.child_range(remade, "attack") do
		local wn = weap.name -- Is used really a lot, so the name is better short
		local weapon_type

		local specials = wml.get_child(weap, "specials")
		if not specials then
			specials = { "specials", {}}
			table.insert(weap, specials)
		end

		weapon_type = loti.item.weapon_bindings[wn]

		if not weapon_type then
			if wn == "thorns" or wn == "gossamer" or wn == "entangle" or wn == "ensnare" or wn == "water spray" or wn == "ink" or wn == "magic blast" then
				weapon_type = "magic"
			elseif weap.range == "ranged" then
				if weap.type == "fire" or weap.type == "cold" or weap.type == "arcane" or weap.type == "lightning" then
					weapon_type = "magic"
				end
			end
		end

		if weapon_type == "magic" then
			weap.damage = weap.damage * magic / 100
			if spell_suck > 0 then
				table.insert(specials, { "dummy", { id = "spell_suck", suck = spell_suck}})
			end
		elseif weapon_type then
			local bonuses = weapon_bonuses[weapon_type]
			weap.damage = weap.damage * bonuses.damage / 100 + bonuses.damage_plus
			if weapon_type ~= "thunderstick" then
				weap.number = weap.number * bonuses.attacks / 100 + bonuses.attacks_plus
			else
				weap.number = weap.number * bonuses.attacks / 100
			end
			if weap.number < 1 then
				weap.number = 1
			end
			if bonuses.icon then
				weap.icon = bonuses.icon
			end
			if bonuses.suck > 0 then
				table.insert(specials, { "dummy", { id = "suck", suck = bonuses.suck}})
			end
			if bonuses.merge == true then
				weap.damage = weap.damage * weap.number
				weap.number = 1
			end
			if bonuses.damage_type then
				weap.type = bonuses.damage_type
			end
			if bonuses.nonweapon_damage_type then
				weap.type = bonuses.nonweapon_damage_type
			end
			if bonuses.name then
				weap.description = bonuses.name
			end
			if bonuses.devastating_blow > 0 then
				table.insert(wml.get_child(weap, "specials"), { "dummy", { id = "devastating_blow", name = _"devastating blow", description = (_"$chance% chance that the enemy will lose 20% of their health on each hit"):vformat{chance = bonuses.devastating_blow}, devastating_blow = bonuses.devastating_blow }})
			end
			for k = 1,#bonuses.specials do
				table.insert(wml.get_child(weap, "specials"), bonuses.specials[k])
			end
		end
	end

	local remade_resistance = wml.get_child(remade, "resistance")
	for i = 1,#damage_type_list do
		remade_resistance[damage_type_list[i]] = remade_resistance[damage_type_list[i]] - resistances[damage_type_list[i]]
	end
	remade_resistance.blade = remade_resistance.blade * defence / 100
	remade_resistance.pierce = remade_resistance.pierce * defence / 100
	remade_resistance.impact = remade_resistance.impact * (0.5 + defence / 200) -- Hammers always penetrated armours better than swords

	local function limit_resistance(damage_type, max)
		if remade_resistance[damage_type] < max then
			remade_resistance[damage_type] = max
		end
	end
	limit_resistance("fire", 10);
	limit_resistance("cold", 10);
	limit_resistance("arcane", 30);
	limit_resistance("blade", 20);
	limit_resistance("pierce", 20);
	limit_resistance("impact", 20);

	remade.vision = remade.max_moves + vision

	local remade_abilities = wml.get_child(remade, "abilities")
	if not remade_abilities then
		remade_abilities = { "abilities", {}}
		table.insert(remade, remade_abilities)
	end

	for i = 1,#damage_type_list do
		if penetrations[damage_type_list[i]] > 0 then
			table.insert(remade_abilities, { "resistance", { id = resist_penetrate_list[i], sub = penetrations[damage_type_list[i]], max_value = 80, affect_enemies = true, affect_allies = false, affect_self = false, apply_to = damage_type_list[i], { "affect_adjacent", { adjacent = "n,ne,se,s,sw,nw" }}}})
		end
	end

	local remade_defences = wml.get_child(remade, "defense")
	if not remade_defences then
		remade_defences = { "defense", {}}
		table.insert(remade, remade_defences)
	end
	if dodge ~= 100 then
		for terrain,def in pairs(remade_defences) do
			remade_defences[terrain] = def * dodge / 100
			if def < 20 and def > 0 then
				remade_defences[terrain] = 20
			end
		end
	end

	remade.hitpoints = remade.max_hitpoints * hitpoints_ratio
	if remade.hitpoints > remade.max_hitpoints then
		remade.hitpoints = remade.max_hitpoints
	end

	-- PART VI: Apply additional effects

	local visual_effects = {}
	local is_loyal

	for index, eff in loti.unit.effects(remade) do -- luacheck: ignore 213/index
		-- TODO: Add alignment, max_attacks and new_advancement using wesnoth.effects
		if eff.apply_to == "alignment" then
			remade.alignment = eff.alignment
		end
		if eff.apply_to == "loyal" then
			is_loyal = true
		end
		if eff.apply_to == "ellipse" then
			is_loyal = false
		end
		if remade.canrecruit then
			is_loyal = false
		end
		if eff.apply_to == "attack" then
			if eff.set_icon then
				local function set_if_same(property) -- Warning, this makes the change only very roughly
					if eff[property] then
						for atk in wml.child_range(remade, "attack") do
							if atk[property] == eff[property] then
								atk.icon = eff.set_icon
							end
						end
					end
				end
				set_if_same("name")
				set_if_same("description")
				set_if_same("range")
				set_if_same("type")
			end
		end
		if eff.apply_to == "max_attacks" then
			remade.max_attacks = remade.max_attacks + eff.add
		end
		if eff.apply_to == "new_advancement" then
			local has_it = false
			for k = 1,#visible_modifications do -- TODO: Might need to look for it in vars instead
				if visible_modifications[k][1] == "advancement" and visible_modifications[k][2].id == eff.id then
					has_it = true
					break
				end
			end
			if has_it == false then
				table.insert(visible_modifications, { "advancement", { id = eff.id }})
			end
		end
		if eff.apply_to == "bonus_attack" then
			local strongest_attack = nil
			local strongest_damage = -9000
			for k = 1,#remade do
				if remade[k][1] == "attack" then
					local atk = remade[k][2]
					if eff.force_original_attack then
						if eff.force_original_attack == atk.name then
							strongest_attack = atk
							break
						end
					end
					if (not eff.range or eff.range == atk.range) and not atk.is_bonus_attack then
						local damage = math.floor(atk.damage) * math.floor(atk.number)
						if eff.force_original_type and eff.force_original_type == atk.type then
							damage = damage * 1000000
						end
						if damage > strongest_damage then
							strongest_attack = atk
							strongest_damage = damage
						end
					end
				end
			end
			if not strongest_attack or (eff.force_original_type and strongest_attack.type ~= eff.force_original_type) then
				strongest_attack = { name = "fangs", description = _"fangs", icon = "attacks/fangs-animal.png", type = "blade", range = eff.range or "melee", damage = 5, number = 4, { "specials", {}}}
			else
				strongest_attack = wesnoth.deepcopy(strongest_attack)
			end
			strongest_attack.is_bonus_attack = true
			if eff.clone_anim then
				local right_anim
				local function get_best_anim(source)
					for anim in wml.child_range(source, "attack_anim") do
						local filter = wml.get_child(anim, "filter_attack")
						if filter and filter.name == strongest_attack.name then
							right_anim = anim
							break -- priority
						elseif filter and filter.range == strongest_attack.range then
							right_anim = anim
						elseif not filter then
							right_anim = anim
						end
					end
				end
				local unit_type = wesnoth.unit_types[remade.type].__cfg
				if remade.gender == "female" then
					local female = wml.get_child(unit_type, "female")
					if female then
						unit_type = female
					end
				end
				get_best_anim(unit_type)
				for variation in wml.child_range(unit_type, "variation") do
					if variation.variation_name == remade.variation then
						get_best_anim(variation)
					end
				end
				if not right_anim then
					for _, inner_eff in loti.unit.effects(remade) do
						if inner_eff.apply_to == "new_animation" then
							local filter = wml.get_child(inner_eff, "filter")
							if not filter or not filter.gender or filter.gender == remade.gender then
								for anim in wml.child_range(inner_eff, "attack_anim") do
									filter = wml.get_child(anim, "filter_attack")
									if filter or (filter.name and filter.name == strongest_attack.name) or (filter.range and filter.range == strongest_attack.range) then
										right_anim = anim
									end
								end
							end
						end
					end
				end

				if right_anim then
					right_anim = wesnoth.deepcopy(right_anim)
					local filter = wml.get_child(right_anim, "filter_attack")
					if filter.name then
						filter.name = eff.name
					end
					table.insert(visual_effects, { apply_to = "new_animation", name = "animation_object_" .. eff.name, { "attack_anim", right_anim }})
				else
					-- This should not happen
					wesnoth.log("warning", "Couldn't find right animation for unit " .. tostring(remade.id))
				end
			end
			strongest_attack.name = eff.name
			if eff.type then
				strongest_attack.type = eff.type
			end
			if eff.icon then
				strongest_attack.icon = eff.icon
			end
			local damage = 100
			local attacks = 100
			if eff.damage then
				damage = damage + eff.damage
			end
			if eff.number then
				attacks = attacks + eff.number
			end
			if eff.attacks then
				attacks = attacks + eff.attacks
			end
			if eff.defense_weight then
				strongest_attack.defense_weight = eff.defense_weight
			end
			if eff.attack_weight then
				strongest_attack.attack_weight = eff.attack_weight
			end
			if eff.description then
				strongest_attack.description = eff.description
			end
			-- Check if it's improved somewhere (I know this could be done with a better complexity)
			for _, other_effect in loti.unit.effects(remade) do
				if other_effect.apply_to == "improve_bonus_attack" and other_effect.name == eff.name then
					if other_effect.increase_damage then
						damage = damage + other_effect.increase_damage
					end
					if other_effect.increase_attacks then
						attacks = attacks + other_effect.increase_attacks
					end
				end
			end
			strongest_attack.damage = strongest_attack.damage * damage / 100
			strongest_attack.number = strongest_attack.number * attacks / 100
			if eff.merge then
				strongest_attack.damage = strongest_attack.damage * strongest_attack.number
				strongest_attack.number = 1
			elseif strongest_attack.number < 1 then
				strongest_attack.number = 1
			end
			local specials = wml.get_child(eff, "specials")
			if specials then
				for k = 1,#specials do
					table.insert(wml.get_child(strongest_attack, "specials"), specials[k])
				end
			end
			table.insert(remade, { "attack", strongest_attack})
		end
	end

	-- PART VII: Modify attacks
	for atk in wml.child_range(remade, "attack") do
		local specials = wml.get_child(atk, "specials")
		-- Redeem must need recharging
		if atk.name == "redeem" then
			atk.damage = 1
			atk.number = 1
			local status = wml.get_child(remade, "status")
			if status.redeem_waiting then
				atk.attack_weight = 0
			end
		end
		-- Only the strongest backstab applies
		local best_backstab_mult = 0
		local best_backstab
		for i = #specials,1,-1 do
			if specials[i][1] == "damage" and string.match(specials[i][2].id, "backstab") then
				local quality = specials[i][2].multiply

				if quality then
					if specials[i][2].apply_to ~= "both" then
						quality = quality * 0.75 -- Charging backstab is worse
					end

					if quality > best_backstab_mult then
						best_backstab_mult = quality
						best_backstab = specials[i]
					end
				end
				table.remove(specials, i)
			end
		end
		if best_backstab then
			table.insert(specials, best_backstab)
		end
		local wrath_intensity = 0
		if vars.wrath == true then
			wrath_intensity = vars.wrath_intensity
		end
		table.insert(specials, { "damage", { id = "latent_wrath", apply_to = "self", add = wrath_intensity }})
	end

	-- PART VIII: Apply visual effects
	if #visual_effects > 0 then
		local visual_obj = { visual_provider = true }
		for i = 1,#visual_effects do
			table.insert(visual_obj, { "effect", visual_effects[i] })
		end
		table.insert(visible_modifications, { "object", visual_obj})
	end

	-- Make some abilities have a visual effect
	for i = 1,#remade_abilities do
		local ability = remade_abilities[i][2]
		local name = remade_abilities[i][1]
		if name == "illuminates" then
			if ability.value > 0 then
				remade.halo = "halo/illuminates-aura.png"
			elseif ability.value < 0 then
				remade.halo = "halo/darkens-aura.png"
			end
		elseif name == "berserk" and ability.id == "berserk_leadership" then
			remade.halo = "misc/berserk-1.png:100,misc/berserk-2.png:100,misc/berserk-3.png:100,misc/berserk-2.png:100"
		elseif name == "damage" and ability.id == "charge_leadership" then
			remade.halo = "misc/charge-1.png:100,misc/charge-2.png:100,misc/charge-3.png:100,misc/charge-2.png:100"
		elseif name == "poison" and ability.id == "poison_leadership" then
			remade.halo = "misc/poison-1.png:200,misc/poison-2.png:200,misc/poison-3.png:200,misc/poison-2.png:200"
		elseif name == "firststrike" and ability.id == "firststrike_leadership" then
			remade.halo = "misc/firststrike-1.png:100,misc/firststrike-2.png:100,misc/firststrike-3.png:100"
		elseif name == "damage" and ability.id == "backstab_leadership" then
			remade.halo = "misc/backstab-1.png:200,misc/backstab-2.png:200,misc/backstab-3.png:200,misc/backstab-2.png:200"
		elseif name == "chance_to_hit" and ability.id == "marksman_leadership" then
			remade.halo = "misc/marksman-1.png:100,misc/marksman-2.png:100,misc/marksman-3.png:100,misc/marksman-2.png:100"
		elseif name == "drains" and ability.id == "drain_leadership" then
			remade.halo = "misc/drain-1.png:200,misc/drain-2.png:200,misc/drain-3.png:200,misc/drain-2.png:200"
		elseif name == "dummy" and ability.id == "northfrost aura" then
			remade.halo = "halo/blizzard-1.png~O(40%):100,halo/blizzard-2.png~O(40%):100,halo/blizzard-3.png~O(40%):100"

		end
	end

	local new_overlays = {}
	if is_loyal then
		table.insert(new_overlays, "misc/loyal-icon.png")
	end
	local sorts_owned = {}
	for _, obj in loti.unit.items(remade) do
		if obj.sort then
			sorts_owned[obj.sort] = true
		end
	end
	if sorts_owned.armour or sorts_owned.helm or sorts_owned.shield or sorts_owned.boots or sorts_owned.gauntlets then
		table.insert(new_overlays, "misc/armour-overlay.png")
	end
	for i = 1,#weapon_type_list do
		if sorts_owned[weapon_type_list[i]] then
			table.insert(new_overlays, "misc/sword-overlay.png")
			break
		end
	end
	if sorts_owned.potion then
		table.insert(new_overlays, "misc/flamesword-overlay.png")
	end
	if sorts_owned.amulet or sorts_owned.ring or sorts_owned.cloak or sorts_owned.limited then
		table.insert(new_overlays, "misc/orb-overlay.png")
	end
	local has_leadership_item = false
	for _, eff in loti.unit.effects(remade) do
		if eff.apply_to == "new_ability" then
			local abilities = wml.get_child(eff, "abilities")
			if abilities and wml.get_child(abilities, "leadership") then
				has_leadership_item = true
			end
		end
	end
	if has_leadership_item then
		table.insert(new_overlays, "misc/fist-overlay.png")
	end
	local overlays_object = { "object", { visual_provider = true, { "effect", { apply_to = "overlay", add = table.concat(new_overlays, ",")}}}}
	table.insert(visible_modifications, overlays_object)


	-- PART IX: Some final changes
	for i = #vars,1,-1 do
		if vars[i][1] == "disabled_defences" then
			local found = false
			for atk in wml.child_range(remade, "attack") do
				if atk.name == vars[i][2].name then
					atk.defense_weight = 0
					found = true
				end
			end
			if not found then
				table.remove(vars, i)
			end
		end
	end
	table.insert(events_to_fire, 1, "post stats update")

	local new_advances_to = {}
	for t in string.gmatch(remade.advances_to, "[^%s,][^,]*") do
		if not string.match(t, "Advancing") then
			table.insert(new_advances_to, t)
		end
	end
	remade.advances_to = table.concat(new_advances_to, ",")

	-- PART X: Call WML hooks
	for i = 1,#events_to_fire do
		remade = call_event_on_unit(remade, events_to_fire[i])
	end
	-- Restore unit from variable after the WML hooks.
	wesnoth.wml_actions.unstore_unit { variable = "updated", find_vacant = "no", check_passability = false }
	return remade
end

-- WML tag
function wesnoth.wml_actions.update_stats(cfg)
	local units = wesnoth.units.find_on_map(cfg)
	for i = 1,#units do
		local unit = units[i].__cfg
		if wml.get_child(unit, "resistance") and wml.get_child(unit, "movement_costs") and wml.get_child(unit, "defense") then
			unit = wesnoth.update_stats(unit)
			wesnoth.units.to_map(unit)
		end
	end
end
