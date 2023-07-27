--! #textdomain "wesnoth-loti"
local _ = wesnoth.textdomain "wesnoth-loti"

local function confirm_purchase(item,trader)

	-- Top-level dialog, includes help message and listbox.
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
									wml.tag.spacer { height = 20 }
								}
							},
							wml.tag.row {  -- the yes/no buttons
								wml.tag.column {
									wml.tag.grid {
										wml.tag.row {
											wml.tag.column {
												border = "all",
												border_size = 20,
												wml.tag.button { id = "ok", label = _"Yes" },
											},
											wml.tag.column {
												border = "all",
												border_size = 20,
												wml.tag.button {
													id = "closeit",
													label = _"No",
													return_value_id = "cancel"
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}

	local ret_val=false

	local function preshow(dialog)
		dialog.ok.on_button_click = function()
			ret_val = true
		end
	end

	local function postshow()
	end

	gui.show_dialog(dialogDefinition, preshow, postshow)

	return ret_val
end

local function trader_menu(cfg)
	local debug = false

	-- load items{} with gems, now available a merchant near you!
	local items=loti.item.type.numbers_between(521,530)  -- Add gems.  Looking at ALL items for sort=gem might be wiser.

	local gem_count = {}  -- fake count of each gem used to keep "currently have X" accurate inside this function
	for _,i in pairs(items) do gem_count[i] = wml.variables[loti.item.type[i].wml_var] end

	-- add input list of items to items{}
	for w in string.gmatch(cfg.items, "[%d]+") do table.insert(items,tonumber(w)) end  -- convert WML string to lua table

	local unique_id=cfg.unique_id  -- Unique id for this trader, used to avoid purchasing same item more than once per trader
	local trader=cfg.trader
	local gold = cfg.gold  -- fake count of gold used to ensure purchases do not exceed real gold

	local bought_items = {}

	local queries={_"What would you like to buy?", _"Buy something or get out", _"See anything to your liking?", _"I have a few items here that fell off a wagon"}
	local query = queries[math.random(1,#queries)]

	local done = false
	while not done do
		(function()
			-- Menu items, as expected by gui.show_menu()
			local menu_items = {}

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
						flavour=description
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
									query .. "</span>"
								}
							}
						},
					-- Listbox, where each row shows ONE of the possible items
					wml.tag.row {
						wml.tag.column { horizontal_grow = true, listboxDefinition }
					},

					-- OK/Close buttons
					wml.tag.row {
						wml.tag.column {
							wml.tag.grid {
								wml.tag.row {
									wml.tag.column {
										border = "all",
										border_size = 20,
										wml.tag.button { id = "ok", label = _"OK" },
										},
									wml.tag.column {
										border = "all",
										border_size = 20,
										wml.tag.button {
											id = "closeit",
											label = _"Close",
											return_value_id = "cancel"
										}
									}
								}
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
				dialog.closeit.on_button_click = function()
					done = true
					if (debug) then print("Pressed the close(it) button") end
				end
			end

			local selected_menu_item = nil
			local function postshow(dialog)
				selected_menu_item = get_selected_menu_item(dialog)
			end

			gui.show_dialog(dialogDefinition, preshow, postshow)

			if (done) then return end  -- pressed the close button

			if not selected_menu_item.allowed then
				-- Disabled menu item was somehow selected,
				-- ignore this and just show the dialog again.
				return
			end

			if (selected_menu_item.selected_item ~= nil) then
				local item=loti.item.type[selected_menu_item.selected_item]
				if (item.sort == "gem") then
					gem_count[item.number] = gem_count[item.number]  + 1
					gold = gold - item.cost
					table.insert(bought_items,item.number)
					return
				end

				-- Do you really want it?
				local doit=confirm_purchase(item,trader)
				if not doit then return end

				table.insert(bought_items,item.number)
				gold = gold - item.cost

				local bought="trader_buys."  .. unique_id .. "." .. selected_menu_item.selected_item
				wml.variables[bought]="yes"

				return
			end
		end)()
	end  -- while not (done)
	return bought_items
end


function wesnoth.wml_actions.trader_menu(cfg)
	local newcfg={}
	for index, value in pairs(cfg) do
		newcfg[index] = value
	end
	local side_number = wml.variables.side_number
	local gold = wesnoth.sides.get(side_number).gold
	newcfg.gold=gold

	local bought_items = wesnoth.sync.evaluate_single(
		function()
		local stuff=trader_menu(newcfg)
		return { value=stuff }
		end
	)
	local items={}
	for _,list in pairs(bought_items) do
		for w in string.gmatch(tostring(list), "[%d]+") do table.insert(items,tonumber(w)) end
	end
	for _,item_num in pairs(items) do
		local item=loti.item.type[item_num]
		wml.fire("gold",{side=side_number,amount=-item.cost})
		loti.item.on_the_ground.add(item.number, cfg.x, cfg.y, item.sort)
	end
	wesnoth.wml_actions.fire_event{ name="item_pick", { "primary_unit", { x=cfg.x, y=cfg.y } } }
end
