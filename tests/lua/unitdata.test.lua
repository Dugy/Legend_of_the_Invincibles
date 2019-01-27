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
	local expected = wml.tostring(expected_wml)
	local actual = wml.tostring(actual_wml)

	assert(expected == actual, "WML table is different from expected:\n" ..
		"Expected: " .. expected .. "\n" .. "Actual:   " .. actual)
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

-- Check the add/list sequence of functions like add_advancement().
-- Parameters:
-- unit - main test unit (first parameter to API functions), can be either WML table or unit ID.
-- iter_fn - name of iterator (e.g. "advancements"),
-- add_fn - name of add function (e.g. "add_advancement"),
-- array_of_things_to_add - array of arguments of add_fn() function (e.g. advancement names, or item number/sort).
-- expected_results - expected contents of iterator after all add_fn() calls. This is passed to test_iterator().
local function test_add_list(unit, iter_fn, add_fn, array_of_things_to_add, expected_results)
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
		
	tests['add/list advancements' .. subtest_name] = function()
		test_add_list(get_unit(), "advancements", "add_advancement",
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
	
	tests['remove/list advancements' .. subtest_name] = function()
		local unit
	
		-- Prepare a unit who already has some advancements
		-- (so that we can test remove_advancement() on this unit)
		local function prepare_unit()
			unit = get_unit()
			
			loti.unit.add_advancement(unit, "fireball1_incineration")
			loti.unit.add_advancement(unit, "LotF1")
			loti.unit.add_advancement(unit, "resist_fire1")
		end
		
		-- Try deleting the first advancement.
		prepare_unit()
		loti.unit.remove_advancement(unit, "fireball1_incineration")
		test_iterator(unit, "advancements", {
			function(result) assert(result.id == "LotF1") end,
			function(result) assert(result.id == "resist_fire1") end,
		})
		
		-- Try deleting advancement in the middle.
		prepare_unit()
		loti.unit.remove_advancement(unit, "LotF1")
		test_iterator(unit, "advancements", {
			function(result) assert(result.id == "fireball1_incineration") end,
			function(result) assert(result.id == "resist_fire1") end,
		})
		
		-- Try deleting the last advancement.
		prepare_unit()
		loti.unit.remove_advancement(unit, "resist_fire1")
		test_iterator(unit, "advancements", {
			function(result) assert(result.id == "fireball1_incineration") end,
			function(result) assert(result.id == "LotF1") end,
		})
		
		-- Try deleting the non-existent advancement.
		prepare_unit()
		loti.unit.remove_advancement(unit, "fireball")
		test_iterator(unit, "advancements", {
			function(result) assert(result.id == "fireball1_incineration") end,
			function(result) assert(result.id == "LotF1") end,
			function(result) assert(result.id == "resist_fire1") end,
		})
	end
		
	tests['add/list items' .. subtest_name] = function()
		test_add_list(get_unit(), "items", "add_item",
			{ { 100, "sword" }, { 327 }, { 562, "spear" }, { 535, "armour" }, { 535, "gauntlets" } },
			{
				loti.item.type[100],
				loti.item.type[327],
				function(result)
					-- Crafted weapon.
					-- Its item sort (in this case, spear) must be different from default.
					assert(result.sort == "spear")
					
					-- All other fields should be the same as in loti.item.type.
					result.sort = "weaponword"
					assert_wml_equals(loti.item.type[562], result)
				end,
				
				function(result)
					-- Crafted armour (chest).
					assert(result.sort == "armour")
					
					-- All other fields should be the same as in loti.item.type.
					result.sort = "armourword"
					assert_wml_equals(loti.item.type[535], result)
				end,
				
				function(result)
					-- Crafted non-chest armour (in this case, a gauntlets).
					assert(result.sort == "gauntlets")
					
					-- Note: result doesn't have its defence multiplied by 1/3 (yet),
					-- because this is done by update_stats() later.
					result.sort = "armourword"
					assert_wml_equals(loti.item.type[535], result)
				end,
			}
		)
	end
	
	tests['remove/list items' .. subtest_name] = function()
		local unit, expected_array
	
		-- Prepare a unit who already has some items
		-- (so that we can test remove_item() on this unit)
		local function prepare_unit()
			unit = get_unit()
			
			loti.unit.add_item(unit, 100, "sword") -- Cunctator's sword
			loti.unit.add_item(unit, 327) -- Eidolon's Coat
			loti.unit.add_item(unit, 535, "armour")
			loti.unit.add_item(unit, 535, "gauntlets")
			loti.unit.add_item(unit, 562, "spear")
		end
		
		-- Correct value that should pass test_iterator() check before making any remove_item() calls.
		local original_array = {
			function(result) assert(result.number == 100 and result.sort == "sword") end,
			function(result) assert(result.number == 327 and result.sort == "cloak") end,
			function(result) assert(result.number == 535 and result.sort == "armour") end,
			function(result) assert(result.number == 535 and result.sort == "gauntlets") end,
			function(result) assert(result.number == 562 and result.sort == "spear") end,
		}
		
		-- Double-check that certain item (from "original_array" list, see above)
		-- is not present on the unit, and that all other items from "original_array" are present,
		-- Throw exception if this statement is incorrect.
		-- Parameter: index - index of the item in "original_array" that should have been deleted.
		-- Note: if index is false/nil, then NONE of the items are expected to be deleted.
		local function assert_item_was_deleted(index)
			local expected_array = table.pack(table.unpack(original_array)) -- Clone the original array
			if index then
				table.remove(expected_array, index)
			end
				
			test_iterator(unit, "items", expected_array)			
		end
		
		-- Before we start testing remove_item(),
		-- let's double-check that "original_array" is correct.
		prepare_unit()
		test_iterator(unit, "items", original_array)

		-- Try deleting non-crafted item. Don't provide item_sort parameter (which is optional).
		prepare_unit()
		loti.unit.remove_item(unit, 100)
		assert_item_was_deleted(1)
		
		-- Try deleting non-crafted item, but provide item_sort parameter (which is optional).
		prepare_unit()
		loti.unit.remove_item(unit, 100, "sword")
		assert_item_was_deleted(1)
		
		-- Try deleting non-crafted item, but provide incorrect item_sort parameter.
		-- This shouldn't delete anything (because item with this item_sort doesn't exist).
		prepare_unit()
		loti.unit.remove_item(unit, 100, "mace")
		assert_item_was_deleted(false)
		
		-- Try deleting item which is not present on the unit (without item_sort).
		-- This shouldn't delete anything.
		prepare_unit()
		loti.unit.remove_item(unit, 123)
		assert_item_was_deleted(false)
		
		-- Try deleting item which is not present on the unit
		-- (but specify item_sort, which is the same as item_sort of one of the present items).
		-- This shouldn't delete anything.
		prepare_unit()
		loti.unit.remove_item(unit, 123, "sword")
		assert_item_was_deleted(false)		
		
		-- Try deleting non-first item in the list (with optional item_sort)
		prepare_unit()
		loti.unit.remove_item(unit, 327, "cloak")
		assert_item_was_deleted(2)
		
		-- Try deleting non-first item in the list (without optional item_sort)
		prepare_unit()
		loti.unit.remove_item(unit, 327)
		assert_item_was_deleted(2)

		-- Try deleting crafted item without item_sort parameter.
		prepare_unit()
		loti.unit.remove_item(unit, 562)
		assert_item_was_deleted(5)
		
		-- Try deleting crafted item with item_sort parameter.
		prepare_unit()
		loti.unit.remove_item(unit, 562, "spear")
		assert_item_was_deleted(5)
		
		-- Try deleting crafted item, but provide incorrect item_sort parameter.
		-- This shouldn't delete anything.
		prepare_unit()
		loti.unit.remove_item(unit, 562, "thunderstick")
		assert_item_was_deleted(false)
		
		-- Try deleting crafted item without item_sort parameter,
		-- when there are TWO items with this item_number.
		-- Only one (the first one) should be deleted.
		prepare_unit()
		loti.unit.remove_item(unit, 535)
		assert_item_was_deleted(3)
		
		-- Try deleting crafted item with item_sort parameter,
		-- when there are TWO items with this item_number.
		-- Only one (the one with correct item_sort) should be deleted.
		prepare_unit()
		loti.unit.remove_item(unit, 535, "armour")
		assert_item_was_deleted(3)
		
		prepare_unit()
		loti.unit.remove_item(unit, 535, "gauntlets")
		assert_item_was_deleted(4)
	end

	tests['list effects on empty unit' .. subtest_name] = function()
		test_iterator(get_unit(), "effects", {})
	end
end

-- Provide the list of tests, will be used by loti.testsuite().
return tests
