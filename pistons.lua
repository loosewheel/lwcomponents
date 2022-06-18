local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local piston_interval = 0.2



local function direction_vector (node)
	local axis = math.floor (node.param2 / 4)
	local rotate = node.param2 % 4
	local vec = { x = 0, y = 0, z = 0 }

	if rotate == 0 then
		vec = { x = 0, y = 0, z = -1 }
	elseif rotate == 1 then
		vec = { x = -1, y = 0, z = 0 }
	elseif rotate == 2 then
		vec = { x = 0, y = 0, z = 1 }
	elseif rotate == 3 then
		vec = { x = 1, y = 0, z = 0 }
	end

	if axis == 1 then
		vec = vector.rotate (vec, { x = math.pi / -2, y = 0, z = 0 })
	elseif axis == 2 then
		vec = vector.rotate (vec, { x = math.pi / 2, y = 0, z = 0 })
	elseif axis == 3 then
		vec = vector.rotate (vec, { x = 0, y = 0, z = math.pi / 2 })
	elseif axis == 4 then
		vec = vector.rotate (vec, { x = 0, y = 0, z = math.pi / -2 })
	elseif axis == 5 then
		vec = vector.rotate (vec, { x = math.pi, y = 0, z = 0 })
	end

	return vec
end



local function push_entities (pos, movedir, entity_list, upper_limit)
	local objects = minetest.get_objects_inside_radius (pos, 1.5)

	for _, obj in ipairs (objects) do
		if obj.get_pos and obj.move_to then
			local opos = obj:get_pos ()

			if opos.x > (pos.x - 0.5) and opos.x < (pos.x + 0.5) and
					opos.z > (pos.z - 0.5) and opos.z < (pos.z + 0.5) and
					opos.y >= (pos.y - 0.5) and opos.y < (pos.y + upper_limit) then

				local newpos = vector.add (opos, movedir)
				local node = utils.get_far_node (vector.round (newpos))
				local def = (node and utils.find_item_def (node.name)) or nil

				if (node.name == "air") or (def and not def.walkable) then

					entity_list[#entity_list + 1] =
					{
						obj = obj,
						pos = newpos
					}

					obj:move_to (newpos)
				else
					entity_list[#entity_list + 1] =
					{
						obj = obj,
						pos = opos
					}
				end
			end
		end
	end
end



local function update_player_position (player_list)
	for _, entry in ipairs (player_list) do
		local player = minetest.get_player_by_name (entry.name)

		if player then
			local pos = player:get_pos ()

			if pos.y < entry.pos.y then
				pos.y = entry.pos.y
				player:set_pos (pos)
			end
		end
	end
end



local function queue_player_update (entity_list, movedir)
	local players = { }

	for _, entry in ipairs (entity_list) do
		if entry.obj and entry.obj:is_player () then
			players[#players + 1] =
			{
				pos = entry.pos,
				name = entry.obj:get_player_name ()
			}
		end
	end

	if #players > 0 then
		minetest.after(0.1, update_player_position, players)
	end
end



local rules_alldirs =
{
	{x =  1, y =  0,  z =  0},
	{x = -1, y =  0,  z =  0},
	{x =  0, y =  1,  z =  0},
	{x =  0, y = -1,  z =  0},
	{x =  0, y =  0,  z =  1},
	{x =  0, y =  0,  z = -1},
}



local function add_pos_to_list (pos, dir, movedir, node_list, check_list)
	local hash = minetest.hash_node_position (pos)

	if not check_list[hash] then
		if minetest.is_protected (pos, "") then
			return 0
		end

		local node = utils.get_far_node (pos)

		if not node then
			return 0
		end

		local def = utils.find_item_def (node.name)

		if node.name == "air" or (def and def.buildable_to) then
			return 1
		end

		if node.name == "lwcomponents:piston_blank_1" or
				node.name == "lwcomponents:piston_blank_2" then
			return 0
		end

		local meta = minetest.get_meta (pos)
		local timer = minetest.get_node_timer (pos)

		check_list[hash] = true

		node_list[#node_list + 1] =
		{
			node = node,
			def = def,
			pos = vector.new (pos),
			newpos = vector.add (pos, movedir),
			meta = (meta and meta:to_table ()) or { },
			node_timer =
			{
				(timer and timer:get_timeout ()) or 0,
				(timer and timer:get_elapsed ()) or 0
			}
		}

		if def.mvps_sticky then
			local sides = def.mvps_sticky (pos, node)

			for _, r in ipairs (sides) do
				if add_pos_to_list (r, dir, movedir, node_list, check_list) == 0 then
					return 0
				end
			end
		end

		-- If adjacent node is sticky block and connects add that
		-- position to the connected table
		for _, r in ipairs (rules_alldirs) do
			local apos = vector.add (pos, r)
			local anode = utils.get_far_node (apos)
			local adef = (anode and minetest.registered_nodes[anode.name]) or nil

			if adef and adef.mvps_sticky then
				local sides = adef.mvps_sticky (apos, anode)

				-- connects to this position?
				for _, link in ipairs (sides) do
					if vector.equals (link, pos) then
						if add_pos_to_list (apos, dir, movedir, node_list, check_list) == 0 then
							return 0
						end

						break
					end
				end
			end
		end
	end

	return 2
end



local function node_list_last_pos (pos, node_list, length)
	local movedir = node_list.movedir
	local base_pos = node_list.base_pos

	if movedir then
		if movedir.x ~= 0 then
			return vector.new ({
				x = base_pos.x + (movedir.x * length),
				y = pos.y,
				z = pos.z
			})
		elseif movedir.z ~= 0 then
			return vector.new ({
				x = pos.x,
				y = pos.y,
				z = base_pos.z + (movedir.z * length)
			})
		elseif movedir.y ~= 0 then
			return vector.new ({
				x = pos.x,
				y = base_pos.y + (movedir.y * length),
				z = pos.z
			})
		end
	end

	return pos
end



local function get_node_list (pos, extent, length, maxnodes, pushing, node_list, check_list)
	local node = utils.get_far_node (pos)
	node_list = node_list or { }
	check_list = check_list or { }

	if node then
		local dir = vector.round (direction_vector (node))
		local movedir = vector.round ((pushing and dir) or vector.multiply (dir, -1))

		node_list.dir = dir
		node_list.movedir = movedir
		node_list.base_pos = vector.add (pos, vector.multiply (dir, extent))
		node_list.length = length
		node_list.maxnodes = maxnodes

		check_list[minetest.hash_node_position (vector.add (pos, vector.multiply (dir, extent - 1)))] = true

		for i = 0, length - 1, 1 do
			local tpos = vector.add (pos, vector.multiply (dir, extent + i))

			local result = add_pos_to_list (tpos, dir, movedir, node_list, check_list)

			if result == 0 then
				return false
			elseif result == 1 then
				break
			end
		end

		-- get any ahead of stickyblocks to limit
		local copy_list = table.copy (node_list)

		for _, n in ipairs (copy_list) do
			local hash = minetest.hash_node_position (n.newpos)

			if not check_list[hash] then
				local last_pos = node_list_last_pos (n.newpos, node_list, length)
				local this_pos = vector.new (n.newpos)
				local count = 0

				while not vector.equals (this_pos, last_pos) and count < length do
					local result = add_pos_to_list (this_pos, dir, movedir, node_list, check_list)

					if result == 0 then
						return false
					elseif result == 1 then
						break
					end

					count = count + 1
					this_pos = vector.add (this_pos, movedir)
				end
			end
		end

		return true
	end

	return false
end



local function can_node_list_move (node_list, check_list)
	local movedir = node_list.movedir
	local radius = math.floor (node_list.maxnodes / 2)
	local base_pos = node_list.base_pos

	if movedir then
		for _, n in ipairs (node_list) do
			-- check connected stickyblocks don't extend too far laterally
			if movedir.x ~= 0 then
				if math.abs (n.pos.y - base_pos.y) > radius or
						math.abs (n.pos.z - base_pos.z) > radius then
					return false
				end
			elseif movedir.z ~= 0 then
				if math.abs (n.pos.y - base_pos.y) > radius or
						math.abs (n.pos.x - base_pos.x) > radius then
					return false
				end
			elseif movedir.y ~= 0 then
				if math.abs (n.pos.x - base_pos.x) > radius or
						math.abs (n.pos.z - base_pos.z) > radius then
					return false
				end
			end

			-- check moving to is clear
			if not check_list[minetest.hash_node_position (n.newpos)] then
				local node = utils.get_far_node (n.newpos)
				local def = (node and utils.find_item_def (node.name)) or nil

				if node.name ~= "air" and def and not def.buildable_to then
					return false
				end
			end
		end
	end

	return true
end



local function sort_node_list (node_list)
	local movedir = node_list.movedir

	if movedir then
		if movedir.x > 0 then
			table.sort (node_list , function (n1, n2)
				return n1.pos.x > n2.pos.x
			end)
		elseif movedir.x < 0 then
			table.sort (node_list , function (n1, n2)
				return n1.pos.x < n2.pos.x
			end)
		elseif movedir.z > 0 then
			table.sort (node_list , function (n1, n2)
				return n1.pos.z > n2.pos.z
			end)
		elseif movedir.z < 0 then
			table.sort (node_list , function (n1, n2)
				return n1.pos.z < n2.pos.z
			end)
		elseif movedir.y > 0 then
			table.sort (node_list , function (n1, n2)
				return n1.pos.y > n2.pos.y
			end)
		elseif movedir.y < 0 then
			table.sort (node_list , function (n1, n2)
				return n1.pos.y < n2.pos.y
			end)
		end
	end
end



local on_mvps_move = function (node_list)
end



local is_mvps_stopper = function (node, movedir, node_list, id)
	return false
end



local update_mesecons_connections_removed = function (node_list)
end



local update_mesecons_connections_added = function (node_list)
end


if utils.mesecon_supported then
	if mesecon.on_mvps_move then
		on_mvps_move = function (node_list)
			for _, callback in ipairs (mesecon.on_mvps_move) do
				callback (node_list)
			end
		end
	end

	if mesecon.is_mvps_stopper then
		is_mvps_stopper = function (node, movedir, node_list, id)
			return mesecon.is_mvps_stopper (node, movedir, node_list, id)
		end
	end

	if mesecon.on_dignode then
		update_mesecons_connections_removed = function (node_list)
			for _, node in ipairs (node_list) do
				mesecon.on_dignode (node.oldpos, node.node)
			end
		end
	end

	if mesecon.on_placenode then
		update_mesecons_connections_added = function (node_list)
			for _, node in ipairs (node_list) do
				mesecon.on_placenode (node.pos, utils.get_far_node (node.pos))
			end
		end
	end
end



local function push_nodes (pos, extent)
	local node_list = { }
	local check_list = { }
	local entity_list = { }
	local maxnodes = utils.settings.max_piston_nodes

	if not get_node_list (pos, extent, maxnodes, maxnodes, true, node_list, check_list) then
		return false
	end

	if not can_node_list_move (node_list, check_list, maxnodes) then
		return false
	end

	sort_node_list (node_list)

	for id, node in ipairs (node_list) do
		if is_mvps_stopper (node.node, node_list.movedir, node_list, id) then
			return false
		end
	end

	for _, node in ipairs (node_list) do
		node.oldpos = vector.new (node.pos)
		node.pos = vector.new (node.newpos)
		node.newpos = nil

		minetest.remove_node (node.oldpos)
	end

	update_mesecons_connections_removed (node_list)

	-- push entities in front first
	for _, node in ipairs (node_list) do
		if not check_list[minetest.hash_node_position (node.pos)] then
			push_entities (node.pos, node_list.movedir, entity_list, 0.5)
		end
	end

	for _, node in ipairs (node_list) do
		push_entities (node.oldpos, node_list.movedir, entity_list, 1.0)

		minetest.set_node (node.pos, node.node)

		if node.meta then
			local meta = minetest.get_meta (node.pos)

			if meta then
				meta:from_table (node.meta)
			end
		end

		if node.node_timer[1] > 0 then
			local timer = minetest.get_node_timer (node.pos)

			if timer then
				timer:set (node.node_timer[1], node.node_timer[2])
			end
		end
	end

	-- push any entities in front of pusher
	push_entities (node_list.base_pos, node_list.movedir, entity_list, 0.5)

	on_mvps_move (node_list)
	update_mesecons_connections_added (node_list)

	if node_list.movedir.y >= 0 then
		queue_player_update (entity_list, node_list.movedir)
	end

	return true
end



local function pull_node (pos, extent)
	local node_list = { }
	local check_list = { }
	local entity_list = { }
	local maxnodes = utils.settings.max_piston_nodes

	if not get_node_list (pos, extent, 1, maxnodes, false, node_list, check_list) then
		return false
	end

	if not can_node_list_move (node_list, check_list, maxnodes) then
		return false
	end

	sort_node_list (node_list)

	for id, node in ipairs (node_list) do
		if is_mvps_stopper (node.node, node_list.movedir, node_list, id) then
			return false
		end
	end

	for _, node in ipairs (node_list) do
		node.oldpos = vector.new (node.pos)
		node.pos = vector.new (node.newpos)
		node.newpos = nil

		minetest.remove_node (node.oldpos)
	end

	update_mesecons_connections_removed (node_list)

	-- push entities in front first
	for _, node in ipairs (node_list) do
		if not check_list[minetest.hash_node_position (node.pos)] then
			push_entities (node.pos, node_list.movedir, entity_list, 0.5)
		end
	end

	for _, node in ipairs (node_list) do
		push_entities (node.oldpos, node_list.movedir, entity_list, 1.0)

		minetest.set_node (node.pos, node.node)

		if node.meta then
			local meta = minetest.get_meta (node.pos)

			if meta then
				meta:from_table (node.meta)
			end
		end

		if node.node_timer[1] > 0 then
			local timer = minetest.get_node_timer (node.pos)

			if timer then
				timer:set (node.node_timer[1], node.node_timer[2])
			end
		end
	end

	on_mvps_move (node_list)
	update_mesecons_connections_added (node_list)

	if node_list.movedir.y >= 0 then
		queue_player_update (entity_list, node_list.movedir)
	end

	return true
end



local function place_blank (pos, extent)
	local node = utils.get_far_node (pos)

	if node then
		local vec = direction_vector (node)
		local blank_pos = vector.add (pos, vector.multiply (vec, extent))
		local blank_node = utils.get_far_node (blank_pos)
		local blank_def = blank_node and utils.find_item_def (blank_node.name)

		if blank_node and blank_node.name == "air" or
			(blank_def and not blank_def.walkable) then

			minetest.set_node (blank_pos,
									 {
										name = "lwcomponents:piston_blank_"..tostring (extent),
										param2 = node.param2
									 })
		end
	end
end



local function remove_blank (pos, extent)
	local node = utils.get_far_node (pos)

	if node then
		local vec = direction_vector (node)
		local blank_pos = vector.add (pos, vector.multiply (vec, extent))
		local blank_node = utils.get_far_node (blank_pos)

		if blank_node and
			blank_node.name == "lwcomponents:piston_blank_"..tostring (extent) then

			minetest.remove_node (blank_pos)
		end
	end
end



local function extend_piston (pos, extent)
	local node = utils.get_far_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		extent = math.max (math.min (tonumber (extent or 2), meta:get_int ("max_extent")), 0)

		if node.name == "lwcomponents:piston" then
			if extent ~= 0 then
				if push_nodes (pos, 1) then
					node.name = "lwcomponents:piston_1"
					minetest.swap_node (pos, node)
					place_blank (pos, 1)
					minetest.sound_play ("lwpiston_extend",
												{
													pos = pos,
													max_hear_distance = 20,
													gain = 0.3
												},
												true)

					if extent == 2 then
						meta:set_int ("extent", 2)
						minetest.get_node_timer (pos):start (piston_interval)

						return true
					end
				end
			end

		elseif node.name == "lwcomponents:piston_1" then
			if extent == 0 then
				remove_blank (pos, 1)
				node.name = "lwcomponents:piston"
				minetest.swap_node (pos, node)
				minetest.sound_play ("lwpiston_retract",
											{
												pos = pos,
												max_hear_distance = 20,
												gain = 0.3
											},
											true)

			elseif extent == 2 then
				if push_nodes (pos, 2) then
					node.name = "lwcomponents:piston_2"
					minetest.swap_node (pos, node)
					place_blank (pos, 2)
					minetest.sound_play ("lwpiston_extend",
												{
													pos = pos,
													max_hear_distance = 20,
													gain = 0.3
												},
												true)
				end
			end

		elseif node.name == "lwcomponents:piston_2" then
			if extent ~= 2 then
				remove_blank (pos, 2)
				node.name = "lwcomponents:piston_1"
				minetest.swap_node (pos, node)
				minetest.sound_play ("lwpiston_retract",
											{
												pos = pos,
												max_hear_distance = 20,
												gain = 0.3
											},
											true)

				if extent == 0 then
					meta:set_int ("extent", 0)
					minetest.get_node_timer (pos):start (piston_interval)

					return true
				end
			end

		elseif node.name == "lwcomponents:piston_sticky" then
			if extent ~= 0 then
				if push_nodes (pos, 1) then
					node.name = "lwcomponents:piston_sticky_1"
					minetest.swap_node (pos, node)
					place_blank (pos, 1)
					minetest.sound_play ("lwpiston_extend",
												{
													pos = pos,
													max_hear_distance = 20,
													gain = 0.3
												},
												true)

					if extent == 2 then
						meta:set_int ("extent", 2)
						minetest.get_node_timer (pos):start (piston_interval)

						return true
					end
				end
			end


		elseif node.name == "lwcomponents:piston_sticky_1" then
			if extent == 0 then
				remove_blank (pos, 1)
				node.name = "lwcomponents:piston_sticky"
				minetest.swap_node (pos, node)
				pull_node (pos, 2)
				minetest.sound_play ("lwpiston_retract",
											{
												pos = pos,
												max_hear_distance = 20,
												gain = 0.3
											},
											true)

			elseif extent == 2 then
				if push_nodes (pos, 2) then
					node.name = "lwcomponents:piston_sticky_2"
					minetest.swap_node (pos, node)
					place_blank (pos, 2)
					minetest.sound_play ("lwpiston_extend",
												{
													pos = pos,
													max_hear_distance = 20,
													gain = 0.3
												},
												true)
				end
			end

		elseif node.name == "lwcomponents:piston_sticky_2" then
			if extent ~= 2 then
				remove_blank (pos, 2)
				node.name = "lwcomponents:piston_sticky_1"
				minetest.swap_node (pos, node)
				pull_node (pos, 3)
				minetest.sound_play ("lwpiston_retract",
											{
												pos = pos,
												max_hear_distance = 20,
												gain = 0.3
											},
											true)

				if extent == 0 then
					meta:set_int ("extent", 0)
					minetest.get_node_timer (pos):start (piston_interval)

					return true
				end
			end
		end
	end

	return false
end



local function on_destruct_1 (pos)
	remove_blank (pos, 1)
end



local function on_destruct_2 (pos)
	remove_blank (pos, 2)
	remove_blank (pos, 1)
end



local function on_place (itemstack, placer, pointed_thing)
	local param2 = 0

	if placer and placer:is_player () then
		param2 = minetest.dir_to_facedir (placer:get_look_dir (), true)
	elseif pointed_thing and pointed_thing.type == "node" then
		param2 = minetest.dir_to_facedir (vector.subtract (pointed_thing.under, pointed_thing.above), true)
	end

	return minetest.item_place (itemstack, placer, pointed_thing, param2)
end




local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"size[7,3.3]"..
	"field[1,1;4,2;channel;Channel;${channel}]"..
	"button_exit[4.6,1.15;1.5,1;submit;Set]"..
	"checkbox[1,2;single;Single move;false]"

	meta:set_string ("formspec", spec)
	meta:set_int ("max_extent", 2)

	-- If return true no item is taken from itemstack
	return false
end



local function on_receive_fields (pos, formname, fields, sender)
	if not utils.can_interact_with_node (pos, sender) then
		return
	end

	local meta = minetest.get_meta (pos)

	if meta then
		if fields.submit then
			meta:set_string ("channel", fields.channel)
		end

		if fields.single then
			if fields.single == "true" then
				local spec =
				"size[7,3.3]"..
				"field[1,1;4,2;channel;Channel;${channel}]"..
				"button_exit[4.6,1.15;1.5,1;submit;Set]"..
				"checkbox[1,2;single;Single move;true]"

				meta:set_int ("max_extent", 1)
				meta:set_string ("formspec", spec)
			else
				local spec =
				"size[7,3.3]"..
				"field[1,1;4,2;channel;Channel;${channel}]"..
				"button_exit[4.6,1.15;1.5,1;submit;Set]"..
				"checkbox[1,2;single;Single move;false]"

				meta:set_int ("max_extent", 2)
				meta:set_string ("formspec", spec)
			end
		end
	end
end



local function on_blast (pos, intensity)
	local meta = minetest.get_meta (pos)

	if meta then
		if intensity >= 1.0 then

			minetest.remove_node (pos)

		else -- intensity < 1.0

			local node = minetest.get_node_or_nil (pos)
			if node then
				local items = minetest.get_node_drops (node, nil)

				if items and #items > 0 then
					local stack = ItemStack (items[1])

					if stack then
						utils.item_drop (stack, nil, pos)
						minetest.remove_node (pos)
					end
				end
			end
		end
	end
end



local function can_dig (pos, player)
	if not utils.can_interact_with_node (pos, player) then
		return false
	end

	return true
end



local function on_rightclick (pos, node, clicker, itemstack, pointed_thing)
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



local function on_timer (pos, elapsed)
	local meta = minetest.get_meta (pos)

	if meta then
		return extend_piston (pos, meta:get_int ("extent"))
	end

	return false
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

						if this_channel ~= "" and this_channel == channel then
							if type (msg) == "string" then
								local m = { }
								for w in string.gmatch(msg, "[^%s]+") do
									m[#m + 1] = w
								end

								if m[1] == "extend" then
									extend_piston (pos, m[2])

								elseif m[1] == "retract" then
									extend_piston (pos, 0)

								elseif m[1] == "single" then
									local spec =
									"size[7,3.3]"..
									"field[1,1;4,2;channel;Channel;${channel}]"..
									"button_exit[4.6,1.15;1.5,1;submit;Set]"..
									"checkbox[1,2;single;Single move;true]"

									meta:set_int ("max_extent", 1)
									meta:set_string ("formspec", spec)

								elseif m[1] == "double" then
									local spec =
									"size[7,3.3]"..
									"field[1,1;4,2;channel;Channel;${channel}]"..
									"button_exit[4.6,1.15;1.5,1;submit;Set]"..
									"checkbox[1,2;single;Single move;false]"

									meta:set_int ("max_extent", 2)
									meta:set_string ("formspec", spec)

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



local function mesecon_support ()
	if utils.mesecon_supported then
		return
		{
			effector =
			{
				rules = function (node)
					local dir = vector.multiply (minetest.facedir_to_dir (node.param2), -1)
					local rules = table.copy (utils.mesecon_default_rules)

					for i = #rules, 1, -1 do
						if vector.equals (rules[i], dir) then
							table.remove (rules, i)
						end
					end

					return rules
				end,

				action_on = function (pos, node)
					-- do something to turn the effector on
					extend_piston (pos, 2)
				end,

				action_off = function (pos, node)
					-- do something to turn the effector off
					extend_piston (pos, 0)
				end,
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:piston_blank_1", {
	description = S("Piston blank"),
	drawtype = "airlike",
	light_source = 0,
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	climbable = false,
	buildable_to = false,
	floodable = false,
	is_ground_content = false,
	drop = "",
	groups = { not_in_creative_inventory = 1 },
	paramtype = "light",
	-- unaffected by explosions
	on_blast = function() end,
})



minetest.register_node("lwcomponents:piston_blank_2", {
	description = S("Piston blank"),
	drawtype = "airlike",
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -0.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -0.5, 0.5, 0.5, -0.3125},
		},
	},
	light_source = 0,
	sunlight_propagates = true,
	walkable = true,
	pointable = true,
	diggable = true,
	climbable = false,
	buildable_to = false,
	floodable = false,
	is_ground_content = false,
	drop = "",
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	-- unaffected by explosions
	on_blast = function() end,
})



minetest.register_node("lwcomponents:piston", {
	description = S("Double Piston"),
	tiles = { "lwcomponents_piston_top.png", "lwcomponents_piston_bottom.png",
				 "lwcomponents_piston_right.png", "lwcomponents_piston_left.png",
				 "lwcomponents_piston_base.png", "lwcomponents_piston_pusher.png" },
	is_ground_content = false,
	groups = { cracky = 3, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:piston",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_place = on_place,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:piston_1", {
	description = S("Double Piston"),
	drawtype = "mesh",
	mesh = "piston_normal_1.obj",
	tiles = { "lwcomponents_piston.png" },
	visual_scale = 1.0,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -1.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -1.5, 0.5, 0.5, -1.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -1.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -1.5, 0.5, 0.5, -1.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	is_ground_content = false,
	groups = { cracky = 3 , not_in_creative_inventory = 1, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:piston",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct_1,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:piston_2", {
	description = S("Double Piston"),
	drawtype = "mesh",
	mesh = "piston_normal_2.obj",
	tiles = { "lwcomponents_piston.png" },
	visual_scale = 1.0,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -2.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -2.5, 0.5, 0.5, -2.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -2.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -2.5, 0.5, 0.5, -2.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	is_ground_content = false,
	groups = { cracky = 3 , not_in_creative_inventory = 1, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:piston",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct_2,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:piston_sticky", {
	description = S("Double Sticky Piston"),
	tiles = { "lwcomponents_piston_top.png", "lwcomponents_piston_bottom.png",
				 "lwcomponents_piston_right.png", "lwcomponents_piston_left.png",
				 "lwcomponents_piston_base.png", "lwcomponents_piston_pusher_sticky.png" },
	is_ground_content = false,
	groups = { cracky = 3, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:piston_sticky",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_place = on_place,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:piston_sticky_1", {
	description = S("Double Sticky Piston"),
	drawtype = "mesh",
	mesh = "piston_sticky_1.obj",
	tiles = { "lwcomponents_piston.png" },
	visual_scale = 1.0,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -1.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -1.5, 0.5, 0.5, -1.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -1.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -1.5, 0.5, 0.5, -1.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	is_ground_content = false,
	groups = { cracky = 3 , not_in_creative_inventory = 1, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:piston_sticky",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct_1,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:piston_sticky_2", {
	description = S("Double Sticky Piston"),
	drawtype = "mesh",
	mesh = "piston_sticky_2.obj",
	tiles = { "lwcomponents_piston.png" },
	visual_scale = 1.0,
	selection_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -2.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -2.5, 0.5, 0.5, -2.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{-0.125, -0.125, -2.4, 0.125, 0.125, 0.4},
			{-0.5, -0.5, -2.5, 0.5, 0.5, -2.3125},
			{-0.5, -0.5, -0.3125, 0.5, 0.5, 0.5},
		},
	},
	is_ground_content = false,
	groups = { cracky = 3 , not_in_creative_inventory = 1, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:piston_sticky",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct_2,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



end -- utils.digilines_supported or utils.mesecon_supported
