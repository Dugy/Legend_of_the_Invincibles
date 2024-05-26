--! #textdomain "wesnoth-loti"
--
-- Implementation of redeem upgrades menu (for Demigod units) and redeem-related utility functions.
--

local _ = wesnoth.textdomain "wesnoth-loti"

local known_ability_trees = {}

known_ability_trees.redeem = {
	spirit = {
		image = "attacks/spirit.png",
		label =_ "Spiritual transformation (only for attacking, a very powerful combat technique)",
		requires = { "absorb", "weapons" },

		-- Short names are used in "Requires: [upgrade1], [upgrade2], ..." lists.
		short_name =_ "Spiritual transformation"
	},
	particlestorm = {
		image = "attacks/particle-storm.png",
		label =_ "Particle Storm (only for attacking, a very powerful offensive spell)",
		requires = { "blizzard", "firestorm", "entropy" },
		short_name =_ "Particle Storm"
	},
	absorb = {
		image = "attacks/dark-missile.png",
		label =_ "Absorption (advancements that allow the unit heal from enemy attacks)",
		requires = { "regeneration" },
		short_name =_ "Absorb"
	},
	firestorm = {
		image = "attacks/firestorm.png",
		label =_ "Firestorm (only for attacking, great damage and range)",
		requires = { "fireblast" },
		short_name =_ "Firestorm"
	},
	blizzard = {
		image = "attacks/blizzard.png",
		label =_ "Blizzard (only for attacking, slows a lot of units)",
		requires = { "arcticblast" },
		short_name =_ "Blizzard"
	},
	regeneration = {
		image = "icons/potion_green_medium.png",
		label =_ "Regeneration (advancements improving the regeneration)",
		requires = { "health" },
		short_name =_ "Regeneration"
	},
	lightning = {
		image = "attacks/lightning.png",
		label =_ "Lightning (high damage, few attacks, can get firststrike)",
		requires = {},
		short_name =_ "Lightning"
	},
	fireblast = {
		image = "attacks/fire-blast.png",
		label =_ "Fire Blast (only for attacking, quite powerful fiery attack)",
		requires = {},
		short_name =_ "Fire Blast"
	},
	fire_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Fire resistance penetration",
		requires = { "firestorm" }
	},
	arcticblast = {
		image = "attacks/ice-blast.png",
		label =_ "Arctic Blast (only for attacking, capable to slow a lot of units)",
		requires = {},
		short_name =_ "Arctic Blast"
	},
	cold_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Cold resistance penetration",
		requires = { "blizzard" }
	},
	entropy = {
		image = "attacks/dark-missile.png",
		label =_ "Entropy (a powerful arcane attack, good for retaliation)",
		requires = {},
		short_name =_ "Entropy"
	},
	arcane_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Arcane resistance penetration",
		requires = { "magic" }
	},
	resist_fire = {
		image = "attacks/blank-attack.png~BLIT(items/armour-fire.png~SCALE_INTO(60,60))",
		label =_ "Resist fire",
		requires = { "fireblast" }
	},
	resist_cold = {
		image = "attacks/blank-attack.png~BLIT(items/armour-ice.png~SCALE_INTO(60,60))",
		label =_ "Resist cold",
		requires = { "arcticblast" }
	},
	resist_arcane = {
		image = "attacks/blank-attack.png~BLIT(items/armour-arcane.png~SCALE_INTO(60,60))",
		label =_ "Resist arcane",
		requires = { "magic" }
	},
	health = {
		image = "icons/potion_red_medium.png",
		label =_ "Health (+10 to HP advancements)",
		requires = {},
		short_name =_ "Health"
	},
	leadership = {
		image = "attacks/fist.png",
		label =_ "Leadership",
		requires = {}
	},
	heal = {
		image = "attacks/lightbeam.png",
		label =_ "Healing others",
		requires = {}
	},
	blade_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Blade resistance penetration",
		requires = { "weapons" }
	},
	impact_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Impact resistance penetration",
		requires = { "weapons" }
	},
	pierce_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Pierce resistance penetration",
		requires = { "weapons" }
	},
	resist_blade = {
		image = "icons/armor_leather.png",
		label =_ "Resist blade",
		requires = { "health" }
	},
	resist_pierce = {
		image = "icons/armor_leather.png",
		label =_ "Resist pierce",
		requires = { "health" }
	},
	resist_impact = {
		image = "icons/armor_leather.png",
		label =_ "Resist impact",
		requires = { "health" }
	},
	weapons = {
		image = "attacks/longsword.png",
		label =_ "Weapons (improved advancements to weapons' damage)",
		requires = {},
		short_name =_ "Weapons"
	},
	magic = {
		image = "attacks/fireball.png",
		label =_ "Magic (improved advancements to magical damage)",
		requires = {},
		short_name =_ "Magic"
	}
}

known_ability_trees.soul_eater = {
	spirit = {
		image = "attacks/spirit.png",
		label =_ "Spiritual transformation (a very powerful combat technique)",
		requires = { "absorb" },
		short_name =_ "Spiritual transformation"
	},
	regeneration = {
		image = "icons/potion_green_medium.png",
		label =_ "Regeneration (advancements improving the regeneration)",
		requires = { "health" },
		short_name =_ "Regeneration"
	},
	absorb = {
		image = "attacks/dark-missile.png",
		label =_ "Absorption (advancements that allow the unit heal from enemy attacks)",
		requires = { "regeneration" },
		short_name =_ "Absorb"
	},
	lightning = {
		image = "attacks/lightning.png",
		label =_ "Lightning (high damage, few attacks, can get firststrike)",
		requires = { "fireball", "chill" },
		short_name =_ "Lightning"
	},
	thunder = {
		image = "attacks/lightning.png",
		label =_ "Thunder (high damage, explosive, great area of effect, only a very few attacks)",
		requires = { "lightning" },
		short_name =_ "Thunder"
	},
	fireball = {
		image = "attacks/fireball.png",
		label =_ "Fireball (quite powerful fiery attack)",
		requires = {},
		short_name =_ "Fireball"
	},
	meteor = {
		image = "attacks/meteor.png",
		label =_ "Meteor (great damage, range and precision, only one attack)",
		requires = { "fireball" },
		short_name =_ "Meteor"
	},
	fire_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Fire resistance penetration",
		requires = { "meteor" }
	},
	chill = {
		image = "attacks/iceball.png",
		label =_ "Chill tempest (capable to slow a lot of units)",
		requires = {},
		short_name =_ "Chill tempest"
	},
	cold_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Cold resistance penetration",
		requires = { "chill" }
	},
	shadowwave = {
		image = "attacks/dark-missile.png",
		label =_ "Shadow wave (can become a powerful draining ability)",
		requires = {},
		short_name =_ "Shadow wave"
	},
	arcane_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Arcane resistance penetration",
		requires = { "shadowwave" }
	},
	resist_fire = {
		image = "attacks/blank-attack.png~BLIT(items/armour-fire.png~SCALE_INTO(60,60))",
		label =_ "Resist fire",
		requires = { "fireball" }
	},
	resist_cold = {
		image = "attacks/blank-attack.png~BLIT(items/armour-ice.png~SCALE_INTO(60,60))",
		label =_ "Resist cold",
		requires = { "chill" }
	},
	resist_arcane = {
		image = "attacks/blank-attack.png~BLIT(items/armour-arcane.png~SCALE_INTO(60,60))",
		label =_ "Resist arcane",
		requires = { "shadowwave", "chill" }
	},
	health = {
		image = "icons/potion_red_medium.png",
		label =_ "Health (+10 to HP advancements)",
		requires = {},
		short_name =_ "Health"
	},
	leadership = {
		image = "attacks/fist.png",
		label =_ "Leadership",
		requires = {}
	},
	heal = {
		image = "attacks/lightbeam.png",
		label =_ "Healing others",
		requires = {}
	},
	blade_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Blade resistance penetration",
		requires = { "health" }
	},
	impact_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Impact resistance penetration",
		requires = { "health" }
	},
	pierce_penetrate = {
		image = "attacks/noctum.png",
		label =_ "Pierce resistance penetration",
		requires = { "health" }
	},
	resist_blade = {
		image = "icons/armor_leather.png",
		label =_ "Resist blade",
		requires = { "health" }
	},
	resist_pierce = {
		image = "icons/armor_leather.png",
		label =_ "Resist pierce",
		requires = { "health" }
	},
	resist_impact = {
		image = "icons/armor_leather.png",
		label =_ "Resist impact",
		requires = { "health" }
	}
}

-- Determine the list of redeem upgrades (e.g. "particlestorm")
-- that have already been picked by this Unit.
-- Parameter "ability_tree" can be "redeem" or "soul_eater".
-- Returns the Lua table { firestorm = 1, lightning = 1, ... }.
local function loti_util_list_existing_upgrades(ability_tree, unit)
	local known_upgrades = known_ability_trees[ability_tree]
	local found = {}

	local modifications = wml.get_child(unit.__cfg, "modifications")
	for _, advancement in ipairs(wml.child_array(modifications, "advancement")) do
		if known_upgrades[advancement.id] then
			found[advancement.id] = 1
		end
	end

	return found
end

-- Display the menu that chooses between redeem upgrades available to certain Unit.
-- Parameter "ability_tree" can be "redeem" or "soul_eater".
-- Returns the selected upgrade (ID string), e.g. "particlestorm".
local function redeem_menu(ability_tree, unit)
	local known_upgrades = known_ability_trees[ability_tree]
	if not known_upgrades then
		wml.error("redeem_menu(): unknown ability tree. Try \"redeem\" or \"soul_eater\".");
	end

	-- Unit is optional, so that we can test UI of redeem_menu() separately from everything else.
	local existing_upgrades = {}
	if unit then
		existing_upgrades = loti_util_list_existing_upgrades(ability_tree, unit)
	end

	-- Menu items, as expected by gui.show_menu()
	local menu_items = {}

	for id, upgrade in pairs(known_upgrades) do
		-- If haven't already picked
		if not existing_upgrades[id] then
			-- Check if all required upgrades have already been picked
			local unmet_dependencies = {}
			for _, required_upgrade in ipairs(upgrade.requires) do
				if not existing_upgrades[required_upgrade] then
					table.insert(unmet_dependencies, required_upgrade)
				end
			end

			local label = upgrade.label

			-- Inform the player which upgrades are needed before this one can get picked.
			if unmet_dependencies[1] then
				label = label .. "\n" .. _("Requires:") .. " "

				-- Can't use table.concat(), because unmet_dependencies has translated strings,
				-- and they are technically objects.
				for nr3, required_id in ipairs(unmet_dependencies) do
					local required_upgrade = known_upgrades[required_id]
					local extra_label = required_upgrade.short_name or required_upgrade.label

					label = label .. extra_label
					if nr3 ~= #unmet_dependencies then
						label = label .. ", "
					end
				end
			end

			table.insert(menu_items, {
				-- Fields with the same meaning as in gui.show_menu()
				image = upgrade.image,
				details = label,

				-- This field is used to determine which upgrade has been selected.
				selected_upgrade = id,

				-- If false, this upgrade can't be selected yet.
				allowed = not unmet_dependencies[1]
			})
		end
	end

	-- Determine the order of menu_items[] array. Non-allowed items should be last.
	local function menu_sort(a, b)
		if a.allowed and not b.allowed then
			return true
		end

		if b.allowed and not a.allowed then
			return false
		end

		return a.details < b.details
	end

	table.sort(menu_items, menu_sort)

	-- Prepare the layout structure for gui.show_dialog().
	local listbox_id = "redeem_menu_list"

	-- 1) listbox_template: shows one possible upgrade (icon + description), e.g. Particle Storm.
	local listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				grow_factor = 0,
				border = "all",
				border_size = 5,
				horizontal_alignment = "left",
				wml.tag.image {
					id = "image"
				}
			},
			wml.tag.column {
				grow_factor = 1,
				border = "all",
				border_size = 5,
				horizontal_grow = true,
				wml.tag.label {
					id = "upgrade_name",
					text_alignment = "left"
				}
			}
		}
	}

	-- 2) listbox_widget: shows a list of all upgrades.
	local listboxDefinition = wml.tag.listbox { id = listbox_id,
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					wml.tag.toggle_panel { listbox_template }
				}
			}
		}
	}

	-- 3) Top-level dialog, includes help message and listbox.
	local dialogDefinition = {
		wml.tag.tooltip { id = "tooltip" },
		wml.tag.helptip { id = "tooltip" },
		wml.tag.grid {
			-- Header (1 row containing a [label] with help)
			wml.tag.row {
				wml.tag.column {
					border = "bottom",
					border_size = 10,
					wml.tag.label {
						id = "redeem_menu_top_label",
						use_markup = true,
						label = "<span size='large' weight='bold'>" ..
							_"Which new advancement path should our victorious unit get?" .. "</span>"
					}
				}
			},

			-- A unit preview panel, and
			-- Listbox, where each row shows ONE of the possible upgrades (e.g. "particlestorm")
			wml.tag.row {
				wml.tag.column {
					wml.tag.grid {
						wml.tag.row {
							wml.tag.column {
								border = "right",
								border_size = 30,
								wml.tag.unit_preview_pane { id = "unit_preview" }
							},
							wml.tag.column { horizontal_grow = true, listboxDefinition }
						}
					}
				}

			},

			-- OK button
			wml.tag.row {
				wml.tag.column {
					border = "top",
					border_size = 10,
					wml.tag.button { id = "ok", label = _"OK" },
				}
			}
		}
	}

	local function get_selected_menu_item(dialog)
		local index = dialog[listbox_id].selected_index
		return menu_items[index]
	end

	local function preshow(dialog)
		local listbox = dialog[listbox_id]
		dialog.unit_preview.unit = unit

		for index, menu_item in ipairs(menu_items) do
			listbox[index].image.label = menu_item.image
			listbox[index].upgrade_name.label = menu_item.details

			if not menu_item.allowed then
				listbox[index].upgrade_name.enabled = false
			end
		end

		-- If user selects a non-allowed upgrade, OK button must become disabled.
		-- If user then selects an allowed upgrade, OK button must become enabled.
		local function toggle_ok_button()
			dialog.ok.enabled = get_selected_menu_item(dialog).allowed
		end

		listbox.on_modified = toggle_ok_button
		listbox:focus()
	end

	local selected_menu_item = nil
	local function postshow(dialog)
		selected_menu_item = get_selected_menu_item(dialog)
	end

	gui.show_dialog(dialogDefinition, preshow, postshow)

	if not selected_menu_item.allowed then
		-- Disabled menu item was somehow selected,
		-- ignore this and just show the dialog again.
		return redeem_menu(ability_tree, unit)
	end

	return selected_menu_item.selected_upgrade
end

-- Tag [show_redeem_menu] allows to use redeem upgrade menu from WML.
-- Unit is identified by cfg.find_in parameter (e.g. find_in=secondary_unit).
-- Parameter cfg.ability_tree can be "redeem" or "soul_eater" (chooses what menu to show).
-- Returns the selected upgrade (ID string), e.g. "particlestorm".
-- Result is placed into Wesnoth variable cfg.to_variable.
function wesnoth.wml_actions.show_redeem_menu(cfg)
	local to_variable = cfg.to_variable or "chose"
	local ability_tree = cfg.ability_tree or "redeem"

	local units = wesnoth.units.find_on_map(cfg)
	if #units < 1 then
		wml.error("[show_redeem_menu]: no units found, may need find_in= parameter.")
	end

	local result = wesnoth.sync.evaluate_single(_"Soul Eater", function()
		local res = redeem_menu(ability_tree, units[1])
		return {wml.tag.soul_eater_choice {choice = res}}
	end)
	wml.variables[to_variable] = result[1][2].choice
end

-- Tag [count_redeem_upgrades] counts the number of existing redeem upgrades of current unit.
-- Result is placed into Wesnoth variable cfg.to_variable.
-- Unit is identified by cfg.find_in parameter (e.g. find_in=secondary_unit).
-- NOTE: this is TEMPORARY (won't be needed in the future),
-- because the WML code that needs this variable might be replaced by Lua.
--
function wesnoth.wml_actions.count_redeem_upgrades(cfg)
	local to_variable = cfg.to_variable or "upgrade_count"

        local units = wesnoth.units.find_on_map(cfg)
	if #units < 1 then
		wml.error("[count_redeem_upgrades]: no units found, may need find_in= parameter.")
	end

	local count = 0
	for _ in pairs(loti_util_list_existing_upgrades("redeem", units[1])) do count = count + 1 end

	wml.variables[to_variable] = count
end

-- max_redeem_count_from_level gets the max redeem count for a redeem level.
local function max_redeem_count_from_level(level)
    -- max_redeem_count(n+1)=max_redeem_count(n)+floor(n*4/3), where n is redeem level
    --   and max_redeem_count(1) = 6.
    -- Instead of repeatedly calculating these values, they are presented here (with plenty of extras for future use)
    local my_level = level or wml.error("max_redeem_count_from_level: missing input value (level)")
    local max_redeem_count_list = {6, 8, 10, 13, 17, 22, 29, 38, 50, 66, 88, 117, 156, 208, 277, 369, 492, 656, 874, 1165, 1553, 2070, 2760, 3680, 4906, 6541, 8721, 11628, 15504, 20672, 27562, 36749, 48998, 65330, 87106, 116141, 154854, 206472, 275296, 367061}
    return max_redeem_count_list[my_level]
end

-- Tag [max_redeem_count_from_level] gets the max redeem count for a redeem level.
-- Result is placed into Wesnoth variable cfg.to_variable.
-- Requires cfg.to_variable, cfg.level
function wesnoth.wml_actions.max_redeem_count_from_level(cfg)
    local to_variable = cfg.to_variable or wml.error("[max_redeem_from_level]: missing to_variable= .")
    local level = cfg.level or wml.error("[max_redeem_from_level]: missing level= .")
    wml.variables[to_variable] = max_redeem_count_from_level(level)
end

-- redeem_hit_chance returns the chance of redeem success based on redeem level and target's level
-- distance indicates whether target is the unit redeemer attacks (distance=0), or a unit adjacent to the
-- unit redeemer attacks (distance=1)
local function redeem_hit_chance(redeem_level,target_level,distance)
	-- nil result indicates no chance
	local hit_chance = 0

	if (distance < 0) or (distance > 1) then wml.error("does_redeem_hit:  distance must be 0 or 1") end
	-- tables based on formulae that can be found at https://github.com/Dugy/Legend_of_the_Invincibles/blob/7397831e6b6693612bb455a8acb26acf8be4e69f/utils/redeeming.cfg#L264
	local chance={ 	-- chance to sucessfully hit redeem defender
			-- index = redeem level, value = table of probablity by target level (from 0)
		{ 100, 100,  50,  25 },
		{ 100, 100, 100,  50,  25 },
		{ 100, 100, 100,  75,  50,  25,  10},
		{ 100, 100, 100, 100,  75,  50,  25,  10},
		{ 100, 100, 100, 100,  75,  50,  25,  10}, -- redeem level 5
		{ 100, 100, 100, 100, 100,  75,  50,  25,  10},
		{ 100, 100, 100, 100, 100, 100,  75,  50,  25,  10},
		{ 100, 100, 100, 100, 100, 100, 100,  75,  50,  25,  10},
		{ 100, 100, 100, 100, 100, 100,  90,  60,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100,  90,  60,  40,  30,  20,  10},  -- redeem level 10
		{ 100, 100, 100, 100, 100, 100, 100, 100,  90,  60,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10}, -- redeem level 15
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100,  90,  80,  70,  60,  50,  40,  30,  20,  10}
	}

	local adj_chance={	-- chance to sucessfully hit unit adjacent to redeem defender
				-- index = redeem level, value = table of probablity by target level (from 0)
		{},{},{},{},   -- redeem level 1-4 don't hit adjacent to target
		{ 100, 100,  50,  25}, -- redeem level 5
		{ 100, 100,  50,  25},
		{ 100, 100, 100,  50,  25},
		{ 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100,  50,  25}, -- redeem level 10
		{ 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100, 100, 100,  50,  25}, -- redeem level 15
		{ 100, 100, 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100,  50,  25},
		{ 100, 100, 100, 100, 100, 100, 100, 100, 100,  50,  25}
	}

	local lookup=0
	if (distance == 0) and (chance[redeem_level] ~= nil) then lookup = chance[redeem_level][target_level+1] end
	if (distance == 1) and (adj_chance[redeem_level] ~= nil) then lookup = adj_chance[redeem_level][target_level+1] end
	if (lookup ~= nil) then hit_chance=lookup end
	return hit_chance
end

-- Tag [does_redeem_hit_target] determines success/fail of redeeming target
-- Requires cfg.redeem_level=, cfg.target_level=
-- Returns true/false in variable identified by cfg.to_variable
function wesnoth.wml_actions.does_redeem_hit_target(cfg)
	local redeem_level = cfg.redeem_level or wml.error("[does_redeem_hit_target]: requires redeem_level= ")
	local target_level = cfg.target_level or wml.error("[does_redeem_hit_target]: requires target_level= ")
	local to_variable = cfg.to_variable or wml.error("[does_redeem_hit_target]: requires to_variable= ")
	local debug = cfg.debug

	local hit_chance = redeem_hit_chance(redeem_level,target_level,0)
	local rand = math.random(0, 99)
	if (debug) then print(string.format("[does_redeem_hit_target]: rlel = %d, tlel = %d, hit = %d, rand = %d",
		redeem_level,target_level,hit_chance,rand))
	end
	local ret_val=false
	if rand < hit_chance then ret_val=true end
	wml.variables[to_variable]=ret_val
end

-- Tag [does_redeem_hit_adjacent_to_target] determines success/fail of redeeming unit adjacent to redeem target
-- Requires cfg.redeem_level=, cfg.target_level=
-- Returns true/false in variable identified by cfg.to_variable
function wesnoth.wml_actions.does_redeem_hit_adjacent_to_target(cfg)
	local redeem_level = cfg.redeem_level or wml.error("[does_redeem_hit_adjacent_to_target]: requires redeem_level= ")
	local target_level = cfg.target_level or wml.error("[does_redeem_hit_adjacent_to_target]: requires target_level= ")
	local to_variable = cfg.to_variable or wml.error("[does_redeem_hit_adjacent_to_target]: requires to_variable= ")
	local debug = cfg.debug

	local hit_chance = redeem_hit_chance(redeem_level,target_level,1)
	local rand = math.random(0, 99)
	if (debug) then print(string.format("[does_redeem_hit_adjacent_to_target]: rlel = %d, tlel = %d, hit = %d, rand = %d",
		redeem_level,target_level,hit_chance,rand))
	end
	local ret_val=false
	if rand < hit_chance then ret_val=true end
	wml.variables[to_variable]=ret_val
end
