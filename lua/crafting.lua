--! #textdomain "wesnoth-loti"

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
		table.insert(gem_quantities, wml.variables[gem] or 0)
	end
	return gem_quantities
end

loti.gem.set_counts = function(gem_quantities)
	for idx, gem in ipairs(loti.gem.types) do
		wml.variables[gem] = gem_quantities[idx]
	end
end

loti.gem.random = function()
	return loti.item.on_the_ground.generate("gem") - 520
end

-- Display popup that shows name/icon of this gem to player.
loti.gem.show_gem_info_popup = function(gem)
	local item = loti.item.type[520 + gem]
	gui.show_popup(item.name, item.description, item.image)
end

-- negative count is allowed
loti.gem.add = function(gem, count)
	local gems = loti.gem.get_counts()
	gems[gem] = gems[gem] + count
	loti.gem.set_counts(gems)
end

loti.gem.show_transmuting_window = function(crafting_dialog, selected_recipe, selected_sort)
	local gem_quantities = loti.gem.get_counts()
	local transmutables = { { amount = 4, text = _"4 obsidians", picture = "items/obsidian.png" },
				{ amount = 2, text = _"2 topazes", picture = "items/topaz.png" },
				{ amount = 1, text = _"1 opal", picture = "items/opal.png" },
				{ amount = 1, text = _"1 pearl", picture = "items/pearl.png" } }

	-- Construct the WML of Transmuting dialog.
	-- Returns: WML table, as expected by the first parameter of gui.show_dialog().
	local function get_dialog_definition()
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
			horizontal_placement = "left",
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
		chosen = wesnoth.sync.evaluate_single(
			function()
				local picked = chosen

				local function gem_changed(dialog)
					picked = dialog.gui_gem_chosen.selected_index

					can_transmute = gem_quantities[picked] >= transmutables[picked].amount
					dialog.ok.enabled = can_transmute
				end

				local function preshow(dialog)
					for i = 1,#transmutables do
						dialog.gui_gem_chosen[i].gui_gem_name.label = transmutables[i].text
						dialog.gui_gem_chosen[i].gui_gem_icon.label = transmutables[i].picture
						if gem_quantities[i] < transmutables[i].amount then
							dialog.gui_gem_chosen[i].gui_gem_name.enabled = false
						end
					end
					dialog.gui_gem_chosen.selected_index = picked
					dialog.gui_gem_chosen.on_modified = function() gem_changed(dialog) end
					gem_changed(dialog)

					dialog.gui_gem_chosen:focus()
				end

				local returned = gui.show_dialog(get_dialog_definition(), preshow)

				if returned ~= -2 then
					return { picked = picked }
				end
				return { picked = 0 }
			end
		).picked

		if chosen == 0 or not can_transmute then
			break
		end

		local obtained = loti.gem.random()
		crafting.mpsafety:queue({
			command = "gem_transmute",
			old_gem = chosen,
			old_count = transmutables[chosen].amount,
			new_gem = obtained,
			new_count = 1
		})
		gem_quantities = loti.gem.get_counts()
		wesnoth.wml_actions.object( loti.item.type[520 + obtained] )

		-- Update the gem counts in the Crafting dialog (which is currently open).
		if selected_recipe then
			loti.gem.show_crafting_report(crafting_dialog, selected_recipe, selected_sort)
		end
	end
end

-- Show a human-readable report in the Crafting dialog:
-- how many gems are currently available,
-- how many gems are needed to craft "item_number",
-- and the description of this item.
loti.gem.show_crafting_report = function(dialog, item_number, crafted_sort)
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

	dialog.gui_gems_owned.label = report
	dialog.gui_item_description.label = loti.item.describe_item(item.number, crafted_sort or item.sort)
end

-- Construct the WML of Crafting dialog.
-- Returns: WML table, as expected by the first parameter of gui.show_dialog().
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

	local basetype_listbox = wml.tag.listbox {
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
				vertical_alignment = "center",
				wml.tag.image {
					id = "gui_type_icon"
				}
			},
			wml.tag.column {
				grow_factor = 1,
				horizontal_grow = true,
				border = "all",
				border_size = 5,
				wml.tag.label {
					id = "gui_type_name",
					characters_per_line = 30
				}
			}
		}
	}

	local type_listbox = wml.tag.listbox {
		id = "gui_type_chosen",
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					vertical_alignment = "top",
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
			-- The main stuff
			wml.tag.column {
				grow_factor = 0,
				horizontal_alignment = "left",
				vertical_grow = true,
				T.grid {
					T.row {
						T.column {
							border = "bottom",
							border_size = 5,
							basetype_listbox
						}
					},
					T.row {
						-- Statistics on gems: needed/available
						T.column {
							grow_factor = 0,
							horizontal_alignment = "left",
							vertical_alignment = "top",
							border = "left,right",
							border_size = 10,
							wml.tag.label {
								id = "gui_gems_owned",
								use_markup = true
							}
						}
					},
					T.row {
						-- Description of selected item
						T.column {
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
			},
			-- List of recipes
			wml.tag.column {
				grow_factor = 0,
				horizontal_alignment = "left",
				vertical_grow = true, -- For Tutorial, where there is only 1 recipe
				recipe_listbox
			},
			-- List of item types
			wml.tag.column {
				border = "top",
				border_size = 5,
				type_listbox
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
		maximum_height = 800,
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
					horizontal_grow = true,
					main_widget
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

	local chose = wesnoth.sync.evaluate_single(
		function()
			local base_type, sort_chosen, recipe_chosen
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

			local function check_validity(dialog)
				local function is_valid()
					if not sort_chosen then
						return false
					end

					recipe_chosen = selectable_recipes[dialog.gui_recipe_chosen.selected_index]
					if not recipe_chosen then
						return false
					end

					if not can_craft(recipe_chosen) then
						return false
					end

					return true
				end

				crafting_allowed = is_valid()
				dialog.ok.enabled = crafting_allowed
			end

			local function preshow(dialog)
				local function type_or_recipe_selected()
					recipe_chosen = selectable_recipes[dialog.gui_recipe_chosen.selected_index]
					sort_chosen = selectable_sorts[dialog.gui_type_chosen.selected_index]

					loti.gem.show_crafting_report(dialog, recipe_chosen, sort_chosen)
					check_validity(dialog)
				end

				local function basetype_changed()
					selectable_sorts = {}
					selectable_recipes = {}

					base_type = dialog.gui_basetype_chosen.selected_index
					local order = 1
					local function populate_item(text, image, sort)
						dialog.gui_type_chosen[order].gui_type_name.label = text
						dialog.gui_type_chosen[order].gui_type_icon.label = image

						order = order + 1
						table.insert(selectable_sorts, sort)
					end

					-- Clear the type listbox
					dialog.gui_type_chosen:remove_items_at(1, 0)

					local word_from, word_to
					if base_type == 1 then
						-- Armour
						populate_item(_"Armour (chest)", "icons/cuirass_muscled.png", "armour")
						populate_item(_"Helm", "icons/helmet_great2.png", "helm")
						populate_item(_"Boots", "icons/greaves.png", "boots")
						populate_item(_"Gauntlets", "icons/gauntlets.png", "gauntlets")

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
					dialog.gui_recipe_chosen:remove_items_at(1, 0)

					order = 1
					for _, i in ipairs(loti.item.type.numbers_between(word_from, word_to + 1)) do
						local item = loti.item.type[i]
						dialog.gui_recipe_chosen[order].gui_recipe_name.label = item.name
						if can_craft(i) then
							dialog.gui_recipe_chosen[order].gui_recipe_icon.label = "../../../images/icons/unit-groups/era_default_knalgan_alliance_30-pressed.png"
							dialog.gui_recipe_chosen[order].gui_recipe_name.enabled = true
						else
							dialog.gui_recipe_chosen[order].gui_recipe_icon.label = "../../../images/icons/unit-groups/cross_30.png"
							dialog.gui_recipe_chosen[order].gui_recipe_name.enabled = false
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
					dialog.gui_type_chosen.selected_index = position

					position = 1
					for i = 1,#selectable_recipes do
						if selectable_recipes[i] == sort_chosen then
							position = i
							break
						end
					end
					dialog.gui_recipe_chosen.selected_index = position

					type_or_recipe_selected()
					check_validity(dialog)

					dialog.gui_recipe_chosen:focus()
				end

				dialog.gui_basetype_chosen.on_modified = basetype_changed
				dialog.gui_type_chosen.on_modified = type_or_recipe_selected
				dialog.gui_recipe_chosen.on_modified = type_or_recipe_selected
				dialog.transmute.on_button_click = function()
					-- Pass the number of selected recipe to Transmuting dialog,
					-- so that it could update the report on needed/available gem counts
					-- after each transmutation.
					loti.gem.show_transmuting_window(dialog, recipe_chosen, sort_chosen)
				end

				basetype_changed()
			end

			local function postshow(dialog)
				check_validity(dialog)
			end

			local returned = -1
			while returned == -1 do
				returned = gui.show_dialog(loti.gem.get_crafting_dialog(), preshow, postshow)
				if returned == -1 and crafting_allowed then
					if gui.confirm(_"Are you sure you want to craft this item?") then
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
		crafting.mpsafety:queue({
			command = "create_on_ground",
			number = chose.recipe,
			sort = chose.sort,
			x = x,
			y = y
		})
		for i = 1,#loti.gem.types do
			if loti.item.type[chose.recipe][loti.gem.types[i]] > 0 then
				crafting.mpsafety:queue({
					command = "gem_remove",
					gem = i,
					count = loti.item.type[chose.recipe][loti.gem.types[i]]
				})
			end
		end
		gem_quantities = loti.gem.get_counts()
		wesnoth.wml_actions.fire_event{ name="item_pick_inventory", { "primary_unit", { x=x, y=y } } }
	end
end
