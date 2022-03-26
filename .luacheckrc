std = "lua53"
max_line_length = false -- May enable later. Have too many lines with 150+ symbols in existing code

-- These global variables are allowed.
globals = {
	"loti", -- All non-local LotI functions are placed here, e.g. loti.item.on_unit.list()
	"crafting", -- Non-local state of Crafting dialog
	"T", -- Shortcut for wml.tag,

	-- FIXME: these globals should be moved somewhere within loti[] array
	"damage_type_list",
	"melee_type_list",
	"ranged_type_list",
	"resist_penetrate_descriptions",
	"resist_penetrate_list",
	"resist_type_descriptions",
	"resist_type_list",
	"sort_list",
	"weapon_type_list"
}

-- These global variables are allowed, but can't be modified (with the exception of some fields).
read_globals = {
	wml = {
		fields = {
			-- wml.variables[something] is supposed to be modified
			variables = {
				read_only = false,
				other_fields = true
			}
		},
		other_fields = true
	},
	"filesystem",
	"gui",
	"mathx",
	wesnoth = {
		fields = {
			-- wesnoth.wml_actions[something] is supposed to be modified
			wml_actions = {
				read_only = false,
				other_fields = true
			},

			-- wesnoth.theme_units[something] is supposed to be modified
			theme_items = {
				read_only = false,
				other_fields = true
			},

			-- wesnoth.sides[number] is supposed to be modified
			sides = {
				read_only = false,
				other_fields = true
			},

			-- "wesnoth.interface.game_display.unit_status" is supposed to be modified
			interface = {
				fields = {
					game_display = {
						fields = {
							unit_status = {
								read_only = false,
								other_fields = true
							}
						},
						other_fields = true
					}
				},
				other_fields = true
			},

			-- Various utility/debug functions
			deepcopy = { read_only = false },
			dbms = { read_only = false },
			loop_guard = { read_only = false },

			-- FIXME: should probably rename wesnoth.update_stats into loti.update_stats
			update_stats = { read_only = false }
		},
		other_fields = true
	}
}

codes = true -- Show luacheck's error/warning codes. Useful for adding exceptions (see below).

-- Ignore "unused argument self" (W212) in mpsafety:constructor() and mpsafety:run_immediately().
self = false
