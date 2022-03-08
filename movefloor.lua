local utils = ...
local S = utils.S



if utils.mesecon_supported then



local mesecon_rules =
{
	{ x =  1, y =  1, z =  0 },
	{ x = -1, y =  1, z =  0 },
	{ x =  0, y =  1, z =  1 },
	{ x =  0, y =  1, z = -1 },
	{ x =  1, y = -1, z =  0 },
	{ x = -1, y = -1, z =  0 },
	{ x =  0, y = -1, z =  1 },
	{ x =  0, y = -1, z = -1 },
}



local max_push = 3



local function get_movefloor_direction (rulename)
	if rulename.y > 0 then
		return { x = 0, y = 1, z = 0 }
	elseif rulename.y < 0 then
		return { x = 0, y = -1, z = 0 }
	end
end



local function add_movefloor_list (pos, list)
	for i = 1, #list do
		if list[i].x == pos.x and
			list[i].y == pos.y and
			list[i].z == pos.z then

			return false
		end
	end

	list[#list + 1] = { x = pos.x, y = pos.y, z = pos.z }

	return true
end



local function find_adjoining_movefloor (pos, list)
	local tpos =
	{
		{ x = pos.x + 1, y = pos.y, z = pos.z },
		{ x = pos.x - 1, y = pos.y, z = pos.z },
		{ x = pos.x, y = pos.y, z = pos.z + 1 },
		{ x = pos.x, y = pos.y, z = pos.z - 1 }
	}

	for i = 1, #tpos do
		local node = minetest.get_node (tpos[i])
		if node and node.name == "lwcomponents:movefloor" then
			if add_movefloor_list (tpos[i], list) then
				find_adjoining_movefloor (tpos[i], list)
			end
		end
	end
end



local function get_node_height (node)
	local height = 0
	local def = minetest.registered_nodes[node.name]

	if def and type (def.collision_box) == "table" then
		if def.collision_box.type and def.collision_box.type == "regular" then
			height = 1

		else
			for _, box in pairs (def.collision_box) do
				if type (box) == "table" then
					if type (box[5]) == "number" then
						height = box[5]
					else
						for _, b in ipairs (box) do
							if type (b[5]) == "number" and b[5] > height then
								height = b[5]
							end
						end
					end
				end
			end

		end
	end

	return height
end



local function get_affected_nodes (floor_list)
	local list = { }
	local max_height = 0
	local protected = false

	for _, fpos in ipairs (floor_list) do
		for y = 0, max_push, 1 do
			local npos = vector.add (fpos, { x = 0, y = y, z = 0 })
			local node = utils.get_far_node (npos)

			if node and node.name ~= "air" then
				local meta = minetest.get_meta (npos)
				local timer = minetest.get_node_timer (npos)
				local h = get_node_height (node) + npos.y - fpos.y - 0.5

				list[#list + 1] =
				{
					pos = npos,
					node = node,
					meta = (meta and meta:to_table ()),
					timeout = (timer and timer:get_timeout ()) or 0,
					elapsed = (timer and timer:get_elapsed ()) or 0
				}

				if h > max_height then
					max_height = h
				end

				if utils.is_protected (npos, nil) then
					protected = true
				end
			end
		end
	end

	return list, math.ceil (max_height), protected
end



local function get_entity_height (obj, base)
	local height = 0

	if obj.get_pos then
		local pos = obj:get_pos ()

		if obj.get_luaentity then
			local entity = obj:get_luaentity ()

			if entity and entity.name then
				local def = minetest.registered_entities[entity.name]

				if def and type (def.collisionbox) == "table" and
					type (def.collisionbox[5]) == "number" then

					height = def.collisionbox[5] + pos.y - base
				end
			end
		end

		local props = obj:get_properties ()
		if props and props.collisionbox and type (props.collisionbox) == "table" and
			type (props.collisionbox[5]) == "number" then

			if props.collisionbox[5] > height then
				height = props.collisionbox[5] + pos.y - base
			end
		end
	end

	return height
end



local function get_affected_entities (floor_list)
	local list = { }
	local max_height = 0

	for _, fpos in pairs (floor_list) do
		local min_pos = vector.subtract (fpos, { x = 0.4999, y = 0.4999, z = 0.4999 })
		local max_pos = vector.add (fpos, { x = 0.4999, y = max_push + 0.4999, z = 0.4999 })

		local objects = minetest.get_objects_in_area (min_pos, max_pos)

		for _, obj in ipairs (objects) do
			local h = get_entity_height (obj, fpos.y + 0.5)

			list[#list + 1] =
			{
				pos = obj:get_pos (),
				obj = obj
			}

			if h > max_height then
				max_height = h
			end
		end
	end

	return list, math.ceil (max_height)
end



local function is_obstructed (floor_list, height)
	for _, fpos in pairs (floor_list) do
		local npos = vector.add (fpos, { x = 0, y = height, z = 0 })

		if utils.is_protected (npos, nil) then
			return true
		end

		local node = utils.get_far_node (npos)

		if node and node.name ~= "air" then
			local def = minetest.registered_nodes[node.name]

			if not def or not def.buildable_to then
				return true
			end
		end
	end

	return false
end



local function move_entities (list, move, players)
	for _, entry in ipairs (list) do
		if entry.obj then
			if players or not entry.obj:is_player () then
				local pos

				if entry.obj:is_player () then
					pos = vector.add (entry.pos, { x = move.x, y = move.y + 0.1, z = move.z })
				else
					pos = vector.add (entry.pos, move)
				end

				if entry.obj.move_to then
					entry.obj:move_to (pos)
				elseif entry.set_pos then
					entry.obj:set_pos (pos)
				end
			end
		end
	end
end



local function update_player_position (list)
	for _, entry in ipairs (list) do
		local player = minetest.get_player_by_name (entry.name)

		if player then
			local pos = player:get_pos ()

			if pos.y < entry.pos.y then
				pos.y = entry.pos.y + 0.1
				player:set_pos (pos)
			end
		end
	end
end



local function queue_player_update (list, move)
	local players = { }

	for _, entry in ipairs (list) do
		if entry.obj and entry.obj:is_player () then
			players[#players + 1] =
			{
				pos = vector.add (entry.pos, move),
				name = entry.obj:get_player_name ()
			}
		end
	end

	if #players > 0 then
		minetest.after(0.1, update_player_position, players)
	end
end



local function move_nodes (list, move)
	if move.y > 0 then
		for i = #list, 1, -1 do
			local pos = vector.add (list[i].pos, move)

			minetest.remove_node (list[i].pos)
			minetest.set_node (pos, list[i].node)

			if list[i].meta then
				local meta = minetest.get_meta (pos)

				if meta then
					meta:from_table (list[i].meta)
				end
			end

			if list[i].timeout > 0 then
				local timer = minetest.get_node_timer (pos)

				if timer then
					timer:set (list[i].timeout, list[i].elapsed)
				end
			end
		end
	else
		for i = 1, #list, 1 do
			local pos = vector.add (list[i].pos, move)

			minetest.remove_node (list[i].pos)
			minetest.set_node (pos, list[i].node)

			if list[i].meta then
				local meta = minetest.get_meta (pos)

				if meta then
					meta:from_table (list[i].meta)
				end
			end

			if list[i].timeout > 0 then
				local timer = minetest.get_node_timer (pos)

				if timer then
					timer:set (list[i].timeout, list[i].elapsed)
				end
			end
		end
	end
end



local function check_for_falling (list)
	for _, pos in ipairs (list) do
		minetest.check_for_falling (vector.add (pos, { x = 0, y = max_push + 1, z = 0 }))
	end
end



local function movefloor_move (pos, node, rulename)
	local direction = get_movefloor_direction (rulename)

	local list =
	{
		{ x = pos.x, y = pos.y, z = pos.z }
	}

	find_adjoining_movefloor (pos, list)

	local nodes, height, protected = get_affected_nodes (list)

	if protected then
		return
	end

	local entities, h = get_affected_entities (list)

	if h > height then
		height = h
	end

	if is_obstructed (list, (direction.y > 0 and height + 1) or -1) then
		return
	end

	if direction.y > 0 then
		move_entities (entities, direction, true)
		move_nodes (nodes, direction)
		queue_player_update (entities, direction)
	else
		move_nodes (nodes, direction)
		move_entities (entities, direction, false)
		check_for_falling (list)
		queue_player_update (entities, direction)
	end

	minetest.sound_play ("lwmovefloor", { pos = pos, max_hear_distance = 10, gain = 1.0 }, true)
end



local function mesecon_support ()
	return
	{
		effector =
		{
			rules = table.copy (mesecon_rules),

			action_on = function (pos, node, rulename)
				-- do something to turn the effector on

				if rulename then
					movefloor_move (pos, node, rulename)
				end
			end
		}
	}
end



minetest.register_node("lwcomponents:movefloor", {
   description = S("Moving Floor"),
   tiles = { "lwmovefloortop.png", "lwmovefloortop.png",
				 "lwmovefloorside.png", "lwmovefloorside.png",
				 "lwmovefloorside.png", "lwmovefloorside.png" },
   sunlight_propagates = false,
   drawtype = "normal",
   node_box = {
      type = "fixed",
      fixed = {
         {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
      }
   },
	groups = { cracky = 2 },
	sounds = default.node_sound_wood_defaults (),
	mesecons = mesecon_support (),
})



end
