local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local fan_interval = 0.2
local fan_force = 15.0



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



local function blow (pos)
	local node = minetest.get_node (pos)
	local dir = direction_vector (node)
	local reach = 5

	for r = 1, reach, 1 do
		local tpos = vector.add (pos, vector.multiply (dir, r))
		local tnode = minetest.get_node_or_nil (tpos)

		if tnode and tnode.name ~= "air" then
			local def = utils.find_item_def (tnode.name)

			if def and def.walkable then
				return
			end
		end

		local object = minetest.get_objects_inside_radius (tpos, 1.5)
		local vel = vector.multiply (dir, (dir.y > 0 and fan_force / 2) or fan_force)

		for i = 1, #object do
			if object[i].add_velocity then
				local opos = object[i]:get_pos ()

				if opos.x >= (tpos.x - 0.5) and opos.x <= (tpos.x + 0.5) and
					opos.z >= (tpos.z - 0.5) and opos.z <= (tpos.z + 0.5) and
					opos.y >= (tpos.y - 0.5) and opos.y <= (tpos.y + 0.5) then

					if object[i].get_luaentity and object[i]:get_luaentity () and
						object[i]:get_luaentity ().name and
						object[i]:get_luaentity ().name == "__builtin:item" then

						object[i]:add_velocity (vector.multiply (vel, 5))
					else
						object[i]:add_velocity (vel)
					end
				end
			end
		end
	end
end



local function fan_off (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:fan_on" then
			node.name = "lwcomponents:fan"

			minetest.get_node_timer (pos):stop ()
			minetest.swap_node (pos, node)

		elseif node.name == "lwcomponents:fan_locked_on" then
			node.name = "lwcomponents:fan_locked"

			minetest.get_node_timer (pos):stop ()
			minetest.swap_node (pos, node)

		end
	end
end



local function fan_on (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:fan" then
			node.name = "lwcomponents:fan_on"

			minetest.swap_node (pos, node)
			minetest.get_node_timer (pos):start (fan_interval)

		elseif node.name == "lwcomponents:fan_locked" then
			node.name = "lwcomponents:fan_locked_on"

			minetest.swap_node (pos, node)
			minetest.get_node_timer (pos):start (fan_interval)

		end
	end
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
	"size[7.5,3]"..
	"field[1,1;6,2;channel;Channel;${channel}]"..
	"button_exit[2.5,2;3,1;submit;Set]"

	meta:set_string ("formspec", spec)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Fan (owned by "..placer:get_player_name ()..")")
	end

	-- If return true no item is taken from itemstack
	return false
end



local function on_receive_fields (pos, formname, fields, sender)
	if not utils.can_interact_with_node (pos, sender) then
		return
	end

	local meta = minetest.get_meta(pos)

	if fields.submit then
		meta:set_string ("channel", fields.channel)
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
	blow (pos)

	return true
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

								if m[1] == "start" then
									fan_on (pos)

								elseif m[1] == "stop" then
									fan_off (pos)

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
				rules = utils.mesecon_default_rules,

				action_on = function (pos, node)
					-- do something to turn the effector on
					fan_on (pos)
				end,

				action_off = function (pos, node)
					-- do something to turn the effector off
					fan_off (pos)
				end,
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:fan", {
	description = S("Fan"),
	tiles = { "lwfan.png", "lwfan.png", "lwfan.png",
				 "lwfan.png", "lwfan.png", "lwfan_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:fan",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_place = on_place,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
})



minetest.register_node("lwcomponents:fan_locked", {
	description = S("Fan (locked)"),
	tiles = { "lwfan.png", "lwfan.png", "lwfan.png",
				 "lwfan.png", "lwfan.png", "lwfan_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:fan_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_place = on_place,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
})



minetest.register_node("lwcomponents:fan_on", {
	description = S("Fan"),
	tiles = { "lwfan.png", "lwfan.png", "lwfan.png",
				 "lwfan.png", "lwfan.png", "lwfan_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:fan",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_place = on_place,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
})



minetest.register_node("lwcomponents:fan_locked_on", {
	description = S("Fan (locked)"),
	tiles = { "lwfan.png", "lwfan.png", "lwfan.png",
				 "lwfan.png", "lwfan.png", "lwfan_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:fan_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_place = on_place,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
})



end -- utils.digilines_supported or utils.mesecon_supported
