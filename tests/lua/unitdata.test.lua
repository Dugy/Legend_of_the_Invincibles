-- Automated test for [unitdata.lua] library.

-- Returns a new unit (WML table) for further testing.
local function newunit()
	return wesnoth.create_unit { type = "Efraim_lich" }.__cfg
end

-- Throw an exception if expected_wml isn't equal to actual_wml.
local function assert_wml_equals(expected_wml, actual_wml)
	wesnoth.set_variable("__tmp_compare_var1", expected_wml)
	wesnoth.set_variable("__tmp_compare_var2", actual_wml)
	local is_equal = wesnoth.eval_conditional {
		{ "variable", { name = "__tmp_compare_var1", equals = "$__tmp_compare_var1" } }
	}

	-- Clean the temporary variables
	wesnoth.set_variable("__tmp_compare_var1", nil)
	wesnoth.set_variable("__tmp_compare_var2", nil)

	assert(is_equal, "WML table is different from expected.")
end

-- Call iterator-returning function (e.g. "advancements") on unit (either WML table or ID)
-- and compare the results with a known correct result (provided as array).
local function test_iterator(unit, api_function_name, expected_array)
	-- When error happens, this string will be shown to tell which function failed.
	local where = "loti.unit." .. api_function_name .. "()"

	-- Obtain the iterator and check it.
	local iterator = loti.unit[api_function_name](unit)
	assert(type(iterator) == "function", where .. " returned non-iterator")

	-- Retrieve all results.
	local obtained_array = {}
	for _, elem in iterator do
		table.insert(obtained_array, elem)
	end

	assert(#expected_array == #obtained_array,
		where .. " returned " .. #obtained_array .. " elements (expected: " .. #expected_array .. ")")

	for idx in ipairs(obtained_array) do
		assert_wml_equals(expected_array[idx], obtained_array[idx])
	end
end

return {
	['list items on empty unit'] = function()
		test_iterator(newunit(), "items", {})
	end,

	['list advancements on empty unit'] = function()
		test_iterator(newunit(), "advancements", {})
	end,

	['list effects on empty unit'] = function()
		test_iterator(newunit(), "effects", {})
	end,

	-- TODO: add/delete various items/advancements/effects
	-- and then use test_iterator() to compare the results with expected.
}
