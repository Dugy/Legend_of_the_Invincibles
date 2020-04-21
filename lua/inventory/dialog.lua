--! #textdomain "wesnoth-loti"
--
-- Implementation of the "display inventory" dialog (shows items currently on the unit).
--

local _ = wesnoth.textdomain "wesnoth-loti"
local helper = wesnoth.require "lua/helper.lua"

-- These Lua files are loaded as plugins.
-- They receive an "inventory_dialog" object as parameter,
-- which provides methods for adding tabs, installing callbacks, etc.
local PLUGINS_LIST = { "multiplayer_safety", "items", "retaliation", "storage", "recall" }

-------------------------------------------------------------------------------

-- List of all tabs in the Inventory dialog.
-- Only one tab is visible at a time.
-- Another tab can be opened via goto_tab("id_of_new_tab").
local tabs = {}

-- Various callbacks that can be installed by plugins.
local install_callback_functions = {}
local register_widget_functions = {}
local onsubmit_callbacks = {}
local enter_or_ok_catcher

-- Plugin interface (inventory_dialog).
-- This pseudo-object is passed to plugins like [retaliation.lua],
-- allowing them to add new tabs/widgets/callbacks to the dialog.
local inventory_dialog = {}
inventory_dialog.add_tab = function(tab)
	-- Sanity checks.
	if not tab.id then
		helper.wml_error('inventory_dialog.add_tab: missing parameter "id"')
	elseif type(tab.grid) ~= "function" then
		helper.wml_error('inventory_dialog.add_tab: parameter "grid" is not a function.')
	elseif type(tab.onshow) ~= "function" then
		helper.wml_error('inventory_dialog.add_tab: parameter "onshow" is not a function.')
	end

	tabs[tab.id] = { grid = tab.grid, onshow = tab.onshow }
end

-- Queue install_function() to be called when it's good time to use wesnoth.set_dialog_callback(inventory_dialog).
inventory_dialog.install_callbacks = function(install_function)
	table.insert(install_callback_functions, install_function)
end

-- Queue register_function() to be called when it's good time to use wesnoth.add_widget_definition().
inventory_dialog.register_widgets = function(register_function)
	table.insert(register_widget_functions, register_function)
end

-- Queue callback() to be called when the Inventory dialog has been closed.
inventory_dialog.add_onsubmit_callback = function(callback)
	table.insert(onsubmit_callbacks, callback)
end

-- Queue function to be called if player presses Enter or clicks OK button.
-- Parameter: field_id - ID of some widget. Its value will be passed to enter_callback as parameter.
-- NOTE: this callback is deleted after use. You should call catch_enter_or_ok() from onshow().
-- NOTE: this replaces the existing callback (if any).
inventory_dialog.catch_enter_or_ok = function(field_id, enter_callback)
	-- This will be used if wesnoth.show_dialog() exits with return value
	-- that means either "OK was clicked" or "Enter was pressed".
	enter_or_ok_catcher = {
		field_id = field_id,
		callback = enter_callback
	}
end

-- Show one tab (and call its "onshow" callback), hide all other tabs.
-- Parameters:
-- 1) tab_id - string (e.g. "inventory"), must be one of the IDs in tabs[] array.
-- 2) Any additional parameters (if any) are passed to "onshow" callback.
inventory_dialog.goto_tab = function(tab_id, ...)
	-- If we switched to another tab, then the old Enter callback is no longer actual.
	enter_or_ok_catcher = nil

	if not tab_id then
		tab_id = "items_tab"
	end

	local unit = inventory_dialog.current_unit
	if not inventory_dialog.is_opened then
		-- Dialog is already closed (e.g. we are in "on Enter" callback),
		-- reopen it.
		return inventory_dialog.reopen_unsynced(unit, tab_id, ...)
	end

	local tab = tabs[tab_id]
	if not tab then
		-- Trying to hide ALL widgets in a dialog would crash Wesnoth.
		helper.wml_error("Error: goto_tab: tab \"" .. tab_id .. "\" doesn't exist.")
	end

	-- Show the new tab.
	wesnoth.set_dialog_visible(true, tab_id)

	-- Hide the other tabs.
	for othertab_id in pairs(tabs) do
		if othertab_id ~= tab_id then
			wesnoth.set_dialog_visible(false, othertab_id)
		end
	end

	-- Recalculate all fields on this tab (via onshow callback),
	-- plus the "unit name" field (which is global for all tabs).
	tab.onshow(unit, ...)

	-- Show "unit name" header everywhere except the blank and recall tabs.
	if tab_id == "blank_tab" or tab_id == "recall_tab" then
		wesnoth.set_dialog_visible(false, "unit_name")
	else
		wesnoth.set_dialog_visible(true, "unit_name")

		local unit_name = "<span size='large' weight='bold'>" .. unit.name ..
			"</span> <span color='#88FCA0' size='large'>" .. unit.__cfg['language_name'] .. "</span>"
		if unit.valid == "recall" then
			unit_name = unit_name .. " (" .. _"on the recall list" .. ")"
		end

		wesnoth.set_dialog_value(unit_name, "unit_name")
	end
end

-- Load plugins.
for _, lua_plugin_file in ipairs(PLUGINS_LIST) do
	wesnoth.require(lua_plugin_file)(inventory_dialog)
end

-- Flag to avoid calling register_widgets() twice
local widgets_registered = false

-- Register all custom GUI widgets used by our inventory dialog.
local function register_widgets()
	if not widgets_registered then
		for _, func in ipairs(register_widget_functions) do
			func()
		end

		widgets_registered = true
	end
end

-- NOTE: the only reason we call this function here is because it's very convenient for debugging
-- (any errors in add_widget_definition() are discovered before the map is even loaded)
-- When the widgets are completely implemented, this function will only be called from get_dialog_widget().
register_widgets()

-- Construct the unit-independent WML of Inventory dialog.
-- Note: this only creates the widget. It gets populated with data in open_inventory_dialog().
-- Returns: WML table, as expected by the first parameter of wesnoth.show_dialog().
local function get_dialog_widget()
	register_widgets()

	-- Get widget that contains all tabs.
	-- (only one tab will be visible at the same time)
	-- Returns: [grid] widget.
	local function get_multitab_widget()
		-- Wrap every tab in [panel], because panels can be made hidden/visible,
		-- and place them all into one grid.
		local row_wrapped_tabs = {}
		for tab_id, tab in pairs(tabs) do
			local grid = tab.grid()
			if type(grid) ~= "table" or grid[1] ~= "grid" then
				helper.wml_error("tab " .. tab_id .. ": grid() function didn't return a [grid] tag.")
			end

			table.insert(row_wrapped_tabs, wml.tag.row { wml.tag.column {
				wml.tag.panel {
					id = tab_id,
					grid
				}
			}})
		end

		-- Show name of the unit. This header is common for all tabs.
		table.insert(row_wrapped_tabs, 1, wml.tag.row {
			wml.tag.column {
				border = "bottom",
				border_size = 10,
				wml.tag.label {
					id = "unit_name",
					use_markup = "yes"
				}
			}
		})

		return wml.tag.grid(row_wrapped_tabs)
	end

	return {
		wml.tag.tooltip { id = "tooltip" },
		wml.tag.helptip { id = "tooltip_large" },
		get_multitab_widget()
	}
end

-- Display the inventory dialog for a unit.
-- Note: optional parameters after "unit" (if any) are passed to goto_tab().
-- WARNING: not synchronized, use via open_inventory_dialog() to avoid OoS.
inventory_dialog.reopen_unsynced = function(unit, ...)
	local goto_tab_params = table.pack(...)

	local function preshow()
		inventory_dialog.is_opened = true -- Following goto_tab() calls won't reopen the dialog

		for _, func in ipairs(install_callback_functions) do
			func()
		end

		-- We don't set current_unit variable before this point,
		-- because we want all methods except onshow() to be unit-independent.
		-- This way the dialog can be reused for another unit
		-- (e.g. to show "Units on the recall list").
		inventory_dialog.current_unit = unit
		inventory_dialog.goto_tab(table.unpack(goto_tab_params))
	end

	local function postshow()
		if enter_or_ok_catcher then
			-- Ensure that "Enter or OK" callback receives the value of requested widget,
			-- because the widget will no longer be available when this callback gets called
			-- (we won't know that Enter was pressed until show_dialog() returns,
			-- but the dialog will already be closed when this happens).
			local param = wesnoth.get_dialog_value(enter_or_ok_catcher.field_id)
			local orig_callback = enter_or_ok_catcher.callback

			enter_or_ok_catcher.callback = function()
				orig_callback(param)
			end
		end
	end

	local retval = wesnoth.show_dialog(get_dialog_widget(), preshow, postshow)
	inventory_dialog.is_opened = false -- Further attempts to open_tab() will reopen the dialog

	unit = inventory_dialog.current_unit -- Allow "recall" tab to select another unit

	-- Run onsubmit callbacks (e.g. "Items" tab uses this to handle clicks on some action buttons)
	for _, func in ipairs(onsubmit_callbacks) do
		func(unit)
	end

	-- Run "Enter or OK" callback
	if enter_or_ok_catcher then
		local callback = enter_or_ok_catcher.callback

		-- Whether we will run this callback or not, we have now left the dialog,
		-- so this callback will no longer be actual when the dialog gets opened next time
		-- (we shouldn't repeat it on next Enter/OK, unless it gets queued again).
		enter_or_ok_catcher = nil

		-- Return value of show_dialog(): -1 means "Enter pressed", 0 means "OK clicked".
		if retval == -1 or retval == 0 then
			callback()
		end
	end

	-- Next time the Inventory dialog is reopened, it should start from a clean slate.
	inventory_dialog.current_unit = nil
end

-- Multiplayer-safe (synchronized) version of reopen_unsynced().
local function open_inventory_dialog(unit)
	--inventory_dialog.mpsafety =

	local result = wesnoth.synchronize_choice(function()
		inventory_dialog.reopen_unsynced(unit)

		-- Tell other players what changed (which items were equipped, etc.).
		return inventory_dialog.mpsafety:export()
	end)

	-- Re-run the same operations (e.g. Equip/Unequip) for all other players.
	inventory_dialog.mpsafety:synchronize(result)
end

-- Tag [show_inventory] displays the inventory dialog for the unit.
-- Unit is identified by passing "cfg" parameter to wesnoth.get_units().
function wesnoth.wml_actions.show_inventory(cfg)
	local units = wesnoth.get_units(cfg)
	if #units < 1 then
		helper.wml_error("[show_inventory]: no units found.")
	end
	open_inventory_dialog(units[1])
end
