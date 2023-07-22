--! #textdomain "wesnoth-loti"
local _ = wesnoth.textdomain "wesnoth-loti"

--luacheck: ignore 211
--luacheck: ignore 511
--luacheck: ignore 241
local function dump(o)
   if type(o) == 'table' then
      local s = '\n{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

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
	local x = cfg.x
	local y = cfg.y
	local items = {}
	if(type(cfg.items) == "table") then items=cfg.items end  -- we called ourself
	if(type(cfg.items) == "string") then                     -- we were called by WML
		items=loti.item.type.numbers_between(521,530)  -- Add gems.  Looking at ALL items for sort=gem might be wiser.
		for w in string.gmatch(cfg.items, "[%d]+") do table.insert(items,tonumber(w)) end
	end
	local unique_id=cfg.unique_id  -- Unique id for this trader, used to avoid purchasing same item more than once per trader
	local trader=cfg.trader
	local bought_items = {}
	if (cfg.bought_items ~= nil) then bought_items = cfg.bought_items end
	local gold = cfg.gold
	local side_number = cfg.side_number
	print("Gold = " .. gold)

	-- Menu items, as expected by gui.show_menu()
	local menu_items = {}
	table.insert(menu_items, {image="",use_markup="yes",details="<span weight='bold'>Nothing</span>",selected_item=nil,allowed=true})

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
			if (debug) then print(string.format("id = %d, name = %s, cost = %d, image = %s",id,item.name,item.cost,item.image)) end

			local label = item.name .. "(" .. item.cost .. _ " gold" .. ")"
			if (item.sort == "gem") then
				local have = wml.variables[item.wml_var]
				if (have == nil) then have=0 end
				label=item.offer .. " " .. tostring(item.cost) .. _ " (currently have " .. have .. _ " of them)"
			end

			local allowed = true
			if (item.cost > gold) then allowed = false end

			local image=item.image
			if (item.sort == "gem") then image = item.image .. "~CROP(18,18,36,36)" end

			-- Might want to check here if item already in menu_items and return if so.
			table.insert(menu_items, {
				-- Fields with the same meaning as in gui.show_menu()
				image = image,
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

		for index, menu_item in ipairs(menu_items) do
			listbox[index].image.label = menu_item.image
			listbox[index].item_name.use_markup = menu_item.use_markup
			listbox[index].item_name.label = menu_item.details

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

	gui.show_dialog(dialogDefinition, preshow, postshow)

	if not selected_menu_item.allowed then
		-- Disabled menu item was somehow selected,
		-- ignore this and just show the dialog again.
		return trader_menu(cfg)
	end

	if (selected_menu_item.selected_item ~= nil) then
		local item=loti.item.type[selected_menu_item.selected_item]
		if (item.sort == "gem") then  -- is this okay in MP?
			local var=wml.variables[item.wml_var]
			var = var + 1
			wml.variables[item.wml_var] = var
			wml.fire("gold",{side=side_number,amount=-item.cost})
			gold = gold - item.cost
			cfg.gold = gold
			return trader_menu(cfg)  -- stay in menu until player chooses "Nothing"
		end

		-- Do you really want it?
		local doit=confirm_purchase(item,trader)
		if not doit then return trader_menu(cfg) end

		table.insert(bought_items,item)
		gold = gold - item.cost

		if (item.sort ~= "gem") then -- item cannot be purchased more than once at this trader
			local bought="trader_buys."  .. unique_id .. "." .. selected_menu_item.selected_item
			wml.variables[bought]="yes"
		end
		cfg.bought_items = bought_items
		cfg.gold = gold
		return trader_menu(cfg)  -- stay in menu until player chooses "Nothing"
        end
	return bought_items
end

function wesnoth.wml_actions.trader_menu(cfg)
	local newcfg={}
	for index, value in pairs(cfg) do
		newcfg[index] = value
	end
	local side_number = wesnoth.sides.find{ wml.tag.has_unit { x=cfg.x,y=cfg.y }}[1].side
	local gold = wesnoth.sides.get(side_number).gold
	print(type(side_number))
	print(type(gold))
	newcfg.gold=gold
	newcfg.side_number = side_number

	--local bought_items=wesnoth.synchronize_choice(trader_menu(newcfg))
	local bought_items=wesnoth.synchronize_choice(trader_menu)
	--local bought_items=trader_menu(newcfg)

	for _, item in pairs(bought_items) do
		--print("I bought " .. item.name)
		wml.fire("gold",{side=side_number,amount=-item.cost})
		loti.item.on_the_ground.add(item.number, cfg.x, cfg.y, item.sort)  -- place item on ground
		wesnoth.wml_actions.fire_event{ name="item_pick", { "primary_unit", { x=cfg.x, y=cfg.y } } }
	end
end

