std = "lua53"
max_line_length = false -- May enable later. Have too many lines with 150+ symbols in existing code

-- These global variables are allowed.
globals = {
	"loti", -- All non-local LoTI functions are placed here, e.g. loti.item.on_unit.list()
	"T" -- Shortcut for wml.tag
}

-- These global variables are allowed, but can't be modified (with the exception of some fields).
read_globals = {
	"wml",
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

-- Ignore "unused argument unit" (W212) in onclick callbacks of Inventory dialog:
-- keeping the unused parameter for readability (to demonstrate that callback receives it).
files["**/inventory/items.lua"] = { ignore = { "212" } }

-- Ignore "unused loop variable idx" (W213) in loops that use gettext function (which is called "_"),
-- where we can't rename "idx" to "_" (a common naming convention for "unused variable").
files["**/stats.lua"] = { ignore = { "213" } }

-- Same as above.
files["**/scenario/tutorial.lua"] = { ignore = { "212", "213" } }

-- Ignore "unused argument self" (W212) in mpsafety:constructor() and mpsafety:run_immediately().
self = false
