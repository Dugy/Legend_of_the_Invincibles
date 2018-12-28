--! #textdomain "wesnoth-loti"

local helper = wesnoth.require "lua/helper.lua"
local T = helper.set_wml_tag_metatable {}
local _ = wesnoth.textdomain "wesnoth-loti"

local gem_types = { "obsidians", "topazes", "opals", "pearls", "diamonds", "rubies", "emeralds", "amethysts", "sapphires", "black_pearls" }

loti.item.get_gem_counts = function()
	local gem_quantities = {}
	for i = 1,#gem_types do
		local got = wesnoth.get_variable(gem_types[i])
		if got then
			table.insert(gem_quantities, got)
		else
			table.insert(gem_quantities, 0)
		end
	end
	return gem_quantities
end

loti.item.set_gem_counts = function(gem_quantities)
	for i = 1,#gem_types do
		wesnoth.set_variable(gem_types[i], gem_quantities[i])
	end
end

loti.item.generate_random_gem = function()
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

loti.item.transmuting_window = function()
	local gem_quantities = loti.item.get_gem_counts()
	local transmutables = { { amount = 4, text = _"4 obsidians", picture = "items/obsidian.png" },
				{ amount = 2, text = _"2 topazes", picture = "items/topaz.png" },
				{ amount = 1, text = _"1 opal", picture = "items/opal.png" },
				{ amount = 1, text = _"1 pearl", picture = "items/pearl.png" } }
	local chosen = 1
	while chosen ~= 0 do
		chosen = wesnoth.synchronize_choice(
			function()
				local picked = chosen
				local dialog = { T.tooltip { id = "tooltip_large" }, T.helptip { id = "tooltip_large" }, maximum_width = 800, maximum_height = 600,
					T.grid {
						T.row { T.column { T.label { id = "title" , definition = "title" , label = _"Transmuting"} }} ,
						T.row { T.column {
							T.label { id="gems_owned" , label="You can transmute some number of gems to get a new random gem"}
						}},
						T.row { T.column {
							T.listbox { id = "gui_gem_chosen",
								T.list_definition { T.row { T.column { horizontal_grow = true,
									T.toggle_panel { tooltip="Choose item type", T.grid { T.row {
										T.column { horizontal_alignment = "left", T.image { id = "gui_gem_icon", horizontal_grow = false } },
			   							T.column { horizontal_alignment = "left", T.label { id = "gui_gem_name", horizontal_grow = true } }
									}}}
								}}}
							}
						}},
						T.row { T.column { T.grid { T.row {
							T.column { T.button { id = "ok", label = "Transmute" } },
							T.column { T.button { id = "cancel", label = "Back" } }
						}}}}
					}
				}

				local function gem_changed()
					picked = wesnoth.get_dialog_value("gui_gem_chosen")
					if gem_quantities[picked] < transmutables[picked].amount then
						wesnoth.set_dialog_active(false, "ok")
					else
						wesnoth.set_dialog_active(true, "ok")
					end
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
				end

				local returned = wesnoth.show_dialog(dialog, preshow)
				
				if returned ~= -2 then
					return { picked = picked }
				end
				return { picked = 0 }
			end
		).picked
		if chosen == 0 then
			break
		end
		gem_quantities[chosen] = gem_quantities[chosen] - transmutables[chosen].amount
		local obtained = loti.item.generate_random_gem()
		gem_quantities[obtained] = gem_quantities[obtained] + 1
		wesnoth.wml_actions.object( loti.item.type[520 + obtained] ) 
		loti.item.set_gem_counts(gem_quantities)
	end
end

loti.item.crafting_window = function(x, y)
	local gem_quantities = loti.item.get_gem_counts()
	local chose = wesnoth.synchronize_choice(
		function()
			local base_type = 1
			local sort_chosen = 1
			local recipe_chosen = 541
			local dialog = { T.tooltip { id = "tooltip_large" }, T.helptip { id = "tooltip_large" }, maximum_width = 800, maximum_height = 600,
				T.grid {
					T.row { T.column { T.label { id = "title" , definition = "title" , label = _"Crafting"} }} ,
					T.row { T.column { T.grid { T.row {
						T.column {
							T.grid {
								T.row { T.column { horizontal_grow = true,
									T.listbox { id = "gui_basetype_chosen", vertical_scrollbar_mode=false,
										T.list_definition { T.row { T.column { horizontal_grow = true,
											T.toggle_panel { tooltip="Choose between armour and weapon", T.grid { T.row {
												T.column { horizontal_alignment = "left", T.image { id = "gui_basetype_icon", horizontal_grow = false } },
					   							T.column { horizontal_alignment = "left", T.label { id = "gui_basetype_name", horizontal_grow = true } }
											}}}
										}}}
									}
								}},
								T.row { T.column {
									T.listbox { id = "gui_type_chosen",
										T.list_definition { T.row { T.column { horizontal_grow = true,
											T.toggle_panel { tooltip="Choose item type", T.grid { T.row {
												T.column { horizontal_alignment = "left", T.image { id = "gui_type_icon", horizontal_grow = false } },
					   							T.column { horizontal_alignment = "left", T.label { id = "gui_type_name", horizontal_grow = true } }
											}}}
										}}}
									}
								}}
							}
						},
						T.column { horizontal_grow = true,
							T.listbox { id = "gui_recipe_chosen", vertical_scrollbar_mode=false,
								T.list_definition { T.row { T.column { horizontal_grow = true,
									T.toggle_panel { tooltip="Choose crafting recipe", T.grid { T.row {
										T.column { horizontal_alignment = "left", T.image { id = "gui_recipe_icon", horizontal_grow = false } },
			   							T.column { horizontal_alignment = "left", T.label { id = "gui_recipe_name", minimum_width = 200 } }
									}}}
								}}}
							}
						},
						T.column {
							T.grid{ 
								T.row { T.column {
									T.label { id="gui_gems_owned" , label=""}
								}},
								T.row { T.column {
									T.label { id="gui_item_description" , label=""}
								}}
							}
						}
					}}}},
					T.row { T.column { T.grid { T.row {
						T.column { T.button { id = "ok", label = "Craft" } },
						T.column { T.button { id = "cancel", label = "Back" } },
						T.column { T.button { id = "transmute", label = "Transmute gems" } }
					}}}}
				}
			}
			local selectable_sorts = {}
			local selectable_recipes = {}

			local function preshow()
				local function can_craft(item_type)
					local item = loti.item.type[item_type]
					if not item then
						return false
					end
					for i = 1,#gem_types do
						local got = item[gem_types[i]]
						if got and got > gem_quantities[i] then
							return false
						end
					end
					return true
				end

				local function check_validity()
					if not sort_chosen then
						wesnoth.set_dialog_active(false, "ok")
						return
					end
					recipe_chosen = selectable_recipes[wesnoth.get_dialog_value("gui_recipe_chosen")]
					if not recipe_chosen then
						wesnoth.set_dialog_active(false, "ok")
						return
					end
					if not can_craft(recipe_chosen) then
						wesnoth.set_dialog_active(false, "ok")
						return
					end
					wesnoth.set_dialog_active(true, "ok")
				end

				local function selected_type_changed()
					sort_chosen = selectable_sorts[wesnoth.get_dialog_value("gui_type_chosen")]
					check_validity()
				end

				local function selected_recipe_changed()
					recipe_chosen = selectable_recipes[wesnoth.get_dialog_value("gui_recipe_chosen")]
					local item = loti.item.type[recipe_chosen]
					if item then
						local gems_text = ""
						local order = 1
						local function add_gem(name)
							local needed = item[gem_types[order]] or 0
							local text = name .. ": " .. needed .. "/" .. tostring(gem_quantities[order])
							if needed > gem_quantities[order] then
								gems_text = gems_text .. "<span color='red'>" .. text .. "</span>\n"
							else
								gems_text = gems_text .. text .. "\n"
							end
							order = order + 1
						end
						add_gem(_"obsidians")
						add_gem(_"topazes")
						add_gem(_"opals")
						add_gem(_"pearls")
						add_gem(_"diamonds")
						add_gem(_"rubies")
						add_gem(_"emeralds")
						add_gem(_"amethysts")
						add_gem(_"sapphires")
						add_gem(_"black pearls")
						wesnoth.set_dialog_value(gems_text, "gui_gems_owned")

						wesnoth.set_dialog_value(item.description, "gui_item_description")
					end
					check_validity()
				end

				local function basetype_changed()
					for i = 1,#selectable_sorts do
						wesnoth.set_dialog_value("", "gui_type_chosen", i, "gui_type_name")
						wesnoth.set_dialog_value("", "gui_type_chosen", i, "gui_type_icon")
					end
					for i = 1,#selectable_recipes do
						wesnoth.set_dialog_value("", "gui_recipe_chosen", i, "gui_recipe_name")
						wesnoth.set_dialog_value("", "gui_recipe_chosen", i, "gui_recipe_icon")
					end
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
					local word_from, word_to
					if base_type == 1 then
						-- Armour
						populate_item(_"Armour", "icons/cuirass_muscled.png", "armour")
						populate_item(_"Helm (only a third of the resistance promised!)", "icons/helmet_great2.png", "helm")
						populate_item(_"Boots (only a third of the resistance promised!)", "icons/greaves.png", "boots")
						populate_item(_"Gauntlets (only a third of the resistance promised!)", "icons/gauntlets.png", "gauntlets")

						word_from = 531
						word_to = 560
					else
						-- Weapon
						populate_item(_"Sword", "attacks/sword-steel.png", "sword")
						populate_item(_"Bow", "attacks/bow-short-reinforced.png", "bow")
						populate_item(_"Axe", "attacks/battleaxe.png", "axe")
						populate_item(_"Staff", "attacks/staff-magic.png", "staff")
						populate_item(_"Mace (or hammer, club, mornig star, scourge, flail, ...)", "attacks/mace.png", "mace")
						populate_item(_"Crossbow (or slurbow)", "attacks/crossbow-iron.png", "xbow")
						populate_item(_"Dagger", "attacks/dagger-curved.png", "dagger")
						populate_item(_"Knife (throwing)", "attacks/dagger-thrown-human.png", "knife")
						populate_item(_"Spear (or javelin, lance, pike, trident)", "attacks/spear.png", "spear")
						populate_item(_"Polearm (halberd, scythe, ...)", "attacks/halberd.png", "halberd")
						populate_item(_"Sling (or bolas or net)", "attacks/sling.png", "sling")
						populate_item(_"Thunderstick (or dragonstaff)", "attacks/thunderstick.png", "thunderstick")
						populate_item(_"Metal claws", "attacks/claws.png", "claws")
						populate_item(_"Otherworldly essence (for touch attacks, baneblade, ...)", "attacks/touch-faerie.png", "essence")

						word_from = 561
						word_to = 600
					end

					order = 1
					for i = word_from, word_to do
						local item = loti.item.type[i]
						if item then
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
				end

				wesnoth.set_dialog_markup(true, "gui_gems_owned")
				wesnoth.set_dialog_markup(true, "gui_item_description")
				wesnoth.set_dialog_value(_"Armour", "gui_basetype_chosen", 1, "gui_basetype_name")
				wesnoth.set_dialog_value("icons/steel_armor.png", "gui_basetype_chosen", 1, "gui_basetype_icon")
				wesnoth.set_dialog_value(_"Weapon", "gui_basetype_chosen", 2, "gui_basetype_name")
				wesnoth.set_dialog_value("attacks/sword-human.png", "gui_basetype_chosen", 2, "gui_basetype_icon")
				wesnoth.set_dialog_value(base_type, "gui_basetype_chosen")
		
				wesnoth.set_dialog_callback(basetype_changed, "gui_basetype_chosen")
				wesnoth.set_dialog_callback(selected_type_changed, "gui_type_chosen")
				wesnoth.set_dialog_callback(selected_recipe_changed, "gui_recipe_chosen")
				wesnoth.set_dialog_callback(loti.item.transmuting_window, "transmute")

				basetype_changed()
			end

			local returned = -1
			while returned == -1 do
				returned = wesnoth.show_dialog(dialog, preshow)
				if returned == -1 then
					if wesnoth.confirm(_"Are you sure to want to craft this item?") then
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
		for i = 1,#gem_types do
			gem_quantities[i] = gem_quantities[i] - loti.item.type[chose.recipe][gem_types[i]]
		end
		loti.item.set_gem_counts(gem_quantities)
		wesnoth.wml_actions.fire_event{ name="item_pick", { "primary_unit", { x=x, y=y } } }
	end
end
