--! #textdomain "wesnoth-loti"

local helper = wesnoth.require "lua/helper.lua"
local _ = wesnoth.textdomain "wesnoth-loti"

-- TODO: rename/regroup these functions to have well-structured names (as in items.lua),
-- don't place functions into loti[] table unless they are needed elsewhere.

loti.gem = {}

-- Machine-readable names of gems.
loti.gem.types = { "obsidians", "topazes", "opals", "pearls", "diamonds", "rubies", "emeralds", "amethysts", "sapphires", "black_pearls" }

-- Translated names of gems.
loti.gem.translated_names = { _"obsidians", _"topazes", _"opals", _"pearls", _"diamonds", _"rubies", _"emeralds", _"amethysts", _"sapphires", _"black pearls" }

loti.gem.get_counts = function()
	local gem_quantities = {}
	for _, gem in ipairs(loti.gem.types) do
		table.insert(gem_quantities, wesnoth.get_variable(gem) or 0)
	end
	return gem_quantities
end

loti.gem.set_counts = function(gem_quantities)
	for idx, gem in ipairs(loti.gem.types) do
		wesnoth.set_variable(gem, gem_quantities[idx])
	end
end

loti.gem.random = function()
	local distributions = helper.get_variable_array("gem_probabilities")
	local index = 1
	local chosen = "higher"
	while chosen == "higher" do
		chosen = helper.rand(distributions[index].distribution)
		index = index + 1
	end
	chosen = tonumber(chosen) - 520
	return chosen
end

loti.gem.show_transmuting_window = function(selected_recipe)
	local gem_quantities = loti.gem.get_counts()
	local transmutables = { { amount = 4, text = _"4 obsidians", picture = "items/obsidian.png" },
				{ amount = 2, text = _"2 topazes", picture = "items/topaz.png" },
				{ amount = 1, text = _"1 opal", picture = "items/opal.png" },
				{ amount = 1, text = _"1 pearl", picture = "items/pearl.png" } }

	-- Construct the WML of Transmuting dialog.
	-- Returns: WML table, as expected by the first parameter of wesnoth.show_dialog().
	local function get_dialog()
		-- One row of the listbox. [grid] widget.
		local listbox_template = wml.tag.grid {
			wml.tag.row {
				wml.tag.column {
					grow_factor = 0,
					horizontal_alignment = "left",
					wml.tag.image {
						id = "gui_gem_icon"
					}
				},
			   	wml.tag.column {
					grow_factor = 1,
					border = "all",
					border_size = 10,
					horizontal_grow = true,
					wml.tag.label {
						id = "gui_gem_name"
					}
				}
			}
		}

		local listbox = wml.tag.listbox {
			id = "gui_gem_chosen",
			wml.tag.list_definition {
				wml.tag.row {
					wml.tag.column {
						horizontal_grow = true,
						wml.tag.toggle_panel {
							listbox_template
						}
					}
				}
			}
		}

		local yesno_buttons = wml.tag.grid {
			wml.tag.row {
				wml.tag.column {
					wml.tag.button {
						id = "ok",
						label = _"Transmute"
					}
				},
				wml.tag.column {
					wml.tag.spacer {}
				},
				wml.tag.column {
					wml.tag.button {
						id = "cancel",
						label = _"Back"
					}
				}
			}
		}

		return {
			wml.tag.tooltip { id = "tooltip_large" },
			wml.tag.helptip { id = "tooltip_large" },
			wml.tag.grid {
				wml.tag.row {
					wml.tag.column {
						wml.tag.label {
							definition = "title",
							label = _"Transmuting"
						}
					}
				},
				wml.tag.row {
					wml.tag.column {
						border = "all",
						border_size = 10,
						wml.tag.label {
							label = _"You can transmute some number of gems\nto get a new random gem"
						}
					}
				},
				wml.tag.row {
					wml.tag.column {
						horizontal_grow = true,
						listbox
					}
				},
				wml.tag.row {
					wml.tag.column {
						border = "top",
						border_size = 10,
						horizontal_grow = true,
						yesno_buttons
					}
				}
			}
		}
	end

	local chosen = 1
	local can_transmute -- Set to true in gem_changed(), becomes false when non-existent gem is selected.

	while chosen ~= 0 do
		chosen = wesnoth.synchronize_choice(
			function()
				local picked = chosen

				local function gem_changed()
					picked = wesnoth.get_dialog_value("gui_gem_chosen")

					can_transmute = gem_quantities[picked] >= transmutables[picked].amount
					wesnoth.set_dialog_active(can_transmute, "ok")
				end

				local function preshow()
					for i = 1,#transmutables do
						wesnoth.set_dialog_value(transmutables[i].text, "gui_gem_chosen", i, "gui_gem_name")
						wesnoth.set_dialog_value(transmutables[i].picture, "gui_gem_chosen", i, "gui_gem_icon")
						if gem_quantities[i] < transmutables[i].amount then
							wesnoth.set_dialog_active(false, "gui_gem_chosen", i, "gui_gem_name")
						end
					end
					wesnoth.set_dialog_value(picked, "gui_gem_chosen")
					wesnoth.set_dialog_callback(gem_changed, "gui_gem_chosen")
					gem_changed()

					wesnoth.set_dialog_focus("gui_gem_chosen")
				end

				local returned = wesnoth.show_dialog(get_dialog(), preshow)
				
				if returned ~= -2 then
					return { picked = picked }
				end
				return { picked = 0 }
			end
		).picked

		if chosen == 0 or not can_transmute then
			break
		end

		gem_quantities[chosen] = gem_quantities[chosen] - transmutables[chosen].amount
		local obtained = loti.gem.random()
		gem_quantities[obtained] = gem_quantities[obtained] + 1
		wesnoth.wml_actions.object( loti.item.type[520 + obtained] ) 
		loti.gem.set_counts(gem_quantities)

		-- Update the gem counts in the Crafting dialog (which is currently open).
		if selected_recipe then
			loti.gem.show_crafting_report(selected_recipe)
		end
	end
end

-- Show a human-readable report in the Crafting dialog:
-- how many gems are currently available,
-- how many gems are needed to craft "item_number",
-- and the description of this item.
loti.gem.show_crafting_report = function(item_number)
	local item = loti.item.type[item_number]
	local available = loti.gem.get_counts()

	local report = ""
	for order, gem_name in ipairs(loti.gem.translated_names) do
		local needed = item[loti.gem.types[order]] or 0
		local text = gem_name .. ": " .. needed .. "/" .. tostring(available[order])

		if needed > available[order] then
			report = report .. "<span color='red'>" .. text .. "</span>\n"
		else
			report = report .. text .. "\n"
		end
	end

	wesnoth.set_dialog_value(report, "gui_gems_owned")
	wesnoth.set_dialog_value(loti.item.describe_item(item.number, item.sort), "gui_item_description")
end

-- Construct the WML of Crafting dialog.
-- Returns: WML table, as expected by the first parameter of wesnoth.show_dialog().
loti.gem.get_crafting_dialog = function()
	local basetype_listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.image {
					id = "gui_basetype_icon"
				}
			},
			wml.tag.column {
				border = "all",
				border_size = 10,
				wml.tag.label {
					id = "gui_basetype_name"
				}
			},
		}
	}

	local basetype_listbox = wml.tag.horizontal_listbox {
		id = "gui_basetype_chosen",
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					border = "right",
					border_size = 10,
					wml.tag.toggle_panel {
						tooltip = _"Choose between armour and weapon",
						basetype_listbox_template
					}
				}
			}
		},
		wml.tag.list_data {
			wml.tag.row {
				wml.tag.column {
					wml.tag.widget {
						id = "gui_basetype_icon",
						label = "icons/steel_armor.png"
					},
					wml.tag.widget {
						id = "gui_basetype_name",
						label = _"Armour"
					}
				}
			},
			wml.tag.row {
				wml.tag.column {
					wml.tag.widget {
						id = "gui_basetype_icon",
						label = "attacks/sword-human.png"
					},
					wml.tag.widget {
						id = "gui_basetype_name",
						label = _"Weapon"
					}
				}
			}
		}
	}

	local type_listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				grow_factor = 0,
				wml.tag.image {
					id = "gui_type_icon"
				}
			},
			wml.tag.column {
				border = "all",
				border_size = 10,
				wml.tag.label {
					id = "gui_type_name",
					characters_per_line = 30
				}
			}
		}
	}

	local type_listbox = wml.tag.horizontal_listbox {
		id = "gui_type_chosen",
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					wml.tag.toggle_panel {
						tooltip = _"Choose item type",
						type_listbox_template
					}
				}
			}
		}
	}

	local recipe_listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				grow_factor = 0,
				vertical_alignment = "center",
				wml.tag.image {
					id = "gui_recipe_icon"
				}
			},
			wml.tag.column {
				grow_factor = 1,
				horizontal_grow = true,
				border = "all",
				border_size = 5,
				wml.tag.label {
					id = "gui_recipe_name"
				}
			}
		}
	}

	local recipe_listbox = wml.tag.listbox {
		id = "gui_recipe_chosen",
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					vertical_alignment = "top",
					wml.tag.toggle_panel {
						tooltip = _"Choose crafting recipe",
						recipe_listbox_template
					}
				}
			}
		}
	}

	-- A grid that includes (1) recipe listbox, (2) gem counts, (3) information about selected item.
	local main_widget = wml.tag.grid {
		wml.tag.row {
			-- List of recipes.
			wml.tag.column {
				grow_factor = 0,
				horizontal_alignment = "left",
				vertical_grow = true, -- For Tutorial, where there is only 1 recipe
				recipe_listbox
			},
			-- Statistics on gems: needed/available
			wml.tag.column {
				grow_factor = 0,
				horizontal_alignment = "left",
				vertical_alignment = "top",
				border = "left,right",
				border_size = 10,
				wml.tag.label {
					id = "gui_gems_owned",
					use_markup = true
				}
			},
			-- Description of selected item.
			wml.tag.column {
				grow_factor = 1,
				horizontal_grow = true,
				vertical_alignment = "top",
				wml.tag.scroll_label {
					id = "gui_item_description",
					definition = "description_small",
					-- definition = "wml_message", -- larger version
					use_markup = true
				}
			}

		}
	}

	local yesno_buttons =  wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.button {
					id = "ok",
					label = _"Craft"
				}
			},
			wml.tag.spacer {},
			wml.tag.column {
				wml.tag.button {
					id = "cancel",
					label = _"Back"
				}
			},
			wml.tag.spacer {},
			wml.tag.column {
				wml.tag.button {
					id = "transmute",
					label = _"Transmute gems"
				}
			}
		}
	}

	return {
		wml.tag.tooltip { id = "tooltip_large" },
		wml.tag.helptip { id = "tooltip_large" },
		maximum_width = 1000,
		wml.tag.grid {
			wml.tag.row {
				wml.tag.column {
					border = "bottom",
					border_size = 10,
					wml.tag.label {
						definition = "title",
						label = _"Crafting"
					}
				}
			},
			wml.tag.row {
				wml.tag.column {
					border = "bottom",
					border_size = 5,
					basetype_listbox
				}
			},
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					main_widget
				}
			},
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					border = "top",
					border_size = 10,
					wml.tag.label {
						label = _"Choose type of item:",
						text_alignment = "left"
					}
				}
			},
			wml.tag.row {
				wml.tag.column {
					border = "top",
					border_size = 5,
					type_listbox
				}
			},
			wml.tag.row {
				wml.tag.column {
					border = "top",
					border_size = 10,
					horizontal_grow = true,
					yesno_buttons
				}
			}
		}
	}
end

loti.gem.show_crafting_window = function(x, y)
	local gem_quantities = loti.gem.get_counts()

	local chose = wesnoth.synchronize_choice(
		function()
			local base_type = 1
			local sort_chosen = 1
			local recipe_chosen = 541
			local crafting_allowed -- Set to true or false in check_validity()

			local selectable_sorts = {}
			local selectable_recipes = {}

			local function can_craft(item_type)
				local item = loti.item.type[item_type]
				for i = 1,#loti.gem.types do
					local got = item[loti.gem.types[i]]
					if got and got > gem_quantities[i] then
						return false
					end
				end
				return true
			end

			local function check_validity()
				local function is_valid()
					if not sort_chosen then
						return false
					end

					recipe_chosen = selectable_recipes[wesnoth.get_dialog_value("gui_recipe_chosen")]
					if not recipe_chosen then
						return false
					end

					if not can_craft(recipe_chosen) then
						return false
					end

					return true
				end

				crafting_allowed = is_valid()
				wesnoth.set_dialog_active(crafting_allowed, "ok")
			end

			local function preshow()
				local function selected_type_changed()
					sort_chosen = selectable_sorts[wesnoth.get_dialog_value("gui_type_chosen")]
					check_validity()
				end

				local function selected_recipe_changed()
					recipe_chosen = selectable_recipes[wesnoth.get_dialog_value("gui_recipe_chosen")]
					loti.gem.show_crafting_report(recipe_chosen)
					check_validity()
				end

				local function basetype_changed()
					selectable_sorts = {}
					selectable_recipes = {}

					base_type = wesnoth.get_dialog_value("gui_basetype_chosen")
					local order = 1
					local function populate_item(text, image, sort)
						wesnoth.set_dialog_value(text, "gui_type_chosen", order, "gui_type_name")
						wesnoth.set_dialog_value(image, "gui_type_chosen", order, "gui_type_icon")
						order = order + 1
						table.insert(selectable_sorts, sort)
					end

					-- Clear the type listbox
					wesnoth.remove_dialog_item(1, 0, "gui_type_chosen")

					local word_from, word_to
					if base_type == 1 then
						-- Armour
						local resistance_note = _"1/3 of promised resistances"
						populate_item(_"Armour (chest)", "icons/cuirass_muscled.png", "armour")
						populate_item(_"Helm\n" .. resistance_note, "icons/helmet_great2.png", "helm")
						populate_item(_"Boots\n" .. resistance_note, "icons/greaves.png", "boots")
						populate_item(_"Gauntlets\n" .. resistance_note, "icons/gauntlets.png", "gauntlets")

						word_from = 531
						word_to = 560
					else
						-- Weapon
						populate_item(_"Sword", "attacks/sword-steel.png", "sword")
						populate_item(_"Bow", "attacks/bow-short-reinforced.png", "bow")
						populate_item(_"Axe", "attacks/battleaxe.png", "axe")
						populate_item(_"Staff", "attacks/staff-magic.png", "staff")
						populate_item(_"Mace (or hammer, club, morning star, scourge, flail, ...)", "attacks/mace.png", "mace")
						populate_item(_"Crossbow (or slurbow)", "attacks/crossbow-iron.png", "xbow")
						populate_item(_"Dagger", "attacks/dagger-curved.png", "dagger")
						populate_item(_"Knife (throwing)", "attacks/dagger-thrown-human.png", "knife")
						populate_item(_"Spear (or javelin, lance, pike, trident)", "attacks/spear.png", "spear")
						populate_item(_"Polearm (halberd, scythe, ...)", "attacks/halberd.png", "polearm")
						populate_item(_"Sling (or bolas or net)", "attacks/sling.png", "sling")
						populate_item(_"Thunderstick (or dragonstaff)", "attacks/thunderstick.png", "thunderstick")
						populate_item(_"Metal claws", "attacks/claws.png", "claws")
						populate_item(_"Otherworldly essence (for touch attacks, baneblade, ...)", "attacks/touch-faerie.png", "essence")

						word_from = 561
						word_to = 600
					end

					-- Clear the recipe listbox
					wesnoth.remove_dialog_item(1, 0, "gui_recipe_chosen")

					order = 1
					for _, i in ipairs(loti.item.type.numbers_between(word_from, word_to + 1)) do
						local item = loti.item.type[i]
						wesnoth.set_dialog_value(item.name, "gui_recipe_chosen", order, "gui_recipe_name")
						if can_craft(i) then
							wesnoth.set_dialog_value("../../../images/icons/unit-groups/era_default_knalgan_alliance_30-pressed.png", "gui_recipe_chosen", order, "gui_recipe_icon")
							wesnoth.set_dialog_active(true, "gui_recipe_chosen", order, "gui_recipe_name")
						else
							wesnoth.set_dialog_value("../../../images/icons/unit-groups/cross_30.png", "gui_recipe_chosen", order, "gui_recipe_icon")
							wesnoth.set_dialog_active(false, "gui_recipe_chosen", order, "gui_recipe_name")
						end
						selectable_recipes[order] = i
						order = order + 1
					end

					local position = 1
					for i = 1,#selectable_sorts do
						if selectable_sorts[i] == sort_chosen then
							position = i
							break
						end
					end
					wesnoth.set_dialog_value(position, "gui_type_chosen")

					position = 1
					for i = 1,#selectable_recipes do
						if selectable_recipes[i] == sort_chosen then
							position = i
							break
						end
					end
					wesnoth.set_dialog_value(position, "gui_recipe_chosen")

					selected_type_changed()
					selected_recipe_changed()
					check_validity()

					wesnoth.set_dialog_focus("gui_recipe_chosen")
				end

				wesnoth.set_dialog_callback(basetype_changed, "gui_basetype_chosen")
				wesnoth.set_dialog_callback(selected_type_changed, "gui_type_chosen")
				wesnoth.set_dialog_callback(selected_recipe_changed, "gui_recipe_chosen")
				wesnoth.set_dialog_callback(function()
					-- Pass the number of selected recipe to Transmuting dialog,
					-- so that it could update the report on needed/available gem counts
					-- after each transmutation.
					loti.gem.show_transmuting_window(recipe_chosen)
				end, "transmute")

				basetype_changed()
			end

			local function postshow()
				check_validity()
			end

			local returned = -1
			while returned == -1 do
				returned = wesnoth.show_dialog(loti.gem.get_crafting_dialog(), preshow, postshow)
				if returned == -1 and crafting_allowed then
					if wesnoth.confirm(_"Are you sure you want to craft this item?") then
						returned = 1
					end
				end
			end
					
			if returned ~= -2 then
				return { sort = sort_chosen, recipe = recipe_chosen }
			else
				return { }
			end
		end
	)
	if chose.sort then
		loti.item.on_the_ground.add(chose.recipe, x, y, chose.sort)
		for i = 1,#loti.gem.types do
			gem_quantities[i] = gem_quantities[i] - loti.item.type[chose.recipe][loti.gem.types[i]]
		end
		loti.gem.set_counts(gem_quantities)
		wesnoth.wml_actions.fire_event{ name="item_pick", { "primary_unit", { x=x, y=y } } }
	end
end
