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

-- Provide this for require() calls
return util

