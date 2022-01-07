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



local function push_entities (pos, vec)
	local tpos = vector.add (pos, vec)
	local tnode = utils.get_far_node (tpos)
	local can_move = false

	if tnode then
		if tnode.name == "air" then
			can_move = true
		else
			tdef = utils.find_item_def (tnode.name)

			can_move = tdef and not tdef.walkable
		end
	end

	if can_move then
		local object = minetest.get_objects_inside_radius (pos, 1.5)

		for j = 1, #object do
			if object[j].get_pos then
				local opos = object[j]:get_pos ()

				if opos.x > (pos.x - 0.5) and opos.x < (pos.x + 0.5) and
					opos.z > (pos.z - 0.5) and opos.z < (pos.z + 0.5) and
					opos.y > (pos.y - 0.5) and opos.y < (pos.y + 0.5) then

					object[j]:set_pos (vector.add (opos, vec))
				end
			end
		end
	end
end



local function push_nodes (pos, extent)
	local node = utils.get_far_node (pos)

	if node then
		local vec = direction_vector (node)
		local last = vector.add (pos, vector.multiply (vec, extent))
		local maxnodes = utils.settings.max_piston_nodes + 1
		local count = 0

		for i = 1, maxnodes do
			local tnode = utils.get_far_node (last)

			if not tnode then
				return false
			end

			if tnode.name == "air" then
				count = i - 1
				break
			end

			if i == maxnodes then
				return false
			end

			last = vector.add (last, vec)
		end

		push_entities (last, vec)

		for i = 1, count, 1 do
			local cpos = vector.subtract (last, vec)
			local cnode = utils.get_far_node (cpos)
			local cmeta = minetest.get_meta (cpos)

			if not cnode or not cmeta then
				return false
			end

			local tmeta = cmeta:to_table ()

			push_entities (cpos, vec)

			minetest.remove_node (cpos)
			minetest.set_node (last, cnode)

			if tmeta then
				cmeta = minetest.get_meta (last)

				if not cmeta then
					return false
				end

				cmeta:from_table (tmeta)
			end

			last = cpos
		end
	end

	return true
end



local function pull_node (pos, extent)
	local node = utils.get_far_node (pos)

	if node then
		local vec = direction_vector (node)
		local cpos = vector.add (pos, vector.multiply (vec, extent))
		local cnode = utils.get_far_node (cpos)

		if cnode and cnode ~= "air" then
			local cmeta = minetest.get_meta (cpos)

			if cmeta then
				local tpos = vector.subtract (cpos, vec)
				local tmeta = cmeta:to_table ()

				minetest.remove_node (cpos)
				minetest.set_node (tpos, cnode)

				if tmeta then
					cmeta = minetest.get_meta (tpos)

					if cmeta then
						cmeta:from_table (tmeta)
					end
				end
			end
		end
	end
end



local function place_blank (pos, extent)
	local node = utils.get_far_node (pos)

	if node then
		local vec = direction_vector (node)
		local blank_pos = vector.add (pos, vector.multiply (vec, extent))
		local blank_node = utils.get_far_node (blank_pos)

		if blank_node and blank_node.name == "air" then
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
						preserve_metadata (pos, node, meta, { stack })
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
				rules = utils.mesecon_default_rules,

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
	paramtype = "none",
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



minetest.register_node("lwcomponents:piston", {
	description = S("Piston"),
	tiles = { "lwcomponents_piston_top.png", "lwcomponents_piston_bottom.png",
				 "lwcomponents_piston_right.png", "lwcomponents_piston_left.png",
				 "lwcomponents_piston_base.png", "lwcomponents_piston_pusher.png" },
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
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
	description = S("Piston"),
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
	groups = { cracky = 3 , not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
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
	description = S("Piston"),
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
	groups = { cracky = 3 , not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
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
	description = S("Sticky Piston"),
	tiles = { "lwcomponents_piston_top.png", "lwcomponents_piston_bottom.png",
				 "lwcomponents_piston_right.png", "lwcomponents_piston_left.png",
				 "lwcomponents_piston_base.png", "lwcomponents_piston_pusher_sticky.png" },
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
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
	description = S("Sticky Piston"),
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
	groups = { cracky = 3 , not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
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
	description = S("Sticky Piston"),
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
	groups = { cracky = 3 , not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
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
