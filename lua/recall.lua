--! #textdomain "wesnoth-loti"

local _ = wesnoth.textdomain "wesnoth-loti"

local T = wml.tag

function wesnoth.wml_actions.recall_from_variable(cfg)
	local from_array = cfg.from or wml.error("[recall_from_variable]: missing required from= ")
	local to_var = cfg.to or wml.error("[recall_from_variable]: missing required to= ")
	local unit_list = wml.array_access.get(from_array) or wml.error(string.format("[recall_from_variable]: failed to fetch wml array %s",from_array))

	local listboxItem = T.grid {
		T.row {
			T.column {
				T.label { id = "available_unit",
					linked_group = "available_unit"
				}
			}
		}
	}

	local listbox_id = "available_units"
	local listboxDefinition = T.listbox { id = listbox_id,
		T.list_definition {
			T.row {
				T.column {
					T.toggle_panel { listboxItem }
				}
			}
		}
	}

	local dialogDefinition = {
		T.tooltip { id = "tooltip" },
		T.helptip { id = "tooltip" },
		T.linked_group { id = "available_unit", fixed_width = true },
		T.grid {
			T.row {  -- header
				T.column {
					T.grid {
						T.row {
							T.column {
								border = "bottom",
								border_size = 10,
								T.label {
									use_markup = true,
									label = "<span size='large' color='yellow' weight='bold'>"
										.. _"Select unit to recall" .. "</span>"
									}
							}
						}
					}
				}
			},
			T.row {  -- Body
				T.column {
					T.grid {
						T.row {
							T.column {
								border = "right",
								border_size = 40,
								listboxDefinition
							},
							T.column {
								T.unit_preview_pane { id = "unit_preview" }
							}
						}
					}
				}
			},
			T.row {  -- Footer
				T.column {
					T.grid {
						T.row {
							T.column {
								T.spacer { width = 400 }
							},
							T.column {
								border = "top,right",
								border_size = 10,
								T.button { id = "ok",
									label = _"OK"
								}
							}
						}
					}
				}
			}
		}
	}

	local picked = 1

	local function preshow(dialog)
		local listbox = dialog[listbox_id]
		for i,unit in ipairs(unit_list) do
			listbox[i].available_unit.label = unit.name .. "(" .. unit.language_name .. ")"
		end
		local function draw_unit()
			wesnoth.units.to_recall(unit_list[listbox.selected_index])
			local tmp = wesnoth.units.find_on_recall{ id = unit_list[listbox.selected_index].id }[1]
			dialog.unit_preview.unit = tmp
			wesnoth.units.extract(tmp)
			picked = listbox.selected_index
		end
		draw_unit()
		listbox.on_modified = draw_unit
	end

	gui.show_dialog(dialogDefinition,preshow)

	wml.variables[to_var] = picked - 1
end
-- luacheck: ignore 113
-- luacheck: ignore 211
-- luacheck: ignore 612

local chat = wesnoth.interface.add_chat_message
local sf = string.format

function wesnoth.wml_actions.autorecall_menu()
	local OK_BUTTON_VALUE = 99
	local CANCEL_BUTTON_VALUE = -2  
	local RIGHT_BUTTON_VALUE = 5
	local LEFT_BUTTON_VALUE = 6
	local UP_BUTTON_VALUE = 7
	local DOWN_BUTTON_VALUE = 8
	local ADD_BUTTON_VALUE = 9

	local gold = wesnoth.sides[wesnoth.current.side].gold
	local max_autorecall = wml.variables.max_autorecall or 8
	local next_autorecall_price
	local function update_next_autorecall_price()
		next_autorecall_price = 100 * (max_autorecall - 7)
		if wesnoth.scenario.difficulty == "EASY" then
			next_autorecall_price = math.floor(next_autorecall_price / 1.5)
		elseif wesnoth.scenario.difficulty == "NORMAL" then
			next_autorecall_price = math.floor(next_autorecall_price / 1.2)
		end
	end
	update_next_autorecall_price()

	local ar_list = wml.array_access.get "autorecall"
	local av_list = {}

	-- Create list of available units
	local on_ar = {}
	for _,unit in pairs(ar_list) do
		on_ar[unit.id] = true
	end
	local our_team = wesnoth.units.find{ side =  wesnoth.current.side }
	for _,unit in pairs(our_team) do
		if not on_ar[unit.id] and unit.id ~= 'Efraim' and unit.id ~= 'Lethalia' and unit.id ~= 'akulas_sister' and
			unit.id ~= 'Lethalia_evil' and unit.id ~= 'Lilith'
			then table.insert(av_list,unit.__cfg) end
	end

	-- autorecall list from older saves may not contain full unit data, update
	local new_ar = {}
	for _,oldunit in ipairs(ar_list) do
		local units = wesnoth.units.find{ id=oldunit.id }
		if #units == 1 then table.insert(new_ar,units[1].__cfg) end
	end
	ar_list = new_ar

	local ar_selected_index = 0
	local av_selected_index = 0

	local ar_listbox_def = T.listbox { id = "ar_listbox",
		has_minimum = false,
		T.list_definition {
                        wml.tag.row {
                                wml.tag.column {
                                        wml.tag.toggle_panel {
						T.grid {
							T.row {
                                                                T.column {
                                                                        T.label { id = "ar_position",
                                                                                text_alignment = "right",
                                                                                linked_group = "ar_position"
                                                                         }
                                                                },
                                                                T.column {
                                                                        T.label { id = "ar_unit",
                                                                                linked_group = "ar_unit"
                                                                        }
                                                                }
                                                        },
                                                        T.row {
                                                                T.column { T.spacer {} },
                                                                T.column { T.image { id = "ar_threshold" } } -- a gap between units that can/can't be recalled due to limit
							}
						}
					}
				}
			}
		}
	}
	local av_listbox_def = T.listbox { id = "av_listbox",
                has_minimum = false,
		T.list_definition {
			T.row {
				T.column {
					T.toggle_panel {
                                                T.grid {
                                                        T.row {
                                                                T.column {
                                                                        T.label { id = "av_unit",
                                                                                linked_group = "av_unit"
									}
								}
							}
						}
					}
				}
			}
		}
	}


	local empty_page = T.page_definition { id = "empty_page", T.row { T.column { T.spacer {width=400} } } }

	local unit_info_frame = T.grid { T.row { T.column { T.unit_preview_pane { id = "unit_info_preview", height=100, width=100 } } } }
	local unit_info_page = T.page_definition { id = "unit_info_page",
		T.row { T.column { unit_info_frame } } }

	local unit_info_mp = T.multi_page { id = "unit_info_mp",
		empty_page,
		unit_info_page
	}

	local done = false
	while not done do

		local dialogDefinition = {
			T.tooltip { id = "tooltip" },
			T.helptip { id = "tooltip_large" },
			T.linked_group { id = "ar_position", fixed_width = true, },
			T.linked_group { id = "ar_unit", fixed_width = true },
			T.linked_group { id = "av_unit", fixed_width = true },
			T.grid {
				T.row {
					T.column {
						T.grid {
							T.row {
								T.column { id = 'autorecall_list',
									vertical_alignment="top",
									T.grid {
										T.row {
											T.column {
												T.label {
													use_markup=true,
													label = "<span size='large' color='yellow'>"
													.. _"Units to be Automatically Recalled (" ..
													#ar_list .. "/" ..  max_autorecall .. ")</span>" }
											}
										},
										T.row { 
											T.column { horizontal_alignment = "left", ar_listbox_def }
										},
									}
								},
								T.column { border="left,right", border_size = 50, unit_info_mp },
								T.column { id = 'av_list',
									vertical_alignment="top",
									T.grid {
										T.row {
											T.column {
												T.label { 
													use_markup=true,
													label = "<span size='large' color='yellow'>"
													.. _"Available Units (" .. #av_list .. ")</span>" }
											}
										},
										T.row {
											T.column { horizontal_alignment = "left", av_listbox_def }
										}
									}
								}
							}
						}
					}
				},
				T.row {
					T.column { 
						border="top",
						border_size = 25,
						T.grid {
							T.row {
								--T.column { T.spacer { width = 10 } },
								T.column {
									border = "right",
									border_size = 80,
									T.button { id = "add_slot",
										definition = "add",
										return_value_id = ADD_BUTTON_VALUE,
										tooltip =_ "Buy space to automatically recall an additional unit" .. "\n" ..
											_"Need: " .. next_autorecall_price .. _"  Have: " .. gold 
									}
								},
								T.column {
									border = "right",
									border_size = 10,
									T.button { id = "ar_up",
										return_value_id = UP_BUTTON_VALUE,
										definition = "up_arrow"
									}
								},
								T.column {
									border = "right",
									border_size = 40,
									T.button { id = "ar_down",
										return_value_id = DOWN_BUTTON_VALUE,
										definition = "down_arrow"
									}
								},
								T.column { T.spacer { width = 10 } },
								T.column {
									border = "left,right",
									border_size = 10,
									T.button { id = "ar_remove",
										return_value_id = RIGHT_BUTTON_VALUE,
										tooltip = "Remove unit from the autorecall list",
										definition = "right_arrow"
									}
								},
								T.column { T.spacer { width = 100 } },
								T.column {
									border = "right",
									border_size = 10,
									T.button {
										id = "ok_button",
										label =_ "OK",
										return_value = OK_BUTTON_VALUE,
									}
								},
								T.column {
									border = "right",
									border_size = 100,
									T.button {
										id = "cancel",
										label = "Cancel"
									}
								},
								T.column {
									border = "right",
									border_size = 40,
									T.button { id = "av_remove",
										return_value_id = LEFT_BUTTON_VALUE,
										definition = "left_arrow",
										tooltip =_ "Move unit to the autorecall list"
									}
								},
								--T.column {
								--	T.button { id = "av_info",
								--		return_value_id = "ok",
								--		definition = "action_about"
								--	}
		} 	}	 }	 }	 }	 }	 

		local function preshow(dialog)
			local ar_listbox = dialog["ar_listbox"]
			local av_listbox = dialog["av_listbox"]
			local function refresh_buttons()
				dialog.ar_up.enabled = false
				dialog.ar_down.enabled = false
				dialog.ar_remove.enabled = false
				dialog.av_remove.enabled = false
				--dialog.av_info.enabled = false
				if ar_listbox.selected_index ~= 0 then
					if ar_listbox.selected_index ~= 1 then dialog.ar_up.enabled = true end
					if ar_listbox.selected_index ~= #ar_list then dialog.ar_down.enabled = true end
					dialog.ar_remove.enabled = true
				elseif av_selected_index ~= 0 then
					--dialog.av_info.enabled = true
					dialog.av_remove.enabled = true
				end
			end

			local function refresh_multipage()
				local unit
				if ar_selected_index ~= 0 then
					unit = ar_list[ar_selected_index]
				elseif av_selected_index ~= 0 then
					unit = av_list[av_selected_index]
				else 
					return
				end

				dialog.unit_info_mp[2].unit_info_preview.unit = wesnoth.units.find{ id = unit.id }[1]
				dialog.unit_info_mp.selected_index = 2
			end

			local function ar_unit_toggle()
				if ar_listbox.selected_index ~= 0 then
					ar_selected_index = ar_listbox.selected_index
					av_selected_index = 0
					dialog.unit_info_mp.selected_index = 2
				else
					ar_selected_index = 0
					dialog.unit_info_mp.selected_index = 1
				end
				dialog:close()
			end
			local function av_unit_toggle()
				if av_listbox.selected_index ~= 0 then
					av_selected_index = av_listbox.selected_index
					ar_selected_index = 0 
					dialog.unit_info_mp.selected_index = 2
				else
					av_selected_index = 0
					dialog.unit_info_mp.selected_index = 1
				end
				--refresh_buttons()
				--refresh_multipage()
				dialog:close()
			end

			local function add_slot()
				local poor_msg =_ "You do not have enough gold to do that"
				if gold < next_autorecall_price then
					gui.show_prompt("",poor_msg)
					return
				end
				max_autorecall = max_autorecall + 1
				gold = gold - next_autorecall_price
				update_next_autorecall_price()
				dialog:close()
			end

			local function move_up()  -- move unit at ar_list[index] to ar_list[index-1]
				if ar_selected_index == 1 then return end
				local tmp
				for i,_ in ipairs(ar_list) do
					if i == ar_selected_index - 1 then
						tmp = ar_list[i]
						ar_list[i]=ar_list[ar_selected_index]
					elseif i == ar_selected_index then
						ar_list[ar_selected_index]=tmp
					end
				end
				ar_selected_index = ar_selected_index - 1
				dialog:close()
			end
			local function move_down()  -- move unit at ar_list[ar_selected_index] to ar_list[ar_selected_index+1]
				if ar_selected_index == #ar_list then return end
				local tmp
				for i,_ in ipairs(ar_list) do
					if i == ar_selected_index then
						tmp = ar_list[i]
						ar_list[i] = ar_list[i+1]
					elseif i == ar_selected_index + 1 then
						ar_list[i] = tmp
					end
				end
				ar_selected_index = ar_selected_index + 1
				dialog:close()
			end
			local function switch_lists(cfg) -- remove unit from from[index], append to to[]
				local from = cfg.from
				local to = cfg.to
				local index = cfg.index
				local new_list = {}
				for i,unit in ipairs(from) do
					if i == index then
						table.insert(to,unit)
					else
						table.insert(new_list,unit)
					end
				end
				return new_list,to
			end

			dialog.add_slot.on_button_click = add_slot
			dialog.ar_up.on_button_click = move_up
			dialog.ar_down.on_button_click = move_down
			dialog.ar_remove.on_button_click = function() 
				ar_list,av_list = switch_lists({index=ar_selected_index,from=ar_list,to=av_list})
				if ar_selected_index > #ar_list then ar_selected_index = #ar_list end
				if ar_selected_index == 0 then ar_selected_index = 0 end
				dialog:close()
			end
			dialog.av_remove.on_button_click = function() av_list,ar_list=
				switch_lists({index=av_selected_index,from=av_list,to=ar_list})
				av_selected_index = 0
				ar_selected_index = #ar_list
				dialog:close()
			end

			for i,unit in ipairs(ar_list) do
				local units = wesnoth.units.find{ id = unit.id } 
				local markup = ""
				if i > max_autorecall then markup = "font-style='oblique'" end
				ar_listbox[i].ar_position.marked_up_text = string.format("<span font_family='monospace'>%d) </span>",i)
				ar_listbox[i].ar_unit.marked_up_text = string.format("<span %s>%s (%s)</span>",markup,units[1].name,
					units[1].__cfg.language_name)
				if i == max_autorecall then
					ar_listbox[i].ar_threshold.label = "images/misc/blank.png~SCALE(1,10)"
				else
					ar_listbox[i].ar_threshold.label = "images/misc/blank.png~SCALE(1,1)"
				end
			end
			ar_listbox.on_modified = ar_unit_toggle
			if ar_selected_index ~= 0 then
				ar_listbox.selected_index = ar_selected_index
			end

			av_list = sort_unit_list(av_list)
			for i,unit in ipairs(av_list) do
				av_listbox[i].av_unit.label = string.format("%s (%s)",unit.name,unit.language_name)
			end
			av_listbox.on_modified = av_unit_toggle
			if av_selected_index ~= 0 then
				av_listbox.selected_index = av_selected_index
			end

			dialog.unit_info_mp:add_item_of_type("empty_page")
			dialog.unit_info_mp:add_item_of_type("unit_info_page")

			refresh_multipage()
			refresh_buttons()
		end
		local ret_val = wesnoth.sync.evaluate_single(function()
			return { status = gui.show_dialog(dialogDefinition,preshow) }
		end).status
		if ret_val == OK_BUTTON_VALUE then  -- the ok button
			wml.array_access.set("autorecall", ar_list)
			wml.variables["max_autorecall"] = max_autorecall
			wesnoth.sides[wesnoth.current.side].gold = gold
			done = true
		end
		if ret_val == CANCEL_BUTTON_VALUE then done = true end  -- cancel/escape - abort changes
	end  -- "while done"
end

