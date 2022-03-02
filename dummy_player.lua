

local function get_dummy_player (as_player, name, pos, look_dir, controls, velocity,
											hp, armor_groups, properties, nametag, breath)
	local obj_as_player = as_player ~= false
	local obj_name = name or ""
	local obj_pos = vector.new (pos or { x = 0, y = 0, z = 0 })
	local obj_look_dir = vector.new (look_dir or { x = 0, y = 0, z = 0 })
	local obj_controls = table.copy (controls or { })
	local obj_velocity = vector.new (velocity or { x = 0, y = 0, z = 0 })
	local obj_hp = hp or 20
	local obj_armor_groups = table.copy (armor_groups or { })
	local obj_properties = table.copy (properties or { })
	local obj_nametag = table.copy (nametag or { })
	local obj_breath = breath or 20

	local object = { }

	-- common
	object.get_pos = function (self)
		return vector.new (obj_pos)
	end


	object.set_pos = function (self, pos)
		obj_pos = vector.new (pos)
	end


	object.get_velocity = function (self)
		return vector.new (obj_velocity)
	end


	object.add_velocity = function (self, vel)
		obj_velocity = vector.add (obj_velocity, vel)
	end


	object.move_to = function (self, pos, continuous)
		obj_pos = vector.new (pos)
	end


	object.punch = function (self, puncher, time_from_last_punch, tool_capabilities, direction)
	end


	object.right_click = function (self, clicker)
	end


	object.get_hp = function (self)
		return obj_hp
	end


	object.set_hp = function (self, hp, reason)
		obj_hp = hp
	end


	object.get_inventory = function (self)
		return nil
	end


	object.get_wield_list = function (self)
		return nil
	end


	object.get_wield_index = function (self)
		return nil
	end


	object.get_wielded_item = function (self)
		return nil
	end


	object.set_wielded_item = function (self, item)
	end


	object.set_armor_groups = function (self, groups)
		obj_armor_groups = groups
	end


	object.get_armor_groups = function (self)
		return table.copy (obj_armor_groups)
	end


	object.set_animation = function (self, frame_range, frame_speed, frame_blend, frame_loop)
	end


	object.get_animation = function (self)
		return { x = 1, y = 1 }, 15.0, 0.0, true
	end


	object.set_animation_frame_speed = function (self, frame_speed)
	end


	object.set_attach = function (self, parent, bone, position, rotation, forced_visible)
	end


	object.get_attach = function (self)
		return nil
	end


	object.get_children = function (self)
		return { }
	end


	object.set_detach = function (self)
	end


	object.set_bone_position = function (self, bone, position, rotation)
	end


	object.get_bone_position = function (self)
		return nil
	end


	object.set_properties = function (self, properties)
		obj_properties = table.copy (properties or { })
	end


	object.get_properties = function (self)
		return table.copy (obj_properties)
	end


	object.is_player = function (self)
		return obj_as_player
	end


	object.get_nametag_attributes = function (self)
		return obj_nametag
	end


	object.set_nametag_attributes = function (self, attributes)
		obj_nametag = table.copy (attributes)
	end



	-- player
	object.get_player_name = function (self)
		return obj_name
	end


	object.get_player_velocity = function (self)
		return table.copy (obj_velocity)
	end


	object.add_player_velocity = function (self, vel)
		obj_velocity =  vector.add (obj_velocity, vel)
	end


	object.get_look_dir = function (self)
		return table.copy (obj_look_dir)
	end


	object.get_look_vertical = function (self)
		return vector.dir_to_rotation (obj_look_dir, { x = 0, y = 1, z = 0 }).x
	end


	object.get_look_horizontal = function (self)
		return vector.dir_to_rotation (obj_look_dir, { x = 0, y = 1, z = 0 }).y
	end


	object.set_look_vertical = function (self, radians)
		obj_look_dir = vector.new ({ x = radians, y = obj_look_dir.y, z = obj_look_dir.z })
	end


	object.set_look_horizontal = function (self, radians)
		obj_look_dir = vector.new ({ x = obj_look_dir.x, y = radians, z = obj_look_dir.z })
	end


	object.get_look_pitch = function (self)
		return vector.dir_to_rotation (obj_look_dir, { x = 0, y = 1, z = 0 }).x
	end


	object.get_look_yaw = function (self)
		return vector.dir_to_rotation (obj_look_dir, { x = 0, y = 1, z = 0 }).y
	end


	object.set_look_pitch = function (self, radians)
		obj_look_dir = vector.new ({ x = radians, y = obj_look_dir.y, z = obj_look_dir.z })
	end


	object.set_look_yaw = function (self, radians)
		obj_look_dir = vector.new ({ x = obj_look_dir.x, y = radians, z = obj_look_dir.z })
	end


	object.get_breath = function (self)
		return obj_breath
	end


	object.set_breath = function (self, value)
		obj_breath = value
	end


	object.get_fov = function (self)
		return 0, false, 0
	end


	object.set_fov = function (self, fov, is_multiplier, transition_time)
		obj_breath = value
	end


	object.get_attribute = function (self, attribute)
		return nil
	end


	object.set_attribute = function (self, attribute, value)
	end


	object.get_meta = function (self)
		return nil
	end


	object.set_inventory_formspec = function (self, formspec)
	end


	object.get_inventory_formspec = function (self)
		return ""
	end


	object.set_formspec_prepend = function (self, formspec)
	end


	object.get_formspec_prepend = function (self)
		return ""
	end


	object.get_player_control = function (self)
		return table.copy (obj_controls)
	end


	object.set_physics_override = function (self, override_table)
	end


	object.get_physics_override = function (self)
		return { }
	end


	object.hud_add = function (self, definition)
		return nil
	end


	object.hud_remove = function (self, id)
	end


	object.hud_change = function (self, id, stat, value)
	end


	object.hud_get = function (self, id)
		return nil
	end


	object.hud_set_flags = function (self, flags)
	end


	object.hud_get_flags = function (self)
		return { }
	end


	object.hud_set_hotbar_itemcount = function (self, count)
	end


	object.hud_get_hotbar_itemcount = function (self)
		return 0
	end


	object.hud_set_hotbar_image = function (self, texturename)
	end


	object.hud_get_hotbar_image = function (self)
		return ""
	end


	object.hud_set_hotbar_selected_image = function (self, texturename)
	end


	object.hud_get_hotbar_selected_image = function (self)
		return ""
	end


	object.set_minimap_modes = function (self, modes, selected_mode)
	end


	object.set_sky = function (self, sky_parameters)
	end


	object.get_sky = function (self)
		return nil
	end


	object.get_sky_color = function (self)
		return nil
	end


	object.set_sun = function (self, sun_parameters)
	end


	object.get_sun = function (self)
		return { }
	end


	object.set_moon = function (self, moon_parameters)
	end


	object.get_moon = function (self)
		return { }
	end


	object.set_stars = function (self, star_parameters)
	end


	object.get_stars = function (self)
		return { }
	end


	object.set_clouds = function (self, cloud_parameters)
	end


	object.get_clouds = function (self)
		return { }
	end


	object.override_day_night_ratio = function (self, ratio)
	end


	object.get_day_night_ratio = function (self)
		return nil
	end


	object.set_local_animation = function (self, idle, walk, dig, walk_while_dig, frame_speed)
	end


	object.get_local_animation = function (self)
		return { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, 30
	end


	object.set_eye_offset = function (self, firstperson, thirdperson)
	end


	object.get_eye_offset = function (self)
		return { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }
	end


	object.send_mapblock = function (self, blockpos)
		return false
	end


	return object
end



return get_dummy_player


--
