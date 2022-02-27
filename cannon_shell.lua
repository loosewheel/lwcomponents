local utils = ...
local S = utils.S



--[[
on_step info

info.touching_ground = bool
info.standing_on_object = bool
info.collides = bool


info.collisions[n].type = "node"
info.collisions[n].node_pos = vector
info.collisions[n].old_velocity = vector
info.collisions[n].now_velocity = vector
info.collisions[n].axis = "x" | "y" | "z" - axis hit

or

info.collisions[n].type = "object"
info.collisions[n].object = userdata
info.collisions[n].old_velocity = vector
info.collisions[n].now_velocity = vector
info.collisions[n].axis = "x" | "y" | "z" - axis hit
]]



local function get_adjacent_node (collision_info, spawn_pos)
	if vector.equals (collision_info.node_pos, spawn_pos) then
		return collision_info.node_pos
	end

	local adj = { x = 0, y = 0, z = 0 }

	if collision_info.axis == "x" then
		adj.x = (collision_info.old_velocity.x > 0 and -1) or 1
	elseif collision_info.axis == "y" then
		adj.y = (collision_info.old_velocity.y > 0 and -1) or 1
	elseif collision_info.axis == "z" then
		adj.z = (collision_info.old_velocity.z > 0 and -1) or 1
	end

	local pos = vector.new (collision_info.node_pos)
	local node = utils.get_far_node (pos)
	local def = minetest.registered_nodes[node and node.name or nil]

	while (node and node.name ~= "air") and (def and not def.buildable_to) do
		local next_pos = vector.add (pos, adj)

		if vector.equals (next_pos, spawn_pos) then
			return pos
		end

		pos = next_pos
		node = utils.get_far_node (pos)
		def = minetest.registered_nodes[node and node.name or nil]
	end

	return pos
end



local function register_shell (name, description, texture, inventory_image,
										 stack_max, shell_speed, explode_func)

	minetest.register_entity (name.."_entity", {
		initial_properties = {
			physical = true,
			collide_with_objects = true,
			collisionbox = { -0.25, -0.125, -0.25, 0.25, 0.125, 0.25 },
			pointable = false,
			visual_size = { x = 0.7, y = 0.7, z = 0.7 },
			visual = "mesh",
			mesh = "lwcomponents_shell.obj",
			textures = { texture },
			use_texture_alpha = false,
			is_visible = true,
			makes_footstep_sound = false,
			automatic_face_movement_dir = false,
			automatic_face_movement_max_rotation_per_sec = false,
			automatic_rotate = 0,
			backface_culling = true,
			damage_texture_modifier = "",
			glow = 0,
			static_save = false,
			shaded = true,
			show_on_minimap = false,
		},

		on_activate = function (self, staticdata, dtime_s)
			if not self.spawn_pos then
				self.spawn_pos = vector.new (self.object:get_pos ())
			end

			if not self.time_lived then
				self.time_lived = 0
			end

			if not self.shell_speed then
				self.shell_speed = shell_speed
			end

			self.staticdata = staticdata
		end,

		get_staticdata = function (self)
			return self.staticdata
		end,

		on_step = function (self, dtime, info)
			local explode_pos = nil

			self.object:set_rotation (vector.dir_to_rotation (self.object:get_velocity ()))

			if self.time_lived then
				self.time_lived = self.time_lived + dtime

				if self.time_lived > self.shell_speed then
					self.object:remove ()

					return
				end
			end

			if info.collides then
				--For each collision that was found in reverse order
				for i = #info.collisions, 1, -1 do
					local c = info.collisions[i]

					if c.type == "node" then
						local node = utils.get_far_node (c.node_pos)

						if node and node.name ~= "air" then
							local def = minetest.registered_nodes[node.name]

							if def and def.walkable then
								-- adjacent for explosion
								explode_pos = get_adjacent_node (c, self.spawn_pos)

--minetest.log ("action", "Shell on node "..node.name.." at "..minetest.pos_to_string (explode_pos)..
							--" node at "..minetest.pos_to_string (c.node_pos))

								break
							end
						end

						if not explode_pos then
							self.object:set_velocity (c.old_velocity)
						end

					elseif c.type == "object" then
						local c_name = (c.object.get_luaentity and
											 c.object:get_luaentity () and
											 c.object:get_luaentity ().name) or ""
						local s_name = (self.name) or ""

						-- explode at this pos
						if c.object:get_armor_groups ().immortal or s_name == c_name then
							self.object:set_velocity (c.old_velocity)
						else
							explode_pos = vector.new (c.object:get_pos ())

--minetest.log ("action", "Shell on entity "..c.object:get_luaentity ().name.." at "..minetest.pos_to_string (explode_pos))

							break
						end
					end
				end
			end

			if explode_pos then
				self.object:remove ()

				explode_func (explode_pos)
			end
		end,

		on_punch = function (self, puncher, time_from_last_punch, tool_capabilities, dir)
			return true
		end,
	})

	minetest.register_craftitem (name, {
		description = description,
		short_description = description,
		groups = { },
		inventory_image = inventory_image,
		wield_image = inventory_image,
		stack_max = stack_max,
	})


	lwcomponents.register_spawner (name,
	function (spawn_pos, itemstack, owner, spawner_pos, spawner_dir, force)
		if not itemstack:is_empty() then
			local def = minetest.registered_entities[name.."_entity"]

			if def then
				local obj = minetest.add_entity (spawn_pos, name.."_entity")

				if obj then
					obj:set_acceleration ({ x = 0, y = -9.81, z = 0 })
					obj:set_rotation (vector.dir_to_rotation (vector.multiply (spawner_dir, shell_speed)))
					obj:set_velocity (vector.multiply (spawner_dir, shell_speed))

					local luaent = obj:get_luaentity ()

					if luaent then
						luaent.spawn_pos = { x = spawn_pos.x, y = spawn_pos.y, z = spawn_pos.z }
						luaent.time_lived = 0
						luaent.shell_speed = shell_speed
					end

					return obj, false
				end
			end
		end

		return nil, false
	end)
end


register_shell ("lwcomponents:cannon_shell",
	S("Shell"),
	"lwcannon_shell.png",
	"lwcannon_shell_item.png",
	99,
	25,
	function (pos)
		utils.boom (pos,
						2, -- node_radius
						70, -- node_chance in 100
						2, -- fire_radius
						5, -- fire_chance in 100
						4, -- entity_radius
						20, -- entity_damage
						false, -- disable_drops
						nil, -- node_filter
						false, -- burn_all
						nil) -- sound
	end)


register_shell ("lwcomponents:cannon_soft_shell",
	S("Soft Shell"),
	"lwcannon_soft_shell.png",
	"lwcannon_soft_shell_item.png",
	99,
	25,
	function (pos)
		utils.boom (pos,
						 2, -- node_radius
						 50, -- node_chance in 100
						 2, -- fire_radius
						 5, -- fire_chance in 100
						 4, -- entity_radius
						 20, -- entity_damage
						 false, -- disable_drops
						 {
							 buildable_to = true,
							 buildable_to_undefined = false,
						 }, -- node_filter
						 false, -- burn_all
						 nil) -- sound
	end)


if minetest.global_exists ("fire") then
register_shell ("lwcomponents:cannon_fire_shell",
	S("Fire Shell"),
	"lwcannon_fire_shell.png",
	"lwcannon_fire_shell_item.png",
	99,
	25,
	function (pos)
		utils.boom (pos,
						2, -- node_radius
						0, -- node_chance in 100
						2, -- fire_radius
						70, -- fire_chance in 100
						4, -- entity_radius
						20, -- entity_damage
						false, -- disable_drops
						nil, -- node_filter
						true, -- burn_all
						nil) -- sound
	end)
end



--
