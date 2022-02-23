local utils = ...
local S = utils.S



local cannon_force = 20
local min_pitch = -20
local max_pitch = 70
local min_rotation = -60
local max_rotation = 60



local function get_cannon_barrel (pos)
	local barrel_pos = { x = pos.x, y = pos.y + 0.65, z = pos.z }
	local objects = minetest.get_objects_inside_radius (barrel_pos, 0.1)

	for i = 1, #objects do
		if not objects[i]:is_player () then
			if objects[i].get_luaentity and objects[i]:get_luaentity () and
				objects[i]:get_luaentity ().name and
				objects[i]:get_luaentity ().name == "lwcomponents:cannon_barrel" then

				return objects[i]
			end
		end
	end
end



local function get_barrel_pos (pos)
	local barrel = get_cannon_barrel (pos)

	if barrel then
		return barrel:get_pos ()
	end

	return nil
end



local function get_barrel_angle (pos)
	local node = minetest.get_node_or_nil (pos)
	local barrel = get_cannon_barrel (pos)

	if barrel and node then
		local cur = barrel:get_rotation ()
		local node_rot = vector.dir_to_rotation (minetest.facedir_to_dir (node.param2))
		local rot = (cur.y - node_rot.y) * 180 / math.pi

		if (node.param2 % 2) == 0 then
			rot = -rot
		end

		return {
			x = cur.x * -180 / math.pi,
			y = rot,
			z = 0
		}
	end

	return nil
end



local function set_barrel_rotation (pos, angle)
	local node = minetest.get_node_or_nil (pos)
	local barrel = get_cannon_barrel (pos)

	angle = tonumber (angle)

	if angle and barrel and node then
		local cur = barrel:get_rotation ()
		local node_rot = vector.dir_to_rotation (minetest.facedir_to_dir (node.param2))

		angle = math.max (math.min (angle, max_rotation), min_rotation)

		if (node.param2 % 2) == 0 then
			angle = -angle
		end

		cur.y = node_rot.y + (angle * math.pi / 180)
		cur.z = 0

		barrel:set_rotation (cur)
	end
end



local function set_barrel_pitch (pos, pitch)
	local node = minetest.get_node_or_nil (pos)
	local barrel = get_cannon_barrel (pos)

	pitch = tonumber (pitch)

	if pitch and barrel and node then
		local cur = barrel:get_rotation ()

		cur.x = (math.max (math.min (pitch, max_pitch), min_pitch) / -180 * math.pi)
		cur.z = 0

		barrel:set_rotation (cur)
	end
end



local function start_flash (pos)
	local blank_pos = { x = pos.x, y = pos.y + 1, z = pos.z }
	local blank = minetest.get_node_or_nil (blank_pos)
	local node_timer = minetest.get_node_timer (pos)

	if node_timer and blank and blank.name == "lwcomponents:cannon_blank" then
		node_timer:stop ()
		minetest.set_node (blank_pos, { name = "lwcomponents:cannon_blank_fire" })
		node_timer:start (0.5)
	end
end



local function cancel_flash (pos)
	local blank_pos = { x = pos.x, y = pos.y + 1, z = pos.z }
	local blank = minetest.get_node_or_nil (blank_pos)

	if blank and blank.name == "lwcomponents:cannon_blank_fire" then
		minetest.set_node (blank_pos, { name = "lwcomponents:cannon_blank" })
	end
end



local function set_barrel_angle_delayed (pos, pitch, rotation)
	pitch = pitch and tonumber (pitch)
	rotation = rotation and tonumber (rotation)
	local node = minetest.get_node_or_nil (pos)

	if node and pitch or rotation then
		local angle = get_barrel_angle (pos)
		local node_timer = minetest.get_node_timer (pos)
		local meta = minetest.get_meta (pos)
		local was_set = false

		if angle and node_timer and meta then
			cancel_flash (pos)

			if pitch then
				pitch = math.floor (math.max (math.min (pitch, max_pitch), min_pitch) - angle.x)

				if pitch ~= 0 then
					meta:set_int ("barrel_pitch", pitch)
					was_set = true
				end
			end

			if rotation then
				if (node.param2 % 2) == 1 then
					rotation = -rotation
				end

				rotation = math.floor (math.max (math.min (rotation, max_rotation), min_rotation) - angle.y)

				if rotation ~= 0 then
					meta:set_int ("barrel_rotate", rotation)
					was_set = true
				end
			end

			if was_set then
				node_timer:stop ()
				node_timer:start (0.1)
			end
		end
	end
end



local function aim_barrel_delayed (pos, aimpos)
	local x = tonumber (aimpos.x) or 0
	local y = tonumber (aimpos.y) or 0
	local z = tonumber (aimpos.z) or 0

	if z < 1 then
		return
	end

	local angle = vector.dir_to_rotation (aimpos)

	local rot = math.floor (math.deg (-angle.y) + 0.5)
	local pitch = math.floor (math.deg (angle.x) + 0.5)

	set_barrel_angle_delayed (pos, pitch, rot)
end



local function fire_cannon (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		if meta:get_int ("barrel_pitch") ~= 0 or
			meta:get_int ("barrel_rotate") ~= 0 then

			return false
		end

		local inv = meta:get_inventory ()

		if inv then
			local stack = inv:get_stack ("main", 1)

			if not stack:is_empty () and stack:get_count () > 0 then
				local name = stack:get_name ()
				local item = ItemStack (stack)

				if item then
					item:set_count (1)

					local barrel = get_cannon_barrel (pos)

					if barrel then
						local ammo_pos = barrel:get_pos ()
						local ammo_angle = barrel:get_rotation (pos)

						if ammo_pos and ammo_angle then
							local dir = vector.rotate ({ x = 0, y = 0, z = -1 }, ammo_angle)
							local owner = meta:get_string ("owner")
							local obj, cancel = nil, false
							local spawn_pos = { x = ammo_pos.x + dir.x,
													  y = ammo_pos.y + dir.y,
													  z = ammo_pos.z + dir.z }

							if utils.settings.spawn_mobs then
								obj, cancel = utils.spawn_registered (name,
																				  spawn_pos,
																				  item,
																				  owner,
																				  pos,
																				  dir,
																				  cannon_force)

								if obj == nil and cancel then
									return false
								end
							end

							if not obj then
								obj = minetest.add_item (spawn_pos, item)

								if obj then
									local vel = vector.multiply (dir, cannon_force)

									obj:set_velocity (vel)
								end
							end

							if obj then
								stack:set_count (stack:get_count () - 1)
								inv:set_stack ("main", 1, stack)

								start_flash (pos)

								minetest.sound_play ("lwcannon",
															{
																pos = pos,
																gain = 1.0,
																max_hear_distance = 20
															},
															true)

								--send_fired_message (pos, slot, name)

								return true, name
							end
						end
					end
				end
			end
		end
	end
end



local function process_controller_input (pos, input)
	local node = minetest.get_node_or_nil (pos)
	local meta = minetest.get_meta (pos)

	if meta and node then
		local owner = meta:get_string ("owner")

		if owner:len () < 1 or owner == input.name then
			local pitch = input.pitch * -180 / math.pi
			local node_rot = vector.dir_to_rotation (minetest.facedir_to_dir ((node.param2 + 2) % 4))
			local rot = (input.yaw - node_rot.y) * 180 / math.pi
			local sensitivity = (meta:get_string ("sensitive") == "true" and 3) or 1

			while rot > 180 do
				rot = rot - 360
			end

			while rot < -180 do
				rot = rot + 360
			end

			if (node.param2 % 2) == 0 then
				rot = -rot
			end

			set_barrel_pitch (pos, pitch * sensitivity)
			set_barrel_rotation (pos, rot * sensitivity)

			if input.dig then
				fire_cannon (pos)
			end
		end
	end
end



local function get_formspec (pos)
	local meta = minetest.get_meta (pos)
	local sensitive = (meta and meta:get_string ("sensitive")) or "false"

	return
	"formspec_version[3]\n"..
	"size[11.75,10.75;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"button[8.5,1.0;2.0,0.8;hide;Hide]\n"..
	"field[1.0,2.6;4.0,0.8;controller;Controller;${controller}]\n"..
	"button[5.5,2.6;2.0,0.8;setcontroller;Set]\n"..
	"checkbox[1.3,3.8;sensitive;Sensitive;"..sensitive.."]\n"..
	"list[context;main;9.0,2.75;1,1;]\n"..
	"list[current_player;main;1.0,5.0;8,4;]\n"..
	"listring[]"
end



local function can_place (pos, player)
	local above = { x = pos.x, y = pos.y + 1, z = pos.z }

	return utils.can_place (pos) and utils.can_place (above) and
			 not utils.is_protected (pos, player) and
			 not utils.is_protected (above, player)
end



local function on_construct (pos)
	local barrel_pos = { x = pos.x, y = pos.y + 0.65, z = pos.z }
	local blank_pos = { x = pos.x, y = pos.y + 1, z = pos.z }
	local staticdata =
	{
		base_pos = { x = pos.x, y = pos.y, z = pos.z },
		blank_pos = blank_pos,
	}

	local barrel = minetest.add_entity (barrel_pos,
													"lwcomponents:cannon_barrel",
													minetest.serialize (staticdata))

	if barrel then
		set_barrel_rotation (pos, 0)
		set_barrel_pitch (pos, 0)
		barrel:set_armor_groups ({ immortal = 1 })
	end

	minetest.set_node (blank_pos, { name = "lwcomponents:cannon_blank" })
end



local function on_destruct (pos)
	local blank_pos = { x = pos.x, y = pos.y + 1, z = pos.z }
	local blank = minetest.get_node_or_nil (blank_pos)
	local barrel = get_cannon_barrel (pos)

	if barrel then
		barrel:remove ()
	end

	if blank and (blank.name == "lwcomponents:cannon_blank" or
					  blank.name == "lwcomponents:cannon_blank_fire") then
		minetest.remove_node (blank_pos)
	end
end



local function after_place_base (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)

	meta:set_string ("sensitive", "true")
	meta:set_string ("inventory", "{ main = { } }")

	local inv = meta:get_inventory ()

	inv:set_size ("main", 1)
	inv:set_width ("main", 1)

	meta:set_string ("formspec", get_formspec (pos))
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	after_place_base (pos, placer, itemstack, pointed_thing)
	utils.pipeworks_after_place (pos)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_base (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Cannon (owned by "..placer:get_player_name ()..")")
	end

	utils.pipeworks_after_place (pos)

	-- If return true no item is taken from itemstack
	return false
end



local function on_place (itemstack, placer, pointed_thing)
	if pointed_thing and pointed_thing.type == "node" and placer and  placer:is_player () then
		local param2 = 0
		local pos = pointed_thing.under

		local on_rightclick = utils.get_on_rightclick (pos, placer)
		if on_rightclick then
			return on_rightclick (pos, minetest.get_node (pos), placer, itemstack, pointed_thing)
		end

		if not can_place (pos, placer) then
			pos = pointed_thing.above

			if not can_place (pos, placer) then
				return itemstack
			end
		end

		if placer and placer:is_player () then
			param2 = (minetest.dir_to_facedir (placer:get_look_dir (), false) + 2) % 4
		end

		minetest.set_node (pos, { name = "lwcomponents:cannon", param1 = 0, param2 = param2 })
		after_place_node (pos, placer, itemstack, pointed_thing)

		if not utils.is_creative (player) then
			itemstack:set_count (itemstack:get_count () - 1)
		end
	end

	return itemstack
end



local function on_place_locked (itemstack, placer, pointed_thing)
	if pointed_thing and pointed_thing.type == "node" and placer and  placer:is_player () then
		local param2 = 0
		local pos = pointed_thing.under

		local on_rightclick = utils.get_on_rightclick (pos, placer)
		if on_rightclick then
			return on_rightclick (pos, minetest.get_node (pos), placer, itemstack, pointed_thing)
		end

		if not can_place (pos, placer) then
			pos = pointed_thing.above

			if not can_place (pos, placer) then
				return itemstack
			end
		end

		if placer and placer:is_player () then
			param2 = (minetest.dir_to_facedir (placer:get_look_dir (), false) + 2) % 4
		end

		minetest.set_node (pos, { name = "lwcomponents:cannon_locked", param1 = 0, param2 = param2 })
		after_place_node_locked (pos, placer, itemstack, pointed_thing)

		if not utils.is_creative (player) then
			itemstack:set_count (itemstack:get_count () - 1)
		end
	end

	return itemstack
end



local function can_dig (pos, player)
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

	if fields.setcontroller then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("controller", fields.controller)
		end
	end

	if fields.hide then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("formspec", "")
		end
	end

	if fields.sensitive ~= nil then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("sensitive", fields.sensitive)
			meta:set_string ("formspec", get_formspec (pos))
		end
	end
end



local function on_blast (pos, intensity)
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

	else
		local meta = minetest.get_meta (pos)

		if meta then
			local formspec = meta:get_string ("formspec")

			if formspec == "" then
				local hit = minetest.pointed_thing_to_face_pos (clicker, pointed_thing)
				hit.x = hit.x - pos.x
				hit.y = hit.y - pos.y
				hit.z = hit.z - pos.z

				local hx = hit.x
				local hy = hit.y
				local hz = hit.z
				local inc = (clicker:get_player_control ().aux1 and 1) or 10

				if node.param2 == 1 then
					hx = hit.z
					hz = hit.x
				elseif node.param2 == 2 then
					hx = -hit.x
					hz = -hit.z
				elseif node.param2 == 3 then
					hx = -hit.z
					hz = -hit.x
				end

				if hz == 0.5 and hy >= -0.5 and hy <= 0.2 then
					local angle = get_barrel_angle  (pos)

					if angle then
						if hx >= -0.5 and hx <= -0.25 and hy >= -0.25 and hy <= -0.0625 then
							-- left
							set_barrel_rotation (pos, angle.y + inc)
						elseif hx >= 0.25 and hx <= 0.5 and hy >= -0.25 and hy <= -0.0625 then
							-- right
							set_barrel_rotation (pos, angle.y - inc)
						elseif hx >= -0.125 and hx <= 0.125 and hy >= 0.0 and hy <= 0.1875 then
							-- up
							set_barrel_pitch (pos, angle.x + inc)
						elseif hx >= -0.125 and hx <= 0.125 and hy >= -0.5 and hy <= -0.3125 then
							-- down
							set_barrel_pitch (pos, angle.x - inc)
						elseif hx >= -0.125 and hx <= 0.125 and hy >= -0.25 and hy <= -0.0625 then
							-- fire
							fire_cannon (pos)
						end
					end
				else
					meta:set_string ("formspec", get_formspec (pos))
				end
			end
		end
	end

	return itemstack
end



local function on_timer (pos, elapsed)
	local meta = minetest.get_meta (pos)

	if meta then
		local barrel_pitch = meta:get_int ("barrel_pitch")
		local barrel_rotate = meta:get_int ("barrel_rotate")

		if barrel_pitch ~= 0 or barrel_rotate ~= 0 then
			local angle = get_barrel_angle (pos)

			if angle then
				if barrel_pitch < -10 then
					angle.x = angle.x - 10
					barrel_pitch = barrel_pitch + 10
				elseif barrel_pitch > 10 then
					angle.x = angle.x + 10
					barrel_pitch = barrel_pitch - 10
				else
					angle.x = angle.x + barrel_pitch
					barrel_pitch = 0
				end

				if barrel_rotate < -10 then
					angle.y = angle.y - 10
					barrel_rotate = barrel_rotate + 10
				elseif barrel_rotate > 10 then
					angle.y = angle.y + 10
					barrel_rotate = barrel_rotate - 10
				else
					angle.y = angle.y + barrel_rotate
					barrel_rotate = 0
				end

				set_barrel_pitch (pos, angle.x)
				set_barrel_rotation (pos, angle.y)

				meta:set_int ("barrel_pitch", barrel_pitch)
				meta:set_int ("barrel_rotate", barrel_rotate)
			end

			return barrel_pitch ~= 0 or barrel_rotate ~= 0
		end
	end

	cancel_flash (pos)

	return false
end



local function digilines_support ()
	if utils.digilines_supported then
		return
		{
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
									if m[1] == "pitch" then
										set_barrel_angle_delayed (pos, m[2], nil)

									elseif m[1] == "rotation" then
										set_barrel_angle_delayed (pos, nil, m[2])

									elseif m[1] == "fire" then
										fire_cannon (pos)

									end
								end

							elseif type (msg) == "table" then
								local controller = meta:get_string ("controller")

								if controller:len () > 0 and controller == channel and
									msg.pitch and msg.yaw and msg.name and msg.look_vector then

									process_controller_input (pos, msg)

								elseif type (msg.action) == "string" and msg.action == "aim" and
									type (msg.aim) == "table" then

									aim_barrel_delayed (pos, msg.aim)

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
				rules = utils.mesecon_flat_rules,

				action_on = function (pos, node)
					fire_cannon (pos)
				end
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
			input_inventory = "main",
			connect_sides = { left = 1, right = 1, front = 1, back = 1, bottom = 1 },

			insert_object = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:add_item ("main", stack)
				end

				return stack
			end,

			can_insert = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:room_for_item ("main", stack)
				end

				return false
			end,

			can_remove = function (pos, node, stack, dir)
				-- returns the maximum number of items of that stack that can be removed
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					local slots = inv:get_size ("main")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("main", i)

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
					local slots = inv:get_size ("main")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("main", i)

						if s and not s:is_empty () and utils.is_same_item (s, stack) then
							if s:get_count () > left then
								s:set_count (s:get_count () - left)
								inv:set_stack ("main", i, s)
								left = 0
							else
								left = left - s:get_count ()
								inv:set_stack ("main", i, nil)
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



local cannon_groups = { cracky = 3 }
if utils.pipeworks_supported then
	cannon_groups.tubedevice = 1
	cannon_groups.tubedevice_receiver = 1
end



minetest.register_node("lwcomponents:cannon_blank", {
	description = S("Cannon blank"),
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



minetest.register_node("lwcomponents:cannon_blank_fire", {
	description = S("Cannon blank"),
	drawtype = "airlike",
	light_source = 7,
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



minetest.register_node("lwcomponents:cannon", {
	description = S("Cannon"),
	tiles = {
		"lwcannon_top.png",
		"lwcannon_bottom.png",
		"lwcannon.png",
		"lwcannon.png",
		"lwcannon_face.png",
		"lwcannon.png"
	},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.09, 0, -0.09, 0.09, 0.5, 0.09 },
			{ -0.5, -0.25, -0.5, 0.5, 0.125, 0.5 },
			{ -0.4375, -0.1875, -0.4375, 0.4375, 0.1875, 0.5 },
			{ -0.5, -0.5, 0.3125, 0.5, 0.125, 0.5 },
			{ -0.5, -0.5, -0.5, -0.3125, 0.125, -0.3125 },
			{ 0.3125, -0.5, -0.5, 0.5, 0.125, -0.3125 },
		}
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.85, 0.5 }
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.1875, 0.5 }
		}
	},
	wield_image = "lwcannon_item.png",
	inventory_image = "lwcannon_item.png",
	is_ground_content = false,
	groups = table.copy (cannon_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:cannon",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_construct = on_construct,
	on_destruct = on_destruct,
	on_place = on_place,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer,
})



minetest.register_node("lwcomponents:cannon_locked", {
	description = S("Cannon (locked)"),
	tiles = {
		"lwcannon_top.png",
		"lwcannon_bottom.png",
		"lwcannon.png",
		"lwcannon.png",
		"lwcannon_face.png",
		"lwcannon.png"
	},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.09, 0, -0.09, 0.09, 0.5, 0.09 },
			{ -0.5, -0.25, -0.5, 0.5, 0.125, 0.5 },
			{ -0.4375, -0.1875, -0.4375, 0.4375, 0.1875, 0.5 },
			{ -0.5, -0.5, 0.3125, 0.5, 0.125, 0.5 },
			{ -0.5, -0.5, -0.5, -0.3125, 0.125, -0.3125 },
			{ 0.3125, -0.5, -0.5, 0.5, 0.125, -0.3125 },
		}
	},
	collision_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.85, 0.5 }
		}
	},
	selection_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.1875, 0.5 }
		}
	},
	wield_image = "lwcannon_item.png",
	inventory_image = "lwcannon_item.png",
	is_ground_content = false,
	groups = table.copy (cannon_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	paramtype2 = "facedir",
	param2 = 0,
	floodable = false,
	drop = "lwcomponents:cannon_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_construct = on_construct,
	on_destruct = on_destruct,
	on_place = on_place_locked,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	on_timer = on_timer,
})



minetest.register_entity ("lwcomponents:cannon_barrel", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		collisionbox = { -0.5, -0.35, -0.5, 0.5, 0.35, 0.5 },
		selectionbox = { -0.5, -0.35, -0.5, 0.5, 0.35, 0.5 },
		pointable = false,
		visual = "mesh",
		visual_size = { x = 1, y = 1, z = 1 },
		mesh = "lwcomponents_cannon_barrel.obj",
		textures = { "lwcomponents_cannon_barrel.png" },
		use_texture_alpha = false,
		is_visible = true,
		makes_footstep_sound = false,
		automatic_rotate = 0,
		backface_culling = true,
		damage_texture_modifier = "",
		glow = 0,
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
	{"top", "lwcomponents:cannon", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:cannon", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:cannon", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:cannon_locked", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:cannon_locked", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:cannon_locked", "main"}, -- insert items from hopper at side
})



--
