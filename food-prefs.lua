-- List all preferences of all dwarves in play
-- by k.stepanov
--[====[

food-prefs
===========
list dwarves preferences in food and ingridients in prepared food, with "grep PATTERN" list only preferences that match PATTERN
]====]

-- ---------------------------------------------------------------------------


-- returns fish id by mat type
-- due to mat_index in prefs is -1 
-- dfhack.matinfo.getToken fails to retrieve token
function get_fish_by_mat_type(mat_type)
	return df.global.world.raws.creatures.all[mat_type].creature_id
end


-- creates index in table for key if there is none
-- adds value
function accumulate (table, key, value)
	if table[key] == nil then
		table[key] = value
	else
		table[key] = table[key] + value
	end
end


-- food preferences for all citizens
function list_prefs_all_dwarves()
	prefs = {}
	for _,citizen in ipairs(df.global.world.units.active) do
		if dfhack.units.isCitizen(citizen) then
	--		print(dfhack.TranslateName(dfhack.units.getVisibleName(citizen)))
			for _, preference in ipairs(citizen.status.current_soul.preferences) do
				if preference.type == 2 then -- like food
					local token =  dfhack.matinfo.getToken(preference.mattype, preference.matindex)
					if preference.item_type == 48 then
						token = "FISH:"..get_fish_by_mat_type(preference.mattype)
					end
					accumulate(prefs, token, 1)

				end
			end	
		end
	end
end


-- counts available ingredients in meals grouped by ingredient material
function list_ingredients_in_meals()
	ingredients = {}
	for _, meal_stack in pairs(df.global.world.items.other.FOOD) do
		if 
		not meal_stack.flags.dump and
		not meal_stack.flags.forbid and
		not meal_stack.flags.garbage_collect and
		not meal_stack.flags.hostile and
		not meal_stack.flags.on_fire and
		not meal_stack.flags.rotten and
		not meal_stack.flags.trader and
		not meal_stack.flags.in_building and
		not meal_stack.flags.construction then
			for _,ingredient in pairs(meal_stack.ingredients) do
				local token =  dfhack.matinfo.getToken(ingredient.mat_type, ingredient.mat_index)
				if ingredient.item_type == 48 then
					token = "FISH:"..get_fish_by_mat_type(ingredient.mat_type)
				end
				accumulate(ingredients, token, meal_stack.stack_size)
			end
		end
	end
end


-- count available uncooked ingredients (edible uncooked or not) on map
-- generates two tables:
-- 	cookables:	table for ingredients owned by fortress
-- 	trade: 		table for ingredients owned by traders if there are any
function list_cookable()
	cookables = {}
	trade = {}
	local types = {"PLANT", "PLANT_GROWTH", "DRINK", "MEAT", "CHEESE", "LIQUID_MISC", "POWDER_MISC", "SEEDS", "GLOB", "EGG", "FISH"}
	for _, t in pairs(types) do
		for _, item in pairs(df.global.world.items.other[t]) do
			if 
			not item.flags.dump and
			not item.flags.forbid and
			not item.flags.garbage_collect and
			not item.flags.hostile and
			not item.flags.on_fire and
			not item.flags.rotten and
			not item.flags.in_building and
			not item.flags.construction then
				local token = ""
				if string.match(t, "EGG") then
					token = dfhack.matinfo.getToken(item.egg_materials.mat_type[1], item.egg_materials.mat_index[1])
					token = string.gsub(token, "EGG_WHITE", "EGG")
					print (token)
				else if string.match(t, "FISH") then
					token = "FISH:"..get_fish_by_mat_type(item.race)
				else
					token = dfhack.matinfo.getToken(item.mat_type, item.mat_index)
				end end
				
				if item.flags.trader then
					accumulate(trade, token, item.stack_size)
				else
					accumulate(cookables, token, item.stack_size)
				end
			end
		end
	end
end


-- if item can be cooked from item owned by fortress
function find_precursors()
	precursors = {}
	local precursor_table = {
		[":CHEESE"] = ":MILK",
		[":MILL"] = ":STRUCTURAL",
		[":OIL"] = ":STRUCTURAL",
		[":DRINK"] = ":STRUCTURAL",
		["DRINK"] = "FRUIT"
	}
	for tag, _ in pairs(prefs) do
		for product, precursor in pairs(precursor_table) do
			if string.find(tag, product) then
				local new_tag = string.gsub(tag, product, precursor)
				if cookables[new_tag] then
					precursors[tag] = cookables[new_tag]
				end
			end
		end
	end
end


-- if item can be grown from seeds owned by fortress
function find_seeds()
	seeds = {}
	for tag, _ in pairs(prefs) do
		if string.match(tag, "^PLANT:.+") then
			local new_tag = string.gsub(tag, string.match(tag, "^PLANT:[%w_-]+:(.+)"), "SEED")
			seeds[tag] = cookables[new_tag]
		end
	end
end


-- print formatted table row
function print_row(k)
	print(string.format("%-40s | %9s | %9s | %9s | %9s | %9s | %9s |",
		k,
		prefs[k], 
		ingredients[k] or '',
		cookables[k] or '',
		precursors[k] or '',
		seeds[k] or '',
		trade[k] or ''))
end
	

-- ---------------------------------------------------------------------------
-- main script operation starts here
-- ---------------------------------------------------------------------------
	local args = {...}
	local cmd = args[1]
	list_prefs_all_dwarves()
	list_ingredients_in_meals()
	list_cookable()
	find_precursors()
	find_seeds()
	local tkeys = {}
	for k in pairs(prefs) do table.insert(tkeys, k) end
	table.sort(tkeys)
	local summary = {}

	print(string.format("%-40s | %9s | %9s | %9s | %9s | %9s | %9s |","tag", "prefs", "in meals", "raw", "precursor", "seeds", "in trade"))
	for _, k in ipairs(tkeys) do 
		if cmd and cmd == "grep" then
			if string.match(k,args[2]) then
				print_row(k)
			end			
		else
			print_row(k)
		end
	end
