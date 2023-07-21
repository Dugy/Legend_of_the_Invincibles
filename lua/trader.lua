--! #textdomain "wesnoth-loti"
local _ = wesnoth.textdomain "wesnoth-loti"

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



local function trader_menu(cfg)
	local debug = true
	local x = cfg.x
	local y = cfg.y
	local items = {}
	if(type(cfg.items) == "table") then items=cfg.items end  -- we called ourself
	if(type(cfg.items) == "string") then                     -- we were called by WML
		items=loti.item.type.numbers_between(521,530)  -- Add gems.  Looking at ALL items for sort=gem might be wiser.
		for w in string.gmatch(cfg.items, "[%d]+") do table.insert(items,tonumber(w)) end
	end
	local trader_id=cfg.id

	local gold = wesnoth.sides.get(1).gold  -- that's side=1, if it matters (MP?)

	-- Menu items, as expected by gui.show_menu()
	local menu_items = {}
	--table.insert(menu_items, {image="",details="<span weight='bold'>Nothing</span>",selected_item=nil,allowed=true})
	table.insert(menu_items, {image="",details="Nothing",selected_item=nil,allowed=true})

	for _,id in pairs(items) do
		(function()
			local item=loti.item.type[id]
			if (item.cost == nil) then
				if (debug) then print(string.format("item %d has no assigned cost, check item number and util/item_list.cfg",id)) end
				return
			end
			if (item.sort ~= "gem") then -- check to see if this item already purchased this item from this trader
				local trader_buys = wml.array_access.get "trader_buys"
				if (debug) then print("trader_buys is a " .. type(trader_buys)) end
				if(type(trader_buys) == "table") then
					for i,k in pairs(trader_buys) do
						print(string.format("i = <%s>, type(k) = <%s>",i,type(k)))
					end
					local var="trader_buys."..trader_id.."."..id
					local bought_it=wml.variables[var]
					if (bought_it) then return end
				end
			end
			if (debug) then print(string.format("id = %d, name = %s, cost = %d, image = %s",id,item.name,item.cost,item.image)) end

			local label = string.format("%s (%d gold)",item.name,item.cost)
			if (item.sort == "gem") then
				local prefix="Buy a "
				if (string.find(string.sub(tostring(item.name),1,1),"[AEIOUaeiou]")) then prefix="Buy an " end
				local have = wml.variables[item.wml_var]
				if (have == nil) then have=0 end
				label=prefix .. string.lower(tostring(item.name)) .. " for " .. item.cost .. " (currently have " .. have .. " of them)"
			end

			local allowed = true
			if (item.cost > gold) then allowed = false end

			local image=item.image
			if (item.sort == "gem") then item.image=item.image .. "~CROP(18,18,36,36)" end

			-- Might want to check here if item already in menu_items and return if so.
			table.insert(menu_items, {
				-- Fields with the same meaning as in gui.show_menu()
				image = image,
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

	-- 1) listbox_template: shows one possible upgrade (icon + description), e.g. Particle Storm.
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
			return trader_menu(cfg)  -- stay in menu until player chooses "Nothing"
		end

		-- Do you really want it? gui goes here --

		wml.fire("gold",{side=1,amount=-item.cost})

		if (item.sort ~= "gem") then -- item cannot be purchased more than once at this trader
			local bought="trader_buys."  .. trader_id .. "." .. selected_menu_item.selected_item
			wml.variables[bought]="yes"
		end
		wesnoth.wml_actions.item {  -- draw item on ground
			x = x,
			y = y,
			image = item.image,
			halo = loti.item.halo
		}
		loti.item.on_the_ground.add(selected_menu_item.selected_item, x, y, item.sort)  -- place item on ground
		wml.tag.fire_event {  -- pick up item on ground
			name = "item_pick",
			wml.tag.primary_unit {
				x = x,
				y = y
			}
		}
if (false) then
		-- create event to pick up item
		--
		-- this section may be unnecessary, just need to make sure item_pick is there and fire?
		--
		-- What about units that can't equip items, what if they buy?
		--
	       if wml.variables["allied_sides"] then
			wesnoth.add_event_handler {
				id = "ie" .. x .. "|" .. y,
				name = "moveto",
				first_time_only = "no",
				wml.tag.filter {
					x = x,
					y = y,
					side = wml.variables["allied_sides"],
					wml.tag["not"] {
						wml.tag.filter_wml {
							wml.tag.variables {
								cant_pick = "yes"
							}
						}
					},
				},
				wml.tag.fire_event {
					name = "item_pick",
					wml.tag.primary_unit {
						x = x,
						y = y
					}
				}
			}
		else
        -- Enable "pick item" event when some unit walks onto this hex.
        -- (see PLACE_ITEM_EVENT for WML version)
        -- this is a LEGACY version, which uses the "controller" side filter
			wesnoth.add_event_handler {
				id = "ie" .. x .. "|" .. y,
				name = "moveto",
				first_time_only = "no",
				wml.tag.filter {
					x = x,
					y = y,
					wml.tag["not"] {
						wml.tag.filter_wml {
							wml.tag.variables {
								cant_pick = "yes"
							}
						}
					},
					wml.tag.filter_side {
						controller = "human"
					}
				},
				wml.tag.fire_event {  -- pick up item on ground
					name = "item_pick",
					wml.tag.primary_unit {
						x = x,
						y = y
					}
				}
			}
		end
		-- Set WML global trader_purcashed.trader_id.item
		--
		-- this is odd, you can keep buying items but you don't pick them up until you're done - MP?
		-- And the first time you buy you don't get to pick it up that turn unless you use pick up items on the ground.
		-- After that, it's immediate.
end  -- if (false)
		return trader_menu(cfg)  -- stay in menu until player chooses "Nothing"
	end
--	return selected_menu_item.selected_item
end

function wesnoth.wml_actions.trader_menu(cfg)
	trader_menu(cfg)
end

