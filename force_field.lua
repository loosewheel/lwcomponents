local utils = ...
local S = utils.S



local field_pulse_interval = 0.2



local function get_bubble (pos)
	local objs = minetest.get_objects_inside_radius (pos, 0.1)

	for _, obj in ipairs (objs) do
		if not obj:is_player () and
			obj.get_luaentity and obj:get_luaentity () and
			obj:get_luaentity ().name and
			obj:get_luaentity ().name == "lwcomponents:force_field_bubble" then

			return obj
		end
	end

	return nil
end



local function spawn_glitter (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local radius = tonumber (meta:get_string ("radius") or 5)

		minetest.add_particlespawner ({
			amount = radius * 5,
			time = 0.5,
			minpos = vector.subtract (pos, radius * 0.707),
			maxpos = vector.add (pos, radius * 0.707),
			minvel = vector.new ({ x = -1, y = -1, z = -1 }),
			maxvel = vector.new ({ x = 1, y = 1, z = 1 }),
			minacc = vector.new (),
			maxacc = vector.new (),
			minexptime = 0.2,
			maxexptime = 0.5,
			minsize = 3,
			maxsize = 6,
			glow = 14,
			texture = "lwcomponents_force_field_zap_1.png",
		})

		minetest.add_particlespawner ({
			amount = radius * 5,
			time = 0.5,
			minpos = vector.subtract (pos, radius * 0.707),
			maxpos = vector.add (pos, radius * 0.707),
			minvel = vector.new ({ x = -1, y = -1, z = -1 }),
			maxvel = vector.new ({ x = 1, y = 1, z = 1 }),
			minacc = vector.new (),
			maxacc = vector.new (),
			minexptime = 0.2,
			maxexptime = 0.5,
			minsize = 3,
			maxsize = 6,
			glow = 14,
			texture = "lwcomponents_force_field_zap_2.png",
		})
	end
end



local function update_bubble (pos)
	local meta = minetest.get_meta (pos)
	local node = utils.get_far_node (pos)

	if meta and node and (node.name == "lwcomponents:force_field_on" or
								 node.name == "lwcomponents:force_field_locked_on") then
		local radius = tonumber (meta:get_string ("radius") or 10)
		local bubble = get_bubble (pos)

		if not bubble then
			local staticdata = { }

			bubble = minetest.add_entity (pos,
													"lwcomponents:force_field_bubble",
													minetest.serialize (staticdata))
		end

		if bubble then
			local props = bubble:get_properties ()
			props.visual_size = { x = radius * 2, y = radius * 2, z = radius * 2 }
			bubble:set_properties (props)
			bubble:set_armor_groups ({ immortal = 1 })
		end
	end
end



local function remove_bubble (pos)
	local bubble = get_bubble (pos)

	if bubble then
		bubble:remove ()
	end
end



local function check_fuel (pos, used)
	local meta = minetest.get_meta (pos)

	if meta then
		local power = meta:get_float ("power")

		if used > power then
			local inv = (meta and meta:get_inventory ()) or nil

			if inv then
				while power < used do
					local fuel, afterfuel =
						minetest.get_craft_result ({ method = "fuel",
															  width = 1,
															  items = inv:get_list ("fuel") })

					if fuel.time > 0 then
						-- Take fuel from fuel list
						inv:set_stack ("fuel", 1, afterfuel.items[1])
						power = power + fuel.time
					else
						-- No valid fuel in fuel list
						break
					end
				end
			end
		end

		if used > power then
			meta:set_float ("power", 0)

			return false
		else
			meta:set_float ("power", power - used)
		end
	end

	return true
end



local function update_formspec (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local stopstart = minetest.get_node_timer (pos):is_started () and
		"button[8.7,1.0;2.0,0.8;stop;Stop]" or
		"button[8.7,1.0;2.0,0.8;start;Start]"

		local spec =
		"formspec_version[3]"..
		"size[11.7,12.8;true]"..
		"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]"..
		"button[5.0,1.0;2.0,0.8;setchannel;Set]"..
		stopstart..
		"field[1.0,2.5;4.0,0.8;radius;Radius;${radius}]"..
		"button[5.0,2.5;2.0,0.8;setradius;Set]"..
		"textarea[1.0,4.0;6.5,2.4;exclude;Permit;${exclude}]"..
		"button[7.5,4.0;2.0,0.8;setexclude;Set]"..
		"list[context;fuel;9.2,2.5;1,1;]"..
		"list[current_player;main;1.0,7.0;8,4;]\n"..
		"listring[]"

		meta:set_string ("formspec", spec)
	end
end



local function turn_on (pos)
	local node = utils.get_far_node (pos)

	if node then
		if node.name == "lwcomponents:force_field" then
			if check_fuel (pos, 0.001) then
				node.name = "lwcomponents:force_field_on"
				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):start (field_pulse_interval)
				update_formspec (pos)
				update_bubble (pos)
				spawn_glitter (pos)
			end

		elseif node.name == "lwcomponents:force_field_locked" then
			if check_fuel (pos, 0.001) then
				node.name = "lwcomponents:force_field_locked_on"
				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):start (field_pulse_interval)
				update_formspec (pos)
				update_bubble (pos)
				spawn_glitter (pos)
			end
		end
	end
end



local function turn_off (pos)
	local node = utils.get_far_node (pos)

	if node then
		if node.name == "lwcomponents:force_field_on" then
			remove_bubble (pos)
			node.name = "lwcomponents:force_field"
			minetest.swap_node (pos, node)
			minetest.get_node_timer (pos):stop ()
			update_formspec (pos)
			spawn_glitter (pos)

		elseif node.name == "lwcomponents:force_field_locked_on" then
			remove_bubble (pos)
			node.name = "lwcomponents:force_field_locked"
			minetest.swap_node (pos, node)
			minetest.get_node_timer (pos):stop ()
			update_formspec (pos)
			spawn_glitter (pos)
		end
	end
end



local function run_zap (pos)
	minetest.sound_play ("lwforce_field_zap", { pos = pos, max_hear_distance = 10, gain = 1.0 })

	minetest.add_particle ({
		pos = pos,
		velocity = vector.new (),
		acceleration = vector.new (),
		expirationtime = 0.1,
		size = 10,
		collisiondetection = false,
		vertical = false,
		texture = (math.random (10) < 6 and "lwcomponents_force_field_zap_1.png") or
						"lwcomponents_force_field_zap_2.png",
		glow = 14,
	})
end



local function run_field (pos, elapsed)
	local meta = minetest.get_meta (pos)

	if meta then
		local radius = tonumber (meta:get_string ("radius") or 10)
		local exclude = { }
		local count = 0
		local owner = meta:get_string ("owner")

		update_bubble (pos)

		for player in string.gmatch (meta:get_string ("exclude"), "[^\n]+") do
			if player and player ~= "" then
				exclude[player] = true
			end
		end

		if owner ~= "" then
			exclude[owner] = true
		end

		local objs = minetest.get_objects_inside_radius (pos, radius + 1)

		for _, obj in ipairs (objs) do
			local obj_pos = (obj.get_pos and obj:get_pos ()) or nil

			if obj_pos and not obj:get_armor_groups ().immortal then
				if not utils.is_drop (obj) and not minetest.is_protected (obj_pos, owner) then

					if obj:is_player () then
						if not exclude[obj:get_player_name ()] then
							local vel = vector.multiply (vector.direction (pos, obj_pos), 30)

							obj:punch (obj,
										  1.0,
										  { full_punch_interval = 1.0,
											 damage_groups = { fleshy = 1 } },
											vector.direction (pos, obj_pos))

							obj:add_velocity (vel)
							count = count + 1
							run_zap (obj_pos)
						end
					else
						local luaent = (obj.get_luaentity and obj:get_luaentity ()) or nil
						local name = obj:get_nametag_attributes ()
						local label = ""

						if type (name) == "table" then
							label = tostring (name.text or "")
						end

						name = (luaent and luaent.name) or ""

						if (name == "" and label == "") or
							((not (name ~= "" and exclude[name])) and
							 (not (label ~= "" and exclude[label]))) then

							local vel = vector.multiply (vector.direction (pos, obj_pos), 30)

							obj:punch (obj,
										  1.0,
										  { full_punch_interval = 1.0,
											 damage_groups = { fleshy = 2 } },
											vector.direction (pos, obj_pos))

							obj:set_velocity (vel)
							count = count + 1
							run_zap (obj_pos)
						end
					end
				end
			end
		end

		if not check_fuel (pos, ((radius * 0.16) * elapsed) + count) then
			turn_off (pos)

			return false
		end
	end

	return true
end



local function set_radius (pos, radius)
	local meta = minetest.get_meta (pos)

	if meta then
		radius = math.min (math.max (tonumber (radius) or 5, 5), 25)

		meta:set_string ("radius", tostring (radius))
		update_bubble (pos)
	end
end



local function add_exclude (pos, name)
	local meta = minetest.get_meta (pos)
	name = tostring (name or "")

	if meta and name ~= "" then
		local exclude = { }

		for player in string.gmatch (meta:get_string ("exclude"), "[^\n]+") do
			if player and player ~= "" then
				if player == name then
					return
				end

				exclude[#exclude + 1] = player
			end
		end

		exclude[#exclude + 1] = name

		meta:set_string ("exclude", table.concat (exclude, "\n"))
	end
end



local function remove_exclude (pos, name)
	local meta = minetest.get_meta (pos)
	name = tostring (name or "")

	if meta and name ~= "" then
		local exclude = { }

		for player in string.gmatch (meta:get_string ("exclude"), "[^\n]+") do
			if player and player ~= "" and player ~= name then
				exclude[#exclude + 1] = player
			end
		end

		meta:set_string ("exclude", table.concat (exclude, "\n"))
	end
end



local function send_status_message (pos)
	if utils.digilines_supported then
		local node = utils.get_far_node (pos)
		local meta = minetest.get_meta (pos)
		local inv = (meta and meta:get_inventory ()) or nil

		if node and meta and inv then
			local channel = meta:get_string ("channel")
			local state = "off"
			local exclude = { }
			local radius = tonumber (meta:get_string ("radius"))
			local fuel = { name = "", count = 0 }

			if node.name == "lwcomponents:force_field_on" or
				node.name == "lwcomponents:force_field_locked_on" then

				state = "on"
			end

			for player in string.gmatch (meta:get_string ("exclude"), "[^\n]+") do
				if player and player ~= "" then
					exclude[#exclude + 1] = player
				end
			end

			local stack = inv:get_stack ("fuel", 1)
			if stack and not stack:is_empty () then
				fuel.name = stack:get_name ()
				fuel.count = stack:get_count ()
			end

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "status",
															state = state,
															radius = radius,
															permit = exclude,
															fuel = fuel })
			end
		end
	end
end



local function on_destruct (pos)
	remove_bubble (pos)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)

	meta:set_string ("radius", "10")
	meta:set_string ("exclude", "")
	meta:set_string ("inventory", "{ fuel = { } }")
	update_formspec (pos)

	local inv = meta:get_inventory ()

	inv:set_size ("fuel", 1)
	inv:set_width ("fuel", 1)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Force Field Generator (owned by "..placer:get_player_name ()..")")
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

	if fields.setradius then
		local meta = minetest.get_meta (pos)

		if meta then
			local radius = math.min (math.max (tonumber (fields.radius) or 5, 5), 25)
			fields.radius = tostring (radius)

			meta:set_string ("radius", tostring (radius))
			update_bubble (pos)
		end
	end

	if fields.setexclude then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("exclude", fields.exclude)
		end
	end

	if fields.start then
		turn_on (pos)
	end

	if fields.stop then
		turn_off (pos)
	end
end



local function can_dig (pos, player)
	if not utils.can_interact_with_node (pos, player) then
		return false
	end

	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			if not inv:is_empty ("fuel") then
				return false
			end
		end
	end

	return true
end



local function on_blast (pos, intensity)
	local meta = minetest.get_meta (pos)

	if meta then
		if intensity >= 1.0 then
			local inv = meta:get_inventory ()

			if inv then
				local slots = inv:get_size ("fuel")

				for slot = 1, slots do
					local stack = inv:get_stack ("fuel", slot)

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
				local slots = inv:get_size ("fuel")

				for slot = 1, slots do
					local stack = inv:get_stack ("fuel", slot)

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
						utils.item_drop (stack, nil, pos)
						on_destruct (pos)
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



local function on_timer (pos, elapsed)
	local result = run_field (pos, elapsed)

	return result
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
									if m[1] == "start" then
										turn_on (pos)

									elseif m[1] == "stop" then
										turn_off (pos)

									elseif m[1] == "radius" then
										set_radius (pos,  m[2])

									elseif m[1] == "add" then
										add_exclude (pos, msg:sub (5, -1))

									elseif m[1] == "remove" then
										remove_exclude (pos, msg:sub (8, -1))

									elseif m[1] == "status" then
										send_status_message (pos)

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



local function mesecon_support ()
	if utils.mesecon_supported then
		return
		{
			effector =
			{
				rules = utils.mesecon_default_rules,

				action_on = function (pos, node)
					-- do something to turn the effector on
					turn_on (pos)
				end,

				action_off = function (pos, node)
					-- do something to turn the effector off
					turn_off (pos)
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
			input_inventory = "fuel",
			connect_sides = { left = 1, right = 1, front = 1, back = 1, bottom = 1 },

			insert_object = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:add_item ("fuel", stack)
				end

				return stack
			end,

			can_insert = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:room_for_item ("fuel", stack)
				end

				return false
			end,

			can_remove = function (pos, node, stack, dir)
				-- returns the maximum number of items of that stack that can be removed
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					local slots = inv:get_size ("fuel")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("fuel", i)

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
					local slots = inv:get_size ("fuel")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("fuel", i)

						if s and not s:is_empty () and utils.is_same_item (s, stack) then
							if s:get_count () > left then
								s:set_count (s:get_count () - left)
								inv:set_stack ("fuel", i, s)
								left = 0
							else
								left = left - s:get_count ()
								inv:set_stack ("fuel", i, nil)
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



local force_field_groups = { cracky = 3, wires_connect = 1 }
if utils.pipeworks_supported then
	force_field_groups.tubedevice = 1
	force_field_groups.tubedevice_receiver = 1
end



local force_field_on_groups = { cracky = 3, not_in_creative_inventory = 1, wires_connect = 1 }
if utils.pipeworks_supported then
	force_field_on_groups.tubedevice = 1
	force_field_on_groups.tubedevice_receiver = 1
end



minetest.register_node("lwcomponents:force_field", {
	description = S("Force Field Generator"),
	tiles = { "lwcomponents_force_field.png", "lwcomponents_force_field.png", "lwcomponents_force_field.png",
				 "lwcomponents_force_field.png", "lwcomponents_force_field.png", "lwcomponents_force_field.png"},
	is_ground_content = false,
	groups = table.copy (force_field_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:force_field",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:force_field_locked", {
	description = S("Force Field Generator (locked)"),
	tiles = { "lwcomponents_force_field.png", "lwcomponents_force_field.png", "lwcomponents_force_field.png",
				 "lwcomponents_force_field.png", "lwcomponents_force_field.png", "lwcomponents_force_field.png"},
	is_ground_content = false,
	groups = table.copy (force_field_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:force_field_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:force_field_on", {
	description = S("Force Field Generator"),
	tiles = { "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png",
				 "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png"},
	is_ground_content = false,
	groups = table.copy (force_field_on_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:force_field",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_node("lwcomponents:force_field_locked_on", {
	description = S("Force Field Generator (locked)"),
	tiles = { "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png",
				 "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png", "lwcomponents_force_field_on.png"},
	is_ground_content = false,
	groups = table.copy (force_field_on_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:force_field_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer
})



minetest.register_entity ("lwcomponents:force_field_bubble", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		collisionbox = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
		selectionbox = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
		pointable = false,
		visual = "mesh",
		visual_size = { x = 1, y = 1, z = 1 },
		mesh = "lwcomponents_force_field_bubble.obj",
		textures = { "lwcomponents_force_field_bubble.png" },
		use_texture_alpha = true,
		is_visible = true,
		makes_footstep_sound = false,
		automatic_rotate = 0.35,
		backface_culling = false,
		damage_texture_modifier = "",
		glow = 14,
		static_save = true,
		shaded = true,
		show_on_minimap = false,
	},

	on_activate = function (self, staticdata, dtime_s)
		self.staticdata = staticdata
	end,

	get_staticdata = function (self)
		return self.staticdata
	end,

	on_step = function (self, dtime, moveresult)
	end,

	on_punch = function (self, puncher, time_from_last_punch, tool_capabilities, dir)
		return true
	end,

	on_blast = function (self, damage)
		return false, false, nil
	end,
})



utils.hopper_add_container({
	{"top", "lwcomponents:force_field", "fuel"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:force_field", "fuel"}, -- insert items below from hopper above
	{"side", "lwcomponents:force_field", "fuel"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:force_field_locked", "fuel"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:force_field_locked", "fuel"}, -- insert items below from hopper above
	{"side", "lwcomponents:force_field_locked", "fuel"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:force_field_on", "fuel"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:force_field_on", "fuel"}, -- insert items below from hopper above
	{"side", "lwcomponents:force_field_on", "fuel"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:force_field_locked_on", "fuel"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:force_field_locked_on", "fuel"}, -- insert items below from hopper above
	{"side", "lwcomponents:force_field_locked_on", "fuel"}, -- insert items from hopper at side
})



--
