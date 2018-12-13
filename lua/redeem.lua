--! #textdomain "wesnoth-loti"
--
-- Implementation of redeem upgrades menu (for Demigod units) and redeem-related utility functions.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

local known_upgrades = {
	spirit = {
		image = "attacks/spirit.png",
		label =_ "Spiritual transformation (a very powerful combat technique)",
		requires = { "absorb", "weapons" },

		-- Short names are used in "Provides: [upgrade1], [upgrade2], ..." lists.
		short_name =_ "Spiritual transformation"
	},
	particlestorm = {
		image = "attacks/particle-storm.png",
		label =_ "Particle Storm (a very powerful offensive spell)",
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
		label =_ "Firestorm (great damage and range)",
		requires = { "fireblast" },
		short_name =_ "Firestorm"
	},
	blizzard = {
		image = "attacks/blizzard.png",
		label =_ "Blizzard (slows a lot of units, moves them over the place)",
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
		label =_ "Fire Blast (quite powerful fiery attack)",
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
		label =_ "Arctic Blast (capable to slow a lot of units)",
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
		image = "icons/armor_leather.png",
		label =_ "Resist fire",
		requires = { "fireblast" }
	},
	resist_cold = {
		image = "icons/armor_leather.png",
		label =_ "Resist cold",
		requires = { "arcticblast" }
	},
	resist_arcane = {
		image = "icons/armor_leather.png",
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

-- Determine the list of redeem upgrades (e.g. "particlestorm")
-- that have already been picked by this Unit.
-- Returns the Lua table { firestorm = 1, lightning = 1, ... }.
function loti_util_list_existing_upgrades(unit)
	local temp_variable = "loti_util_temporary_unit"
	wesnoth.fire("store_unit", { variable = temp_variable, { "filter", { x = unit.x, y = unit.y } } })
	local advancements = helper.get_variable_array(temp_variable .. ".modifications.advancement")
	wesnoth.set_variable(temp_variable, nil)

	local found = {}
	for nr, advancement in pairs(advancements) do
		if known_upgrades[advancement.id] then
			found[advancement.id] = 1
		end
	end

	return found
end

-- Determine the list of redeem upgrades that require "upgrade_id" to be already picked.
-- Returns the Lua table { firestorm = 1, resist_fire = 1, ... }
function loti_util_list_upgrades_depending_on(upgrade_id)
	local found = {}
	for id, upgrade in pairs(known_upgrades) do
		for nr2, required_upgrade in pairs(upgrade.requires) do
			if required_upgrade == upgrade_id then
				-- Found a dependency.
				found[id] = 1
			end
		end
	end

	return found
end

-- Display the menu that chooses between redeem upgrades available to certain Unit.
-- Returns the selected upgrade (ID string), e.g. "particlestorm".
function redeem_menu(unit)
	-- Unit is optional, so that we can test UI of redeem_menu() separately from everything else.
	local existing_upgrades = {}
	if unit then
		existing_upgrades = loti_util_list_existing_upgrades(unit)
	end

	-- Menu items, as expected by wesnoth.show_menu()
	local menu_items = {};

	for id, upgrade in pairs(known_upgrades) do
		-- If haven't already picked
		if not existing_upgrades[id] then
			-- Check if all required upgrades have already been picked
			local dependencies_met = true
			for nr2, required_upgrade in pairs(upgrade.requires) do
				if not existing_upgrades[required_upgrade] then
					dependencies_met = false
					break
				end
			end

			if dependencies_met then
				local label = upgrade.label

				-- Inform the player which upgrades can become available after this one gets picked.

				local provides_labels = {}
				for provided_id in pairs(loti_util_list_upgrades_depending_on(id)) do
					if not existing_upgrades[provided_id] then
						local provided_upgrade = known_upgrades[provided_id]
						local extra_label = provided_upgrade.short_name
							or provided_upgrade.label

						table.insert(provides_labels, extra_label)
					end
				end

				if provides_labels[1] then
					label = label .. "\n" .. _("Provides:") .. " "

					-- Can't use table.concat(), because provides_labels has translated strings,
					-- and they are technically objects.
					for nr3,extra_label in pairs(provides_labels) do
						label = label .. extra_label
						if nr3 ~= #provides_labels then
							label = label .. ", "
						end
					end
				end

				table.insert(menu_items, {
					image = upgrade.image,
					details = label,

					-- The following field is not used by wesnoth.show_menu(),
					-- we use it to determine which upgrade has been selected.
					selected_upgrade = id
				})
			end
		end
	end

	-- Prepare the layout structure for wesnoth.show_dialog().
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
	local listbox = wml.tag.listbox { id = listbox_id,
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					wml.tag.toggle_panel { return_value = -1, listbox_template }
				}
			}
		}
	}

	-- 3) Top-level dialog, includes help message and listbox.
	local dialog = {
		wml.tag.tooltip { id = "tooltip_large" },
		wml.tag.helptip { id = "tooltip_large" },
		wml.tag.grid {
			-- Header (1 row containing a [label] with help)
			wml.tag.row {
				wml.tag.column {
					border = "bottom",
					border_size = 10,
					wml.tag.label {
						id = "redeem_menu_top_label"
					}
				}
			},

			-- Listbox, where each row shows ONE of the possible upgrades (e.g. "particlestorm")
			wml.tag.row {
				wml.tag.column { horizontal_grow = true, listbox }
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

	local function preshow()
		wesnoth.set_dialog_markup(true, "redeem_menu_top_label")
		wesnoth.set_dialog_value(
			"<span size='large' weight='bold'>Which new advancement path should our victorious unit get?</span>",
			"redeem_menu_top_label"
		)

		for index, menu_item in pairs(menu_items) do
			wesnoth.set_dialog_value(menu_item.image, listbox_id, index, "image")
			wesnoth.set_dialog_value(menu_item.details, listbox_id, index, "upgrade_name")
		end
	end

	local selected_index = 1
	local function postshow()
		selected_index = wesnoth.get_dialog_value(listbox_id)
	end

	wesnoth.show_dialog(dialog, preshow, postshow)
	return menu_items[selected_index].selected_upgrade
end

-- Tag [redeem_menu] allows to use redeem upgrade menu from WML.
-- Unit is identified by cfg.find_in parameter (e.g. find_in=secondary_unit).
-- Returns the selected upgrade (ID string), e.g. "particlestorm".
-- Result is placed into Wesnoth variable cfg.to_variable.
function wesnoth.wml_actions.show_redeem_menu(cfg)
	local to_variable = cfg.to_variable or "chose"

	local units = wesnoth.get_units(cfg)
	if #units < 1 then
		helper.wml_error("[show_redeem_menu]: no units found, may need find_in= parameter.")
	end

	local result = redeem_menu(units[1])
	wesnoth.set_variable(to_variable, result)
end
