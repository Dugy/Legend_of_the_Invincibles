--! #textdomain "wesnoth-loti"
--
-- Utility functions for plugins of the inventory dialog.
--

local _ = wesnoth.textdomain "wesnoth-loti"
local util = {}

-- Create a "Close" button in the bottom-right corner of the dialog.
-- Returns: [grid] widget.
util.make_close_button = function()
	return wml.tag.grid {
		wml.tag.row {
			wml.tag.column {
				wml.tag.spacer {}
			},
			wml.tag.column {
				wml.tag.button {
					id = "ok",
					label = _"Close"
				}
			}
		}
	}
end

-- These variables are for translation of strings that depend on a parameter.
-- NO_ITEM_TEXT must list all item types that have a slot (i.e. all except potion/limited).
util.NO_ITEM_TEXT = {
	default = _"[no item]",
	ring = _"no ring",
	amulet = _"no amulet",
	cloak = _"no cloak",
	armour = _"no armour",
	helm = _"no helm",
	gauntlets = _"no gauntlets",
	boots = _"no boots",
	sword = _"no sword",
	axe = _"no axe",
	staff = _"no staff",
	xbow = _"no crossbow",
	bow = _"no bow",
	dagger = _"no dagger",
	knife = _"no knife",
	mace = _"no mace",
	polearm = _"no polearm",
	claws = _"no metal claws",
	sling = _"no sling",
	essence = _"no essence",
	thunderstick = _"no thunderstick",
	spear = _"no spear"
}

-- Provide this for require() calls
return util
