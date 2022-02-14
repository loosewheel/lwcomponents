local utils = ...
local S = utils.S



if utils.digilines_supported then



local function is_drop (obj)
	if obj then
		local entity = obj.get_luaentity and obj:get_luaentity ()

		return (entity and entity.name and entity.name == "__builtin:item")
	end

	return false
end



local function get_entity_dims (obj)
	local dims = { -0.5, 0, -0.5, 0.5, 2, 0.5 }

	if obj.get_luaentity then
		local entity = obj:get_luaentity ()

		if entity and entity.name then
			local def = minetest.registered_entities[entity.name]

			if def and type (def.collisionbox) == "table" then

				dims = { def.collisionbox[1] or -0.5,
							def.collisionbox[2] or -0.5,
							def.collisionbox[3] or -0.5,
							def.collisionbox[4] or 0.5,
							def.collisionbox[5] or 0.5,
							def.collisionbox[6] or 0.5 }
			end
		end
	end

	local props = obj:get_properties ()
	if props and props.collisionbox and type (props.collisionbox) == "table" then

		dims = { props.collisionbox[1] or -0.5,
					props.collisionbox[2] or -0.5,
					props.collisionbox[3] or -0.5,
					props.collisionbox[4] or 0.5,
					props.collisionbox[5] or 0.5,
					props.collisionbox[6] or 0.5 }
	end

	dims[1] = math.min (dims[1], dims[3])
	dims[3] = dims[1]
	dims[4] = math.max (dims[4], dims[6])
	dims[6] = dims[4]

	if (dims[3] - dims[1]) < 1 then
		dims[1] = -0.5
		dims[3] = -0.5
		dims[4] = 0.5
		dims[6] = 0.5
	end

	return dims
end



local function get_entity (pos)
	local objects = minetest.get_objects_inside_radius (pos, 2.0)

	if #objects > 0 then
		for _, obj in ipairs (objects) do
			if obj.get_pos then
				if obj:is_player () then
					local epos =  vector.round (obj:get_pos ())

					if epos.x == pos.x and epos.z == pos.z and
							(epos.y == pos.y or epos.y == pos.y - 1) then
						return 1
					end
				end

				if not is_drop (obj) then
					local epos =  vector.new (obj:get_pos ())
					local dims = get_entity_dims (obj)

					if pos.x >= (epos.x + dims[1]) and pos.x <= (epos.x + dims[4]) and
							pos.y >= (epos.y + dims[2]) and pos.y <= (epos.y + dims[5]) and
							pos.z >= (epos.z + dims[3]) and pos.z <= (epos.z + dims[6]) then
						return 2
					end
				end
			end
		end
	end

	return nil
end



local function camera_scan (pos, resolution, distance)
	local node = utils.get_far_node (pos)
	local image = { }

	for y = 1, resolution, 1 do
		image[y] = { }

		for x = 1, resolution, 1 do
			image[y][x] = "000000"
		end
	end

	if node then
		local dir = vector.multiply (minetest.facedir_to_dir (node.param2), -1)
		local last_pos = nil
		local last_color = "000000"
		local view = (distance * 1.414213562) / resolution

		for dist = distance, 1, -1 do
			local scale = dist / distance

			for y = 1, resolution, 1 do
				for x = 1, resolution, 1 do
					local horz = (x - (resolution / 2)) * scale * view
					local vert = (y - (resolution / 2)) * scale * view

					local tpos = nil
					if dir.x ~= 0 then
						tpos = vector.round ({ x = (dist * dir.x) + pos.x, y = pos.y - vert, z = horz + pos.z })
					else
						tpos = vector.round ({ x = horz + pos.x, y = pos.y - vert, z = (dist * dir.z) + pos.z })
					end


					if last_pos and vector.equals (last_pos, tpos) then
						image[y][x] = last_color
					else
						local entity = get_entity (tpos)

						if entity == 1 then
							local color = (((distance - dist) / distance) * 98) + 30

							last_color = string.format ("00%02X00", color)
							image[y][x] = last_color
							last_pos = tpos
						elseif entity == 2 then
							local color = (((distance - dist) / distance) * 98) + 30

							last_color = string.format ("0000%02X", color)
							image[y][x] = last_color
							last_pos = tpos
						else
							local node = utils.get_far_node (tpos)

							if node and node.name ~= "air" then
								local color = (((distance - dist) / distance) * 98) + 30

								last_color = string.format ("%02X%02X%02X", color, color, color)
								image[y][x] = last_color
								last_pos = tpos
							else
								last_pos = nil
							end
						end
					end
				end
			end
		end
	end

	return image
end



local function send_scan (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local channel = meta:get_string ("channel")

		if channel:len () > 0 then
			local image = camera_scan (pos,
												tonumber (meta:get_string ("resolution")),
												tonumber (meta:get_string ("distance")))

			utils.digilines_receptor_send (pos,
													 utils.digilines_default_rules,
													 channel,
													 image)
		end


	end
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"formspec_version[3]\n"..
	"size[8.5,5.5;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"field[1.0,2.5;4.0,0.8;distance;Distance;${distance}]\n"..
	"button[5.5,2.5;2.0,0.8;setdistance;Set]\n"..
	"field[1.0,4.0;4.0,0.8;resolution;Resolution;${resolution}]\n"..
	"button[5.5,4.0;2.0,0.8;setresolution;Set]\n"

	meta:set_string ("formspec", spec)
	meta:set_string ("distance", "5")
	meta:set_string ("resolution", "16")

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Camera (owned by "..placer:get_player_name ()..")")
	end

	-- If return true no item is taken from itemstack
	return false
end



local function on_receive_fields (pos, formname, fields, sender)
	if not utils.can_interact_with_node (pos, sender) then
		return
	end

	if fields.setchannel then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("channel", fields.channel)
		end
	end

	if fields.setdistance then
		local meta = minetest.get_meta (pos)

		if meta then
			local distance = math.min (math.max (tonumber (fields.distance) or 1, 1), 16)
			fields.distance = tostring (distance)

			meta:set_string ("distance", tostring (distance))
		end
	end

	if fields.setresolution then
		local meta = minetest.get_meta (pos)

		if meta then
			local resolution = math.max (tonumber (fields.resolution) or 1, 1)
			fields.resolution = tostring (resolution)

			meta:set_string ("resolution", tostring (resolution))
		end
	end
end



local function can_dig (pos, player)
	if not utils.can_interact_with_node (pos, player) then
		return false
	end

	return true
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
						preserve_metadata (pos, node, meta, { stack })
						utils.item_drop (stack, nil, pos)
						minetest.remove_node (pos)
					end
				end
			end
		end
	end
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

						if this_channel ~= "" and this_channel == channel and
							type (msg) == "string" then

							local m = { }
							for w in string.gmatch(msg, "[^%s]+") do
								m[#m + 1] = w
							end

							if m[1] == "scan" then
								send_scan (pos)

							elseif m[1] == "distance" then
								meta:set_string ("distance", tostring (tonumber (m[2] or 5) or 5))

							elseif m[1] == "resolution" then
								meta:set_string ("resolution", tostring (tonumber (m[2] or 16) or 16))

							end
						end
					end
				end,
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:camera", {
	description = S("Camera"),
	tiles = { "lwcamera.png", "lwcamera.png", "lwcamera.png",
				 "lwcamera.png", "lwcamera.png", "lwcamera_lens.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:camera",
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:camera_locked", {
	description = S("Camera (locked)"),
	tiles = { "lwcamera.png", "lwcamera.png", "lwcamera.png",
				 "lwcamera.png", "lwcamera.png", "lwcamera_lens.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:camera_locked",
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



end -- utils.digilines_supported



--
