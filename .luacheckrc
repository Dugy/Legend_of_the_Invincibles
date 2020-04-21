std = "lua53"
max_line_length = false -- May enable later. Have too many lines with 150+ symbols in existing code

-- These global variables are allowed.
globals = {
	"loti", -- All non-local LoTI functions are placed here, e.g. loti.item.on_unit.list()
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

-- We ignore the following codes:
-- * W212 ("unused argument") in onclick callbacks of Inventory dialog, where we are keeping
-- the unused parameter for readability (to demonstrate that callback receives it).
-- * W213 ("unused loop variable") in loops where we can't use "_" (common naming convention
-- for "unused variable"), because these loops either use gettext function (which is called "_"),
-- or are nested within another loop where "_" is already the index, or for some other reason.
files["**/lua/inventory/items.lua"] = { ignore = {
	"212", -- "unused argument unit"
} }

files["**/lua/items.lua"] = { ignore = {
	"213" -- "unused loop variable i"
} }

files["**/lua/stats.lua"] = { ignore = {
	"213" -- "unused loop variable index"
} }

files["**/lua/scenario/tutorial.lua"] = { ignore = {
	"212", -- "unused argument item_sort"
	"213" -- "unused loop variable idx"
} }

-- Ignore "unused argument self" (W212) in mpsafety:constructor() and mpsafety:run_immediately().
self = false
