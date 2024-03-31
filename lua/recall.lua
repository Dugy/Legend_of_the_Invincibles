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
