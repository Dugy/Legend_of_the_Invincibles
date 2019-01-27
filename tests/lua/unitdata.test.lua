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
		local expected = expected_array[idx]
		local obtained = obtained_array[idx]
		
		if type(expected) == "function" then
			-- Callback to check the results
			expected(obtained)
		else
			-- Exact value of the result, compare directly.
			assert_wml_equals(expected, obtained)
		end
	end
end

-- Check the add/remove/list sequence of functions like add_advancement().
-- Parameters:
-- unit - main test unit (first parameter to API functions), can be either WML table or unit ID.
-- iter_fn - name of iterator (e.g. "advancements"),
-- add_fn - name of add function (e.g. "add_advancement"),
-- remove_fn - name of remove function (e.g. "remove_advancement"),
-- array_of_things_to_add - array of arguments of add_fn() function (e.g. advancement names, or item number/sort).
-- expected_results - expected contents of iterator after all add_fn() calls. This is passed to test_iterator().
local function test_add_remove(unit, iter_fn, add_fn, remove_fn, array_of_things_to_add, expected_results)
	-- Test the empty iterator. Should be valid and should provide an empty list.
	test_iterator(unit, iter_fn, {})

	-- Add the test objects (whatever they are - item WML tables, advancement IDs, doesn't matter).
	for _, add_arguments in ipairs(array_of_things_to_add) do
		loti.unit[add_fn](unit, table.unpack(add_arguments))
	end

	-- Compare current state of unit (e.g. items on unit) with array of what we just added.
	test_iterator(unit, iter_fn, expected_results)

	-- TODO: test remove
end

-- Prepare array of tests.
local tests = {}

-- Functions should equally accept both WML table and ID (string) of the unit.
for unit_form, get_unit in pairs({
	['WML table'] = newunit,
	['unit ID'] = function() return newunit().id end
}) do
	local subtest_name = ' (on ' .. unit_form .. ')'
		
	tests['add/remove/list advancements' .. subtest_name] = function()
		test_add_remove(get_unit(), "advancements", "add_advancement", "remove_advancement",
			-- Note: all these advancements must be valid for the test unit
			-- (in this case, Efraim_god),
			-- because add_advancement() won't add unknown advancements.
			{ { "fireball1_incineration" }, { "LotF1" }, { "resist_fire1" } },
			
			-- Check each returned value with an evaluation callback.
			{
				function(result)				
					assert(result.id == "fireball1_incineration")
					assert(result.strict_amla)
					assert(result.require_amla == "fireball")
				end,
				function(result) assert(result.id == "LotF1") end,
				function(result) assert(result.id == "resist_fire1") end,
			}
		)
	end
		
	tests['add/remove/list items' .. subtest_name] = function()
		test_add_remove(get_unit(), "items", "add_item", "remove_item",
			{ { 100, "sword" }, { 327 }, { 562, "spear" } },
			{ loti.item.type[100], loti.item.type[327], loti.item.type[562] }
		)
	end

	tests['list effects on empty unit' .. subtest_name] = function()
		test_iterator(get_unit(), "effects", {})
	end
end

-- Provide the list of tests, will be used by loti.testsuite().
return tests
