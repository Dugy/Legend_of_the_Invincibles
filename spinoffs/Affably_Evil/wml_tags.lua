function wesnoth.wml_actions.repeating_message(cfg)
	local message = cfg.message or ""
	local first = cfg.first or message
	cfg = cfg.__literal
	local stop = {}
	local length = 0
	local repeat_options = false
	local depth = wesnoth.get_variable("lua_repeating_message_depth") -- These should work when nested
	if depth == nil then
		wesnoth.set_variable("lua_repeating_message_depth", 1)
		depth = 0
	else
		wesnoth.set_variable("lua_repeating_message_depth", depth + 1)
	end
	if cfg.repeat_options == true then
		wesnoth.set_variable("lua_repeating_message_do_repeat" .. tonumber(depth), true)
		cfg.repeat_options = nil
		repeat_options = true
	end
	-- Prepare the contents to be used as [message], remove [break] tags and mark where they were and set a variable to infrom us about option chosen
	for i = 1,#cfg do
		if cfg[i][1] == "option" then
			length = length + 1
			if cfg[i][2] then
				for j = 1,#cfg[i][2] do
					if cfg[i][2][j][1] == "command" then
						for k = 1,#cfg[i][2][j][2] do
							if cfg[i][2][j][2][k][1] == "break" then
								stop[i] = true
								table.remove(cfg[i][2][j][2], k)
							end
						end
						table.insert(cfg[i][2][j][2], { "set_variable", { name="lua_repeating_message_option_chosen" .. tonumber(depth), value=i }} )
					end
				end
			end
		end
	end
	-- Repeat once for each option
	for repetition = 1,length do
		if repetition == 1 then
			cfg.message = first
			wesnoth.set_variable("first_view", true) -- Set a variable that indicates that the message is viewed for the first time
		else
			cfg.message = message
		end
		wesnoth.fire("message" , cfg) -- Show it as [message]
		local picked = wesnoth.get_variable("lua_repeating_message_option_chosen" .. tonumber(depth)) -- See what was picked
		-- Prevent it from being picked again if it's not disabled using [show_if]
		local has_show_if = false
		if picked == nil then -- Some error happened
			break
		end
		for i = 1,#cfg[picked][2] do
			if cfg[picked][2][i][1] == "show_if" then
				table.insert(cfg[picked][2][i][2], {"and" , { { "variable", { name="lua_repeating_message_do_repeat" .. tonumber(depth), equals=true }}}} )
				has_show_if = true
			end
		end
		if has_show_if == false then
			table.insert(cfg[picked][2], { "show_if" , { {"and" , { { "variable", { name="lua_repeating_message_do_repeat" .. tonumber(depth), equals=true }}}}}} )
		end
		if repetition == 1 then
			wesnoth.set_variable("first_view", nil) -- No longer the first view
		end
		-- Apply the functionality of the [break] tag here
		if stop[picked] == true then
			break
		end
		-- Repeat forever if options can repeat
		if repeat_options == true then
			length = length + 1
		end
	end

	-- Cleanup
	wesnoth.set_variable("lua_repeating_message_do_repeat" .. tonumber(depth), nil)
	wesnoth.set_variable("lua_repeating_message_option_chosen" .. tonumber(depth), nil)
	if depth == 0 then
		wesnoth.set_variable("lua_repeating_message_depth", nil)
	else
		wesnoth.set_variable("lua_repeating_message_depth", depth)
	end
end
