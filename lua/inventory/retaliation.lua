--! #textdomain "wesnoth-loti"
--
-- "Select weapons for retaliation" tab of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

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

	wesnoth.add_widget_definition("toggle_panel", "checklist", definition)
end

-- Callback that updates "Select weapons for retaliation" tab whenever it is shown.
-- Note: see get_tab() for internal structure of this tab.
local function onshow(unit)
	local listbox_id = "retaliation_listbox"

	-- Ensure than no rows are selected.
	wesnoth.set_dialog_value({}, listbox_id)
	retaliation_checkboxes = {}

	for index, attack in ipairs(unit.attacks) do
		local attack_only = true -- True if "attack only" by design, e.g. whirlwind
		local allowed = attack.defense_weight > 0 -- True if currently allowed

		if not allowed then
			-- Double-check that this attack was disabled via this dialog.
			-- If not, this is likely an attack like whirlwind or redeem,
			-- and we shouldn't show it on the list at all.
			for _, disable_record in ipairs(helper.get_variable_array("disabled_defences", unit)) do
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

			wesnoth.set_dialog_value(text, listbox_id, checkbox_id, "attack_name")

			-- This is a multiselect listbox,
			-- each set_dialog_value() selects an additional row.
			if allowed then
				wesnoth.set_dialog_value(checkbox_id, listbox_id)
			end
		end
	end
end

-- Callback that submits the form of "Select weapons for retaliation" tab.
local function onsave(unit)
	local listbox_id = "retaliation_listbox"
	local is_selected = {} -- { checkbox_id1 => 1, checkbox_id2 => 1, ... }

	-- Determine which checkboxes are selected.
	-- This is a multiselect listbox, so get_dialog_value() has a second return value.
	local _, listbox_values = wesnoth.get_dialog_value(listbox_id)
	for _, checkbox_id in pairs(listbox_values) do
		is_selected[checkbox_id] = 1
	end

	-- Save changes (if any) and go back to the Items tab.
	local disabled_defences = {}
	for checkbox_id, attack_index in ipairs(retaliation_checkboxes) do
		if is_selected[checkbox_id] then
			unit.attacks[attack_index].defense_weight = 1
		else
			unit.attacks[attack_index].defense_weight = 0

			-- Add to unit.variables.disabled_defences, so that we would later know
			-- that this is not an "attack only by design" weapon.
			table.insert(disabled_defences, {
				name = unit.attacks[attack_index].name,
				order = attack_index - 1 -- Backward compatibility with WML dialog
			})
		end
	end

	helper.set_variable_array("disabled_defences", disabled_defences, unit)
end


-- Add this tab to the dialog.

return function(inventory_dialog)
	inventory_dialog.add_tab {
		id = "retaliation_tab",
		grid = get_tab,
		onshow = onshow
	}

	inventory_dialog.install_callbacks(function()
		-- Callback for "Save" button.
		wesnoth.set_dialog_callback(function()
			-- Unit is not yet known when the callback is installed,
			-- but it will already be known when it is called.
			onsave(inventory_dialog.current_unit)
			inventory_dialog.goto_tab("items_tab")
		end, "retaliation_save")
	end)

	inventory_dialog.register_widgets(register_checklist_widget)
end
