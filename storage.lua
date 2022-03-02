local utils = ...
local S = utils.S



local function unit_after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"formspec_version[3]"..
	"size[11.75,12.25,false]"..
	"list[context;main;1.0,1.0;8,4;]"..
	"list[current_player;main;1.0,6.5;8,4;]"..
	"listring[]"

	meta:set_string ("inventory", "{ main = { } }")
	meta:set_string ("formspec", spec)

	local inv = meta:get_inventory ()

	inv:set_size ("main", 32)
	inv:set_width ("main", 8)

	-- If return true no item is taken from itemstack
	return false
end



local function unit_after_place_node_locked (pos, placer, itemstack, pointed_thing)
	unit_after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Storage Unit (owned by "..placer:get_player_name ()..")")
	end

	-- If return true no item is taken from itemstack
	return false
end



local function unit_can_dig (pos, player)
	if not utils.can_interact_with_node (pos, player) then
		return false
	end

	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			if not inv:is_empty ("main") then
				return false
			end
		end
	end

	return true
end



local function unit_on_blast (pos, intensity)
	local meta = minetest.get_meta (pos)

	if meta then
		if intensity >= 1.0 then
			local inv = meta:get_inventory ()

			if inv then
				local slots = inv:get_size ("main")

				for slot = 1, slots do
					local stack = inv:get_stack ("main", slot)

					if stack and not stack:is_empty () then
						if math.floor (math.random (0, 5)) == 3 then
							utils.item_drop (stack, nil, pos)
						else
							utils.on_destroy (stack)
						end
					end
				end
			end

			on_destruct (pos)
			minetest.remove_node (pos)

		else -- intensity < 1.0
			local inv = meta:get_inventory ()

			if inv then
				local slots = inv:get_size ("main")

				for slot = 1, slots do
					local stack = inv:get_stack ("main", slot)

					if stack and not stack:is_empty () then
						utils.item_drop (stack, nil, pos)
					end
				end
			end

			local node = minetest.get_node_or_nil (pos)
			if node then
				local items = minetest.get_node_drops (node, nil)

				if items and #items > 0 then
					local stack = ItemStack (items[1])

					if stack then
						preserve_metadata (pos, node, meta, { stack })
						utils.item_drop (stack, nil, pos)
						on_destruct (pos)
						minetest.remove_node (pos)
					end
				end
			end
		end
	end
end



local function unit_on_rightclick (pos, node, clicker, itemstack, pointed_thing)
	if not utils.can_interact_with_node (pos, clicker) then
		if clicker and clicker:is_player () then
			local owner = "<unknown>"
			local meta = minetest.get_meta (pos)

			if meta then
				owner = meta:get_string ("owner")
			end

			local spec =
			"formspec_version[3]"..
			"size[8.0,4.0,false]"..
			"label[1.0,1.0;Owned by "..minetest.formspec_escape (owner).."]"..
			"button_exit[3.0,2.0;2.0,1.0;close;Close]"

			minetest.show_formspec (clicker:get_player_name (),
											"lwcomponents:component_privately_owned",
											spec)
		end
	end

	return itemstack
end




minetest.register_node("lwcomponents:storage_unit", {
	description = S("Storage Unit"),
	drawtype = "glasslike_framed",
	tiles = { "lwcomponents_storage_framed.png", "lwcomponents_storage.png" },
	is_ground_content = false,
	groups = { choppy = 2 },
	sounds = default.node_sound_wood_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,

	after_place_node = unit_after_place_node,
	can_dig = unit_can_dig,
	on_blast = unit_on_blast,
	on_rightclick = unit_on_rightclick
})



minetest.register_node("lwcomponents:storage_unit_locked", {
	description = S("Storage Unit (locked)"),
	drawtype = "glasslike_framed",
	tiles = { "lwcomponents_storage_framed.png", "lwcomponents_storage.png" },
	is_ground_content = false,
	groups = { choppy = 2 },
	sounds = default.node_sound_wood_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,

	after_place_node = unit_after_place_node_locked,
	can_dig = unit_can_dig,
	on_blast = unit_on_blast,
	on_rightclick = unit_on_rightclick
})



local consolidation_interval = 20



local function unit_inventory (pos, owner, inv_list)
	local node = utils.get_far_node (pos)

	if node and (node.name == "lwcomponents:storage_unit" or
					 node.name == "lwcomponents:storage_unit_locked") then

		local meta = minetest.get_meta (pos)
		local uowner = meta:get_string ("owner")

		if meta and (owner == uowner or uowner == "") then
			local inv = meta:get_inventory ()

			if inv then
				local slots = inv:get_size ("main")

				for slot = 1, slots, 1 do
					local stack = inv:get_stack ("main", slot)

					if stack and not stack:is_empty () then
						local copy = ItemStack (stack)
						copy:set_count (1)
						local name = copy:to_string ()
						local item = inv_list[name]

						if not item then
							inv_list[name] = { count = 0 }
							item = inv_list[name]
						end

						item[#item + 1] =
						{
							pos = vector.new (pos),
							count = stack:get_count (),
							slot = slot
						}

						item.count = item.count + stack:get_count ()
					end
				end
			end

			return true
		end
	end

	return false
end



local function inventory_searcher (pos, owner, coords, inv_list, check_list)
	local spos = minetest.pos_to_string (pos, 0)

	if not check_list[spos] then
		check_list[spos] = true

		if unit_inventory (pos, owner, inv_list) then
			for _, c in ipairs (coords) do
				inventory_searcher (vector.add (pos, c), owner, coords, inv_list, check_list)
			end
		end
	end
end



local function get_inventory_list (pos)
	local inv_list = { }
	local meta = minetest.get_meta (pos)

	if meta then
		local owner = meta:get_string ("owner")
		local check_list = { [minetest.pos_to_string (pos, 0)] = true }
		local coords =
		{
			{ x =  1, y =  0, z =  0 },
			{ x = -1, y =  0, z =  0 },
			{ x =  0, y =  1, z =  0 },
			{ x =  0, y = -1, z =  0 },
			{ x =  0, y =  0, z =  1 },
			{ x =  0, y =  0, z = -1 }
		}

		for _, c in ipairs (coords) do
			inventory_searcher (vector.add (pos, c), owner, coords, inv_list, check_list)
		end
	end

	return inv_list
end



local function count_table_keys (t)
	local count = 0

	for k, v in pairs (t) do
		count = count + 1
	end

	return count
end



local function get_stock_list (pos)
	local inv_list = get_inventory_list (pos)
	local list = { }

	for k, v in pairs (inv_list) do
		local stack = ItemStack (k)
		local name = stack:get_name ()
		local description = nil
		local custom = false
		local pallet_index = nil
		local tstack = stack:to_table ()

		if tstack and tstack.meta and count_table_keys (tstack.meta) > 0 then
			custom = true
			pallet_index = tstack.meta.palette_index
		end

		if stack:get_short_description () ~= "" then
			description = stack:get_short_description ()
		elseif stack:get_description () ~= "" then
			description = stack:get_description ()
		else
			description = name

			local def = utils.find_item_def (name)

			if def then
				if def.short_description then
					description = def.short_description
				elseif def.description then
					description = def.description
				end
			end
		end

		list[#list + 1] =
		{
			name = stack:get_name (),
			description = utils.unescape_description (description),
			id = k,
			count = v.count,
			custom = custom,
			pallet_index = pallet_index,
		}
	end

	return list
end



local function output_items (pos, name, count)
	if count < 1 then
		return 0
	end

	local meta = minetest.get_meta (pos)

	if not meta then
		return 0
	end

	local inv = meta:get_inventory ()

	if not inv then
		return 0
	end

	local stack = ItemStack (name)

	if stack:get_stack_max () < count then
		count = stack:get_stack_max ()
	end

	stack:set_count (count)

	while stack:get_count () > 0 do
		if inv:room_for_item ("output", stack) then
			break
		else
			stack:set_count (stack:get_count () - 1)
		end
	end

	if stack:get_count () < 1 then
		return 0
	end

	local inv_list = get_inventory_list (pos)
	local item = inv_list[name]
	local left = stack:get_count ()

	if item then
		for i = #item, 1, -1 do
			local tmeta = minetest.get_meta (item[i].pos)
			local tinv = (tmeta and tmeta:get_inventory ()) or nil

			if tinv then
				local s = tinv:get_stack ("main", item[i].slot)

				if utils.is_same_item (name, s) then
					if s:get_count () > left then
						s:set_count (s:get_count () - left)
						tinv:set_stack ("main", item[i].slot, s)
						left = 0
					else
						tinv:set_stack ("main", item[i].slot, nil)
						left = left - s:get_count ()
					end
				end

				if left == 0 then
					break
				end

			end
		end
	end

	if left < count then
		local output = ItemStack (name)

		output:set_count (count - left)
		inv:add_item ("output", output)

		return count - left
	end

	return 0
end



local function consolidate_itemstacks (item1, item2)
	local copy1 = ItemStack (item1)
	local copy2 = ItemStack (item2)

	if utils.is_same_item (copy1, copy2) then
		local count = copy1:get_stack_max () - copy1:get_count ()

		if count > copy2:get_count () then
			count = copy2:get_count ()
		end

		if count > 0 then
			copy1:set_count (copy1:get_count () + count)
			copy2:set_count (copy2:get_count () - count)

			if copy2:get_count () < 1 then
				copy2 = nil
			end
		end
	end

	return copy1, copy2
end



local function consolidate_stock (pos)
	local inv_list = get_inventory_list (pos)

	for k, v in pairs (inv_list) do
		if #v > 1 then
			for i = #v, 2, -1 do
				local smeta = minetest.get_meta (v[i].pos)
				local sinv = (smeta and smeta:get_inventory ()) or nil

				if sinv then
					local src = sinv:get_stack ("main", v[i].slot)

					if src and not src:is_empty () then
						for j = 1, i - 1, 1 do
							local dmeta = minetest.get_meta (v[j].pos)
							local dinv = (dmeta and dmeta:get_inventory ()) or nil

							if dinv then
								local dest = dinv:get_stack ("main", v[j].slot)

								dest, src = consolidate_itemstacks (dest, src)
								dinv:set_stack ("main", v[j].slot, dest)
							end

							if not src or src:is_empty () then
								break
							end
						end
					end

					sinv:set_stack ("main", v[i].slot, src)
				end
			end
		end
	end
end



local function check_consolidation (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local count = meta:get_int ("input_count") + 1

		if count >= consolidation_interval then
			meta:set_int ("input_count", 0)

			minetest.after (0.1, consolidate_stock, vector.new (pos))
		else
			meta:set_int ("input_count", count)
		end
	end
end



local function check_filter (pos, itemstack)
	local stack = ItemStack (itemstack)

	if stack and not stack:is_empty () then
		local meta = minetest.get_meta (pos)

		if meta then
			local inv = meta:get_inventory ()

			if inv then
				if inv:is_empty ("filter") then
					return true
				end

				local slots = inv:get_size ("filter")
				for i = 1, slots, 1 do
					local s = inv:get_stack ("filter", i)

					if s and not s:is_empty () and
						s:get_name () == stack:get_name () then

						return true
					end
				end
			end
		end
	end

	return false
end



local function unit_placer (pos, owner, stack)
	local node = utils.get_far_node (pos)

	if node and (node.name == "lwcomponents:storage_unit" or
					 node.name == "lwcomponents:storage_unit_locked") then

		local meta = minetest.get_meta (pos)
		local uowner = meta:get_string ("owner")

		if meta and (owner == uowner or uowner == "") then
			local inv = meta:get_inventory ()

			if inv then
				local left = inv:add_item ("main", stack)

				if not left or left:is_empty () or left:get_count () == 0 then
					return false, nil
				end

				return true, left
			end
		end
	end

	return false, stack
end



local function inventory_placer (pos, owner, coords, stack, check_list)
	local spos = minetest.pos_to_string (pos, 0)

	if not check_list[spos] then
		check_list[spos] = true

		local continue, left = unit_placer (pos, owner, stack)

		if continue and left then
			for _, c in ipairs (coords) do
				left = inventory_placer (vector.add (pos, c), owner, coords, left, check_list)

				if not left then
					break
				end
			end
		end

		return left
	end

	return stack
end



local function input_item (pos, itemstack)
	local stack = ItemStack (itemstack)

	if stack and not stack:is_empty () and
		check_filter (pos, itemstack) then

		local meta = minetest.get_meta (pos)

		if meta then
			local owner = meta:get_string ("owner")
			local check_list = { [minetest.pos_to_string (pos, 0)] = true }
			local coords =
			{
				{ x =  1, y =  0, z =  0 },
				{ x = -1, y =  0, z =  0 },
				{ x =  0, y =  1, z =  0 },
				{ x =  0, y = -1, z =  0 },
				{ x =  0, y =  0, z =  1 },
				{ x =  0, y =  0, z = -1 }
			}

			for _, c in ipairs (coords) do
				stack = inventory_placer (vector.add (pos, c), owner, coords, stack, check_list)

				if not stack then
					break
				end
			end
		end

		check_consolidation (pos)
	end

	return stack
end



local function store_input (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			local slots = inv:get_size ("input")

			for slot = 1, slots, 1 do
				local stack = inv:get_stack ("input", slot)

				if stack and not stack:is_empty () then
					local left = input_item (pos, stack)

					if left then
						left = inv:add_item ("output", left)
					end

					inv:set_stack ("input", slot, left)
				end
			end
		end
	end
end



local function store_input_delayed (pos)
	minetest.after (0.1, store_input, pos)
end



local function search_filter (name, terms)
	if terms then
		for _, t in ipairs (terms) do
			if (name:lower ():find (t, 1, true)) then
				return true
			end
		end

		return false
	end

	return true
end



local function get_formspec_list (pos)
	local inv_list = get_inventory_list (pos)
	local list = { }

	for k, v in pairs (inv_list) do
		local description = k
		local stack = ItemStack (k)
		local smeta = stack:get_meta ()


		if stack:get_short_description () ~= "" then
			description = stack:get_short_description ()
		elseif stack:get_description () ~= "" then
			description = stack:get_description ()
		else
			local def = utils.find_item_def (stack:get_name ())

			if def then
				if def.short_description then
					description = def.short_description
				elseif def.description then
					description = def.description
				end
			end
		end

		list[#list + 1] =
		{
			item = k,
			description = utils.unescape_description (description),
			count = v.count
		}
	end

	table.sort (list , function (e1, e2)
		return (e1.description:lower () < e2.description:lower ())
	end)

	return list
end



local function indexer_get_formspec (pos, search)
	local inv_list = get_formspec_list (pos)

	search = search or ""

	local terms = { }
	for w in string.gmatch(search, "[^%s]+") do
		terms[#terms + 1] = string.lower (w)
	end

	if #terms < 1 then
		terms = nil
	end

	local index = ""
	local count = 0
	local top = 0
	for _, v in ipairs (inv_list) do
		if search_filter (v.description, terms) then
			local stack = ItemStack (v.item)
			local max_stack = stack:get_stack_max ()
			local descr_esc = minetest.formspec_escape (v.description)
			local item =
			string.format ("item_image_button[0.0,%0.2f;1.0,1.0;%s;01_%s;]",
								top, v.item, v.item)

			if max_stack >= 10 then
				item = item..
				string.format ("button[1.0,%0.2f;1.0,1.0;10_%s;10]",
									top, v.item)
			end

			if max_stack > 1 then
				item = item..
				string.format ("button[2.0,%0.2f;1.0,1.0;ST_%d_%s;%d]",
									top, max_stack, v.item, max_stack)
			end

			item = item..
			string.format ("label[3.1,%0.2f;%d]"..
								"label[4.4,%0.2f;%s]",
								top + 0.5, v.count,
								top + 0.5, descr_esc)

			index = index..item

			top = top + 1.0
			count = count + 1
		end
	end

	local scroll_height = ((count < 12 and 0) or (count - 11)) * 10
	local thumb_size = (count < 12 and 11) or (scroll_height * (11 / count))

	if thumb_size < (scroll_height / 10) then
		thumb_size = scroll_height / 10
	end

	local spec =
	string.format ("formspec_version[3]"..
						"size[21.75,14.5,false]"..
						"field[1.0,1.21;7.5,0.8;search_field;;%s]\n"..
						"field_close_on_enter[search_field;false]"..
						"button[8.5,1.21;2.0,0.8;search;Search]\n"..
						"scrollbaroptions[min=0;max=%d;smallstep=10;largestep=100;thumbsize=%d;arrows=default]"..
						"scrollbar[10.0,2.5;0.5,11.0;vertical;index_scrollbar;0-%d]"..
						"scroll_container[1.0,2.5;9.0,11.0;index_scrollbar;vertical;0.1]"..
						"%s"..
						"scroll_container_end[]"..
						"field[11.0,1.21;3.0,0.8;channel;Channel;${channel}]\n"..
						"field_close_on_enter[channel;false]"..
						"button[14.0,1.21;1.5,0.8;setchannel;Set]\n"..
						"label[11.0,3.6;Input]"..
						"list[context;input;11.0,3.8;2,2;]"..
						"listring[context;output]"..
						"label[16.0,1.0;Output]"..
						"list[context;output;16.0,1.25;4,4;]"..
						"listring[current_player;main]"..
						"label[11.0,6.75;Filter]"..
						"list[context;filter;11.0,7.0;8,1;]"..
						"list[current_player;main;11.0,8.75;8,4;]"..
						"listring[context;input]",
						search,
						scroll_height,
						thumb_size,
						scroll_height,
						index)

	return spec
end



local function indexer_after_place_base (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)

	meta:set_string ("inventory", "{ input = { }, output = { }, filter = { } }")
	meta:set_string ("formspec", indexer_get_formspec (pos))

	local inv = meta:get_inventory ()

	inv:set_size ("input", 4)
	inv:set_width ("input", 2)
	inv:set_size ("output", 16)
	inv:set_width ("output", 4)
	inv:set_size ("filter", 8)
	inv:set_width ("filter", 2)
end



local function indexer_after_place_node (pos, placer, itemstack, pointed_thing)
	indexer_after_place_base (pos, placer, itemstack, pointed_thing)
	utils.pipeworks_after_place (pos)

	-- If return true no item is taken from itemstack
	return false
end



local function indexer_after_place_node_locked (pos, placer, itemstack, pointed_thing)
	indexer_after_place_base (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Storage Indexer (owned by "..placer:get_player_name ()..")")
	end

	utils.pipeworks_after_place (pos)

	-- If return true no item is taken from itemstack
	return false
end



local function indexer_can_dig (pos, player)
	if not utils.can_interact_with_node (pos, player) then
		return false
	end

	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			if not inv:is_empty ("input") then
				return false
			end

			if not inv:is_empty ("output") then
				return false
			end
		end
	end

	return true
end



local function indexer_on_blast (pos, intensity)
	local meta = minetest.get_meta (pos)

	if meta then
		if intensity >= 1.0 then
			local inv = meta:get_inventory ()

			if inv then
				local slots = inv:get_size ("input")

				for slot = 1, slots do
					local stack = inv:get_stack ("input", slot)

					if stack and not stack:is_empty () then
						if math.floor (math.random (0, 5)) == 3 then
							utils.item_drop (stack, nil, pos)
						else
							utils.on_destroy (stack)
						end
					end
				end

				slots = inv:get_size ("output")

				for slot = 1, slots do
					local stack = inv:get_stack ("output", slot)

					if stack and not stack:is_empty () then
						if math.floor (math.random (0, 5)) == 3 then
							utils.item_drop (stack, nil, pos)
						else
							utils.on_destroy (stack)
						end
					end
				end
			end

			on_destruct (pos)
			minetest.remove_node (pos)

		else -- intensity < 1.0
			local inv = meta:get_inventory ()

			if inv then
				local slots = inv:get_size ("input")

				for slot = 1, slots do
					local stack = inv:get_stack ("input", slot)

					if stack and not stack:is_empty () then
						utils.item_drop (stack, nil, pos)
					end
				end

				slots = inv:get_size ("output")

				for slot = 1, slots do
					local stack = inv:get_stack ("output", slot)

					if stack and not stack:is_empty () then
						utils.item_drop (stack, nil, pos)
					end
				end
			end

			local node = minetest.get_node_or_nil (pos)
			if node then
				local items = minetest.get_node_drops (node, nil)

				if items and #items > 0 then
					local stack = ItemStack (items[1])

					if stack then
						preserve_metadata (pos, node, meta, { stack })
						utils.item_drop (stack, nil, pos)
						on_destruct (pos)
						minetest.remove_node (pos)
					end
				end
			end
		end
	end
end



local function indexer_on_rightclick (pos, node, clicker, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)

	if meta then
		if not utils.can_interact_with_node (pos, clicker) then
			if clicker and clicker:is_player () then
				local owner = meta:get_string ("owner")

				local spec =
				"formspec_version[3]"..
				"size[8.0,4.0,false]"..
				"label[1.0,1.0;Owned by "..minetest.formspec_escape (owner).."]"..
				"button_exit[3.0,2.0;2.0,1.0;close;Close]"

				minetest.show_formspec (clicker:get_player_name (),
												"lwcomponents:component_privately_owned",
												spec)
			end

			return itemstack
		end

		meta:set_string ("formspec", indexer_get_formspec (pos))
	end

	return itemstack
end



local function indexer_on_receive_fields (pos, formname, fields, sender)
	if not utils.can_interact_with_node (pos, sender) then
		return
	end

	if fields.setchannel or (fields.key_enter_field and
									 fields.key_enter_field == "channel") then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("channel", fields.channel)
		end

	elseif fields.search or (fields.key_enter_field and
									 fields.key_enter_field == "search_field") then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("formspec", indexer_get_formspec (pos, fields.search_field))
		end

	else
		for k, v in pairs (fields) do
			if k:sub (1, 3) == "01_" then
				local item = k:sub (4, -1)
				output_items (pos, item, 1)

				break
			elseif k:sub (1, 3) == "10_" then
				local item = k:sub (4, -1)
				output_items (pos, item, 10)

				break
			elseif k:sub (1, 3) == "ST_" then
				local marker = k:find ("_", 4, true)

				if marker then
					local qty = tonumber (k:sub (4, marker - 1) or 1)
					local item = k:sub (marker + 1, -1)

					output_items (pos, item, qty)
				end
			end
		end
	end
end



local function indexer_on_metadata_inventory_put (pos, listname, index, stack, player)
	if listname == "input" then
		store_input_delayed (pos)
	end
end



local function indexer_on_metadata_inventory_move (pos, from_list, from_index,
																	to_list, to_index, count, player)
	if from_list == "output" and to_list == "input" then
		store_input_delayed (pos)
	end
end



local function indexer_allow_metadata_inventory_put (pos, listname, index, stack, player)
	if listname == "filter" then
		local meta = minetest.get_meta (pos)

		if meta then
			local inv = meta:get_inventory ()

			if inv then
				inv:set_stack ("filter", index, ItemStack (stack:get_name ()))
			end
		end

		return 0
	end

	return stack:get_stack_max ()
end



local function indexer_allow_metadata_inventory_take (pos, listname, index, stack, player)
	if listname == "filter" then
		local meta = minetest.get_meta (pos)

		if meta then
			local inv = meta:get_inventory ()

			if inv then
				inv:set_stack ("filter", index, nil)
			end
		end

		return 0
	end

	return stack:get_stack_max ()
end



local function indexer_allow_metadata_inventory_move (pos, from_list, from_index,
																		to_list, to_index, count, player)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			if from_list == "filter" then
				if to_list == "filter" then
					return 1
				end

				inv:set_stack ("filter", from_index, nil)

				return 0

			elseif to_list == "filter" then
				local stack = inv:get_stack (from_list, from_index)

				if stack and not stack:is_empty () then
					inv:set_stack ("filter", to_index, ItemStack (stack:get_name ()))
				end

				return 0

			else
				local stack = inv:get_stack (from_list, from_index)

				if stack and not stack:is_empty () then
					return stack:get_stack_max ()
				end
			end
		end
	end

	return utils.settings.default_stack_max
end



local function send_stock_message (pos)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				local msg =
				{
					action = "inventory",
					inventory = get_stock_list (pos)
				}

				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 msg)
			end
		end
	end
end



local function digilines_support ()
	if utils.digilines_supported then
		return
		{
			wire =
			{
				rules = utils.digilines_default_rules,
			},

			effector =
			{
				action = function (pos, node, channel, msg)
					local meta = minetest.get_meta(pos)

					if meta then
						local this_channel = meta:get_string ("channel")

						if this_channel ~= "" then
							if type (msg) == "string" then
								local m = { }
								for w in string.gmatch(msg, "[^%s]+") do
									m[#m + 1] = w
								end

								if this_channel == channel then
									if m[1] == "output" then
										if m[2] then
											output_items (pos, m[2], tonumber (m[3] or 1) or 1)
										end

									elseif m[1] == "inventory" then
										send_stock_message (pos)

									end
								end

							elseif type (msg) == "table" then
								if this_channel == channel then
									if msg.action and msg.action == "output" and
										type (msg.item) == "string" then

										output_items (pos, msg.item, tonumber (msg.count or 1) or 1)
									end
								end

							end
						end
					end
				end,
			}
		}
	end

	return nil
end



local function pipeworks_support ()
	if utils.pipeworks_supported then
		return
		{
			priority = 100,
			input_inventory = "output",
			connect_sides = { left = 1, right = 1, front = 1, back = 1, bottom = 1, top = 1 },

			insert_object = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					store_input_delayed (pos)

					return inv:add_item ("input", stack)
				end

				return stack
			end,

			can_insert = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:room_for_item ("input", stack)
				end

				return false
			end,

			can_remove = function (pos, node, stack, dir)
				-- returns the maximum number of items of that stack that can be removed
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					local slots = inv:get_size ("output")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("output", i)

						if s and not s:is_empty () and utils.is_same_item (stack, s) then
							return s:get_count ()
						end
					end
				end

				return 0
			end,

			remove_items = function (pos, node, stack, dir, count)
				-- removes count items and returns them
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil
				local left = count

				if inv then
					local slots = inv:get_size ("output")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("output", i)

						if s and not s:is_empty () and utils.is_same_item (s, stack) then
							if s:get_count () > left then
								s:set_count (s:get_count () - left)
								inv:set_stack ("output", i, s)
								left = 0
							else
								left = left - s:get_count ()
								inv:set_stack ("output", i, nil)
							end
						end

						if left == 0 then
							break
						end
					end
				end

				local result = ItemStack (stack)
				result:set_count (count - left)

				return result
			end
		}
	end

	return nil
end



local indexer_groups = { choppy = 2 }
if utils.pipeworks_supported then
	indexer_groups.tubedevice = 1
	indexer_groups.tubedevice_receiver = 1
end



minetest.register_node("lwcomponents:storage_indexer", {
	description = S("Storage Indexer"),
	drawtype = "normal",
	tiles = { "lwcomponents_storage_framed.png", "lwcomponents_storage_framed.png",
				 "lwcomponents_storage_indexer.png", "lwcomponents_storage_indexer.png",
				 "lwcomponents_storage_indexer.png", "lwcomponents_storage_indexer.png",},
	is_ground_content = false,
	groups = table.copy (indexer_groups),
	sounds = default.node_sound_wood_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_receive_fields = indexer_on_receive_fields,
	after_place_node = indexer_after_place_node,
	can_dig = indexer_can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	on_blast = indexer_on_blast,
	on_rightclick = indexer_on_rightclick,
	on_metadata_inventory_put = indexer_on_metadata_inventory_put,
	on_metadata_inventory_move = indexer_on_metadata_inventory_move,
	allow_metadata_inventory_take = indexer_allow_metadata_inventory_take,
	allow_metadata_inventory_put = indexer_allow_metadata_inventory_put,
	allow_metadata_inventory_move = indexer_allow_metadata_inventory_move
})



minetest.register_node("lwcomponents:storage_indexer_locked", {
	description = S("Storage Indexer (locked)"),
	drawtype = "normal",
	tiles = { "lwcomponents_storage_framed.png", "lwcomponents_storage_framed.png",
				 "lwcomponents_storage_indexer.png", "lwcomponents_storage_indexer.png",
				 "lwcomponents_storage_indexer.png", "lwcomponents_storage_indexer.png",},
	is_ground_content = false,
	groups = table.copy (indexer_groups),
	sounds = default.node_sound_wood_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_receive_fields = indexer_on_receive_fields,
	after_place_node = indexer_after_place_node_locked,
	can_dig = indexer_can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	on_blast = indexer_on_blast,
	on_rightclick = indexer_on_rightclick,
	on_metadata_inventory_put = indexer_on_metadata_inventory_put,
	on_metadata_inventory_move = indexer_on_metadata_inventory_move,
	allow_metadata_inventory_take = indexer_allow_metadata_inventory_take,
	allow_metadata_inventory_put = indexer_allow_metadata_inventory_put,
	allow_metadata_inventory_move = indexer_allow_metadata_inventory_move
})



utils.hopper_add_container({
	{"top", "lwcomponents:storage_indexer", "output"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:storage_indexer", "input"}, -- insert items below from hopper above
	{"side", "lwcomponents:storage_indexer", "input"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:storage_indexer_locked", "output"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:storage_indexer_locked", "input"}, -- insert items below from hopper above
	{"side", "lwcomponents:storage_indexer_locked", "input"}, -- insert items from hopper at side
})



--
