-- Automated test for [unitdata.lua] library.

-- Returns a new unit (WML table) for further testing.
local function newunit()
	local unit = wesnoth.create_unit { type = "Efraim_god" }

	-- Unit must be on the map for tests, otherwise wesnoth.get_unit() won't find it by ID.
	unit:to_map(1, 1)

	return unit.__cfg
end

-- Throw an exception if expected_wml isn't equal to actual_wml.
local function assert_wml_equals(expected_wml, actual_wml)
	wesnoth.set_variable("__tmp_compare_var1", expected_wml)
	wesnoth.set_variable("__tmp_compare_var2", actual_wml)
	local is_equal = wesnoth.eval_conditional {
		{ "variable", { name = "__tmp_compare_var1", equals = "$__tmp_compare_var2" } }
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

	for idx in ipairs(expected_array) do
		assert_wml_equals(expected_array[idx], obtained_array[idx])
	end
end

-- Check the add/remove/list sequence of functions like add_advancement().
-- Parameters:
-- unit - main test unit (first parameter to API functions), can be either WML table or unit ID.
-- iter_fn - name of iterator (e.g. "advancements"),
-- add_fn - name of add function (e.g. "add_advancement"),
-- remove_fn - name of remove function (e.g. "remove_advancement"),
-- array_of_things_to_add - array of test values (e.g. advancement names) to pass to add_fn() and test_iterator().
local function test_add_remove(unit, iter_fn, add_fn, remove_fn, array_of_things_to_add)
	-- Test the empty iterator. Should be valid and should provide an empty list.
	test_iterator(unit, iter_fn, {})

	-- Add the test objects (whatever they are - item WML tables, advancement IDs, doesn't matter).
	for _, object in ipairs(array_of_things_to_add) do
		loti.unit[add_fn](unit, object)
	end

	-- Compare current state of unit (e.g. items on unit) with array of what we just added.
	test_iterator(unit, iter_fn, array_of_things_to_add)

	-- TODO: test remove
end

return {
	['add/remove/list advancements (on WML table))'] = function()
		test_add_remove(newunit(), "advancements", "add_advancement", "remove_advancement",
			{ "fireball1_incineration", "LotF1", "resist_fire1" } )
	end,

	['add/remove/list advancements (on unit ID))'] = function()
		test_add_remove(newunit().id, "advancements", "add_advancement", "remove_advancement",
			{ "fireball1_incineration", "LotF1", "resist_fire1" } )
	end,

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
