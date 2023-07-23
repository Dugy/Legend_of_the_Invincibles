--! #textdomain "wesnoth-loti"
local _ = wesnoth.textdomain "wesnoth-loti"

local function confirm_purchase(item,trader)
	-- Prepare the layout structure for gui.show_dialog().
	local listbox_id = "trader_menu_confirm"

	-- 1) listbox_template: shows one possible choice (yes, no)
	local listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				grow_factor = 1,
				border = "all",
				border_size = 0,
				horizontal_alignment = "center",
				wml.tag.label {
					id = "option"
				}
			}
		}
	}

	-- 2) listbox_widget: shows a list of all options
	local listboxDefinition = wml.tag.listbox {
		id = listbox_id,
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
	local confirm_queries = { _"A bargain at twice the price.  We good?", _"Makes a great gift.  Wrap it up to go?", _"You gonna buy that or what?",
		_"I close in 5 minutes.  We got a deal or what?", _"Look at it.  Do you really want it?" }
	local confirm_query=confirm_queries[math.random(1,#confirm_queries)]
	if(string.sub(item.image,7,10) == "book") then confirm_query = _"Hey, this ain't a library!  You wanna take that home to read?" end
	local dialogDefinition = {
		wml.tag.tooltip { id = "tooltip_large" },
		wml.tag.helptip { id = "tooltip_large" },
		wml.tag.grid {
			wml.tag.row {
				wml.tag.column {  -- column 1, item
					border = "all",

					border_size=50,
					wml.tag.grid {
						wml.tag.row { -- item image and name
							wml.tag.column {
								wml.tag.grid {
									wml.tag.row {
										wml.tag.column {
											border = "bottom",
											border_size=10,
											wml.tag.image {
												label = item.image
											}
										},
										wml.tag.column {
											wml.tag.label {
												label = item.name .. "  (" .. item.sort .. ")"
											}
										},
									}
								}
							}
						},
						wml.tag.row { -- item description
							wml.tag.column {
								wml.tag.label {
									use_markup = true,
									label = item.description
								}
							}
						}
					}
				},
				wml.tag.column {  -- column2, let's do business
						wml.tag.grid {
							wml.tag.row { -- the trader
								wml.tag.column {
									wml.tag.grid {
										wml.tag.row {
											wml.tag.column {
												wml.tag.label {
													border = "bottom",
													border_size=30,
													use_markup = true,
													label = "<span size='large' color='wheat' weight='bold'>".. trader .."</span>"
												}
											},
											wml.tag.column {
												wml.tag.image {
													label = "merchant.png"
												}
											}
										}
									}
								}
							},
							wml.tag.row {  -- you want it?
								wml.tag.column {
										wml.tag.label {
										use_markup = true,
										label = "<span color='wheat' weight='bold'>".. confirm_query .."</span>"
									}
								}
							},
							wml.tag.row {  -- blank space
								wml.tag.column {
									wml.tag.label {
										border = "all",
										border_size = 10,
										label = "   "
									}
								}
							},
							wml.tag.row {  -- the options (yes, no), in a listbox
								wml.tag.column { horizontal_grow = true, listboxDefinition }
							},
							wml.tag.row {  -- the okay button
								wml.tag.column {
									border = "top",
									border_size = 10,
									wml.tag.button { id = "ok", label = _"OK" },
								}
							}
						}
					}
				}
			}
		}

		-- Possible alternative gui.show_prompt https://wiki.wesnoth.org/LuaAPI/gui ???
	local options = {}
	table.insert(options,{label = _"Yes", ret_val = true})
	table.insert(options,{label = _"No", ret_val = false})

	local ret_val=false

	local function get_selected_option(dialog)
		local index = dialog[listbox_id].selected_index
		return options[index]
	end

	local function preshow(dialog)
		local listbox = dialog[listbox_id]
		for index, option in ipairs(options) do
			listbox[index].option.label = option.label
		end

		listbox:focus()
	end

	local function postshow(dialog)
		local selected_option = get_selected_option(dialog)
		ret_val = selected_option.ret_val
	end

	gui.show_dialog(dialogDefinition, preshow, postshow)

	return ret_val
end

local function trader_menu(cfg)
	local debug = false
	local items = {}
	local gem_count = {}
	if(type(cfg.items) == "table") then -- not our first rodeo
		items=cfg.items
		gem_count = cfg.gem_count
	end
	if(type(cfg.items) == "string") then -- first time we have been called
		items=loti.item.type.numbers_between(521,530)  -- Add gems.  Looking at ALL items for sort=gem might be wiser.
		for _,i in pairs(items) do gem_count[i] = wml.variables[loti.item.type[i].wml_var] end
		cfg.gem_count = gem_count
		for w in string.gmatch(cfg.items, "[%d]+") do table.insert(items,tonumber(w)) end
	end
	local unique_id=cfg.unique_id  -- Unique id for this trader, used to avoid purchasing same item more than once per trader
	local trader=cfg.trader
	local bought_items = {}
	if (cfg.bought_items ~= nil) then bought_items = cfg.bought_items end
	local gold = cfg.gold

	-- Menu items, as expected by gui.show_menu()
	local menu_items = {}
	table.insert(menu_items, {image="",use_markup="yes",details="<span weight='bold'>Nothing</span>",description="Get me outta here!",flavour="chocolate",selected_item=nil,allowed=true})

	for _,id in pairs(items) do
		(function()
			local _ = wesnoth.textdomain "wesnoth-loti"

			local item=loti.item.type[id]
			if (item.cost == nil) then
				if (debug) then print(string.format("item %d has no assigned cost, check item number and util/item_list.cfg",id)) end
				return
			end
			if (item.sort ~= "gem") then -- check to see if this item already purchased this item from this trader
				local trader_buys = wml.array_access.get "trader_buys"
				if (debug) then print("trader_buys is a " .. type(trader_buys)) end
				if(type(trader_buys) == "table") then
					local var="trader_buys."..unique_id.."."..id
					local bought_it=wml.variables[var]
					if (bought_it) then return end
				end
			end
			if (debug) then print(string.format("id = %d, name = %s, cost = %d, image = %s, desc = %s, flav = %s",
				id,item.name,item.cost,item.image,item.description,item.flavour)) end

			local label = item.name .. " (" .. item.cost .. _ " gold" .. ")"
			if (item.sort == "gem") then
				local have = gem_count[item.number]
				if (have == nil) then have=0 end
				label=item.offer .. " " .. tostring(item.cost) .. _ " (currently have " .. have .. _ " of them)"
			end

			local allowed = true
			if (item.cost > gold) then allowed = false end

			local image=item.image
			local description=item.description
			local flavour=item.flavour
			if (item.sort == "gem") then
				image = item.image .. "~CROP(18,18,36,36)"
				description = item.description_override
				flavour=""
			end


			-- Might want to check here if item already in menu_items and return if so.
			table.insert(menu_items, {
				-- Fields with the same meaning as in gui.show_menu()
				image = image,
				description = description,
				flavour = flavour,
				use_markup = false,
				details = label,
				-- This field is used to determine which item has been selected.
				selected_item = id,
				-- If false, player can't afford this item
				allowed = allowed
			})
		end)()
	end


	-- Prepare the layout structure for gui.show_dialog().
	local listbox_id = "trader_menu_list"

	-- 1) listbox_template: shows one possible item (e.g. Ruby, or Holy Sword)
	local listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				grow_factor = 1,
				border = "all",
				border_size = 0,
				horizontal_alignment = "left",
				wml.tag.image {
					id = "image"
				}
			},
			wml.tag.column {
				grow_factor = 1,
				border = "all",
				border_size = 0,
				horizontal_grow = true,
				wml.tag.label {
					id = "item_name",
					text_alignment = "left"
				}

			}
		}
	}

	-- 2) listbox_widget: shows a list of all items.
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
	local query={_"What would you like to buy?", _"Buy something or get out", _"See anything to your liking?", _"I have a few items here that fell off a wagon"}
	local rand = math.random(1,#query)
	local dialogDefinition = {
		wml.tag.tooltip { id = "tooltip_large" },
		wml.tag.helptip { id = "tooltip_large" },
		wml.tag.grid {

			-- Header (1 row containing a [label] with help)
			wml.tag.row {
				wml.tag.column {
					border = "bottom",
					border_size = 10,
					wml.tag.label {
						id = "trader_menu_top_label",
						use_markup = true,
						label = "<span size='large' weight='bold'>" ..
							query[rand] .. "</span>"
						}
					}
				},
			-- Listbox, where each row shows ONE of the possible items
			wml.tag.row {
				wml.tag.column { horizontal_grow = true, listboxDefinition }
			},

			-- OK button
			wml.tag.row {
				wml.tag.row {
					wml.tag.column {
						border = "all",
						border_size = 20,
						wml.tag.button { id = "ok", label = _"OK" },
						}
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

		for index, menu_item in ipairs(menu_items) do
			listbox[index].image.label = menu_item.image
			listbox[index].image.tooltip = menu_item.flavour
			listbox[index].item_name.use_markup = menu_item.use_markup
			listbox[index].item_name.label = menu_item.details
			listbox[index].item_name.tooltip = menu_item.description

			if not menu_item.allowed then
				listbox[index].item_name.enabled = false
			end
		end
		-- If user selects a non-allowed purchase, OK button must become disabled.
		-- If user then selects an allowed purchase, OK button must become enabled.
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

	local function gui_show_dialog_no_args()
		gui.show_dialog(dialogDefinition, preshow, postshow)
	end
	wesnoth.synchronize_choice(gui_show_dialog_no_args)

	if not selected_menu_item.allowed then
		-- Disabled menu item was somehow selected,
		-- ignore this and just show the dialog again.
		return trader_menu(cfg)
	end

	if (selected_menu_item.selected_item ~= nil) then
		local item=loti.item.type[selected_menu_item.selected_item]
		if (item.sort == "gem") then
			gem_count[item.number] = gem_count[item.number]  + 1
			cfg.gem_count = gem_count
			gold = gold - item.cost
			cfg.gold = gold
			table.insert(bought_items,item)
			cfg.bought_items = bought_items
			cfg.items = items
			return trader_menu(cfg)  -- stay in menu until player chooses "Nothing", but skip confirmation for gems
		end

		-- Do you really want it?
		local doit=confirm_purchase(item,trader)
		if not doit then return trader_menu(cfg) end

		table.insert(bought_items,item)
		gold = gold - item.cost

		local bought="trader_buys."  .. unique_id .. "." .. selected_menu_item.selected_item
		wml.variables[bought]="yes"
		cfg.bought_items = bought_items
		cfg.gold = gold
		cfg.items = items

		return trader_menu(cfg)  -- stay in menu until player chooses "Nothing"
        end
	return bought_items
end
function wesnoth.wml_actions.trader_menu_safe(cfg)  -- and broke
	local newcfg={}
	for index, value in pairs(cfg) do
		newcfg[index] = value
	end
	local side_number = wml.variables.side_number
	local gold = wesnoth.sides.get(side_number).gold
	newcfg.gold=gold

	local function trader_menu_no_arg()
		return trader_menu(newcfg)
	end
	local bought_items = wesnoth.synchronize_choice(trader_menu_no_arg)

	for _, item in pairs(bought_items) do
		wml.fire("gold",{side=side_number,amount=-item.cost})
		loti.item.on_the_ground.add(item.number, cfg.x, cfg.y, item.sort)  -- place item on ground
		wesnoth.wml_actions.fire_event{ name="item_pick", { "primary_unit", { x=cfg.x, y=cfg.y } } }
	end
end

function wesnoth.wml_actions.trader_menu(cfg)
	local newcfg={}
	for index, value in pairs(cfg) do
		newcfg[index] = value
	end
	local side_number = wml.variables.side_number
	local gold = wesnoth.sides.get(side_number).gold
	newcfg.gold=gold

	local bought_items=trader_menu(newcfg)

	for _, item in pairs(bought_items) do
		wml.fire("gold",{side=side_number,amount=-item.cost})
		loti.item.on_the_ground.add(item.number, cfg.x, cfg.y, item.sort)  -- place item on ground
		wesnoth.wml_actions.fire_event{ name="item_pick", { "primary_unit", { x=cfg.x, y=cfg.y } } }
	end
end


