codes = true -- Show luacheck's error/warning codes

std = "lua53"
max_line_length = false -- May enable later. Have too many lines with 150+ symbols in existing code

globals = { "loti", "T" }
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

