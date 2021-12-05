--! #textdomain "wesnoth-loti"
--
-- "Select weapons for retaliation" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local mpsafety

-- Ordered array of indexes of attacks (positions in unit.attacks array)
-- for attacks affected by the shown checkboxes.
-- E.g. { 1, 2, 4, ...} - where 3 was skipped because, for example, it was a whirlwind attack.
-- Calculated in onshow_retaliation_tab().
local retaliation_checkboxes = {}

-- Construct tab: "weapons for retaliation".
-- Note: result is exactly the same for any unit. See onshow() for unit-specific logic.
-- Returns: top-level [grid] widget.
local function get_tab()
	local listbox_template = wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				border = "left",
				border_size = 30,
				horizontal_grow = true,
				vertical_alignment = "center",
				wml.tag.label {
					id = "attack_name",
					text_alignment = "left"
				}
			}
		},
		wml.tag.row {
			wml.tag.column {
				wml.tag.spacer {
					height = 30
				}
			}
		}
	}

	local listbox = wml.tag.listbox {
		id = "retaliation_listbox",
		has_maximum = false, -- More than 1 checkbox can be selected.
		has_minimum = false, -- All checkboxes can be unselected.
		wml.tag.list_definition {
			wml.tag.row {
				wml.tag.column {
					horizontal_grow = true,
					wml.tag.toggle_panel {
						id = "attack_checkbox",
						definition = "checklist",
						listbox_template
					}
				}
			}
		}
	}

	return wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				border = "all",
				border_size = 15,
				wml.tag.label {
					label = _"Which attacks do you allow to use for retaliation?"
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
				wml.tag.button {
					id = "retaliation_save",
					label = _"OK"
				}
			}
		}
	}
end

-- Register custom GUI widget "checklist": toggle_panel with a checkbox (doesn't look like a selected row).
local function register_checklist_widget()
	local height = 50

	local function draw(icon)
		return {
			wml.tag.draw {
				wml.tag.image {
					name = icon
				}
			}
		}
	end

	local definition = {
		id = "checklist",
		description = 'Toggle panel which looks like a checkbox, but can have content.',

		wml.tag.resolution {
			min_width = 26, -- Can't be less than GUI__LISTBOX_SELECTED_CELL
			min_height = 26, -- Can't be less than GUI__LISTBOX_SELECTED_CELL
			default_height = height,

			wml.tag.state { -- Non-selected
				wml.tag.enabled(draw("buttons/checkbox.png")),
				wml.tag.disabled(draw("buttons/checkbox.png~GS()")),
				wml.tag.focused(draw("buttons/checkbox-active.png"))
			},
			wml.tag.state { -- Selected
				wml.tag.enabled(draw("buttons/checkbox-pressed.png")),
				wml.tag.disabled(draw("buttons/checkbox-pressed.png~GS()")),
				wml.tag.focused(draw("buttons/checkbox-active-pressed.png"))
			}
		}
	}

	gui.add_widget_definition("toggle_panel", "checklist", definition)
end

-- Callback that updates "Select weapons for retaliation" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow(dialog, unit)
	local listbox = dialog["retaliation_listbox"]

	-- Ensure than no rows are selected.
	listbox:remove_items_at(1, 0)

	retaliation_checkboxes = {}

	for index, attack in ipairs(unit.attacks) do
		local attack_only = true -- True if "attack only" by design, e.g. whirlwind
		local allowed = attack.defense_weight > 0 -- True if currently allowed

		if not allowed then
			-- Double-check that this attack was disabled via this dialog.
			-- If not, this is likely an attack like whirlwind or redeem,
			-- and we shouldn't show it on the list at all.
			for _, disable_record in ipairs(wml.array_access.get("disabled_defences", unit)) do
				-- Note when comparing: "index" is Lua array index (starts with 1),
				-- while order is C++ array index (starts with 0).
				if disable_record.order + 1 == index then
					attack_only = false
					break
				end
			end
		end

		if allowed or not attack_only then
			table.insert(retaliation_checkboxes, index)
			local checkbox_id = #retaliation_checkboxes
			local text = attack.description .. ": " .. attack.damage .. "-" .. attack.number .. " " .. attack.type

			listbox[checkbox_id]["attack_name"].label = text

			if allowed then
				listbox[checkbox_id]["attack_checkbox"].selected = true
			end
		end
	end
end

-- Callback that submits the form of "Select weapons for retaliation" tab.
local function onsave(dialog, unit)
	local listbox = dialog["retaliation_listbox"]

	-- Enqueue changes to the mpsafety and go back to the Items tab.
	local operation = {}
	for checkbox_id, attack_index in ipairs(retaliation_checkboxes) do
		local weight_cycle = 0
		if listbox[checkbox_id]["attack_checkbox"].selected then
			weight_cycle = 1
		end
		table.insert(operation, wml.tag.attack{
			index = attack_index,
			weight = weight_cycle
		})
	end
	operation.command = "set_attacks_retal"
	operation.unit = unit
	mpsafety:queue(operation)
end

-- Add this tab to the dialog.

return function(inventory_dialog)
	mpsafety = inventory_dialog.mpsafety
	inventory_dialog.add_tab {
		id = "retaliation_tab",
		grid = get_tab,
		onshow = onshow
	}

	inventory_dialog.install_callbacks(function(dialog)
		-- Callback for "Save" button.
		dialog.retaliation_save.on_button_click = function()
			-- Unit is not yet known when the callback is installed,
			-- but it will already be known when it is called.
			onsave(dialog, inventory_dialog.current_unit)
			inventory_dialog.goto_tab("items_tab")
		end
	end)

	inventory_dialog.register_widgets(register_checklist_widget)
end
