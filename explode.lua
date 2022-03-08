local utils = ...
local S = utils.S




local explode = { }



if minetest.global_exists ("fire") then


explode.fire_supported = true


function explode.set_fire (pos, burn_all)
	local node = utils.get_far_node (pos)

	if not node then
		return
	end

	if node.name ~= "air" then
		local def = minetest.registered_nodes[node.name]

		if not def or not def.buildable_to then
			return
		end
	end

	local dirs =
	{
		{ x = 0, y = -1, z = 0 },
		{ x = -1, y = 0, z = 0 },
		{ x = 0, y = 0, z = -1 },
		{ x = 1, y = 0, z = 0 },
		{ x = 0, y = 0, z = 1 }
	}

	for i = 1, #dirs do
		node = utils.get_far_node (vector.add (pos, dirs[i]))

		if node and node.name ~= "air" and node.name ~= "fire:basic_flame" then
			local def = minetest.registered_nodes[node.name]

			if def and def.liquidtype == "none" then
				if (def.groups and def.groups.flammable) or burn_all then
					minetest.set_node (pos, { name = "fire:basic_flame" })

					return
				end
			end
		end
	end
end


else


explode.fire_supported = false


function explode.set_fire (pos, burn_all)
end


end



local function dig_node (pos, toolname)
	local node = utils.get_far_node (pos)
	local dig = false
	local drops = nil

	if toolname == true then
		dig = true
		toolname = nil
	end

	if node and node.name ~= "air" then
		local def = utils.find_item_def (node.name)

		if not dig then
			if def and def.can_dig then
				local result, can_dig = pcall (def.can_dig, pos)

				dig = ((not result) or (result and (can_dig == nil or can_dig == true)))
			else
				dig = true
			end
		end

		if dig then
			local items = minetest.get_node_drops (node, toolname)

			if items then
				drops = { }

				for i = 1, #items do
					drops[i] = ItemStack (items[i])
				end

				if def and def.preserve_metadata then
					def.preserve_metadata (pos, node, minetest.get_meta (pos), drops)
				end
			end

			minetest.remove_node (pos)
		end
	end

	return drops
end



local function add_drops (drops, drop)
	if drops and drop then
		for i = 1, #drop do
			local item = ItemStack (drop[i])

			if item and not item:is_empty () then
				local existing = drops[item:get_name ()]

				if existing and utils.is_same_item (item, existing) then
					existing:set_count (existing:get_count () + item:get_count ())
				else
					drops[item:get_name ()] = item
				end
			end
		end
	end
end



local function explode_node (pos, dig_chance, intensity, drops, filter)
	if not utils.is_protected (pos, nil) then
		dig_chance = math.min (math.max (dig_chance, 0), 100)

		if math.random (100) <= dig_chance then
			local node = utils.get_far_node (pos)
			local blasted = false

			if node and node.name ~= "air" then
				local def = minetest.registered_nodes[node.name]

				if def then
					if def.diggable == false then
						return false
					end

					for k, v in pairs (filter) do
						if def[k] == nil then
							if filter[k.."_undefined"] == false then
								return false
							end
						elseif def[k] ~= v then
							return false
						end
					end

					if def.on_blast then
						def.on_blast (pos, intensity)
						blasted = true
					end
				end

				if not blasted then
					local drop = dig_node (pos, true)

					add_drops (drops, drop)
				end

				minetest.check_for_falling ({ x = pos.x, y = pos.y + 1, z = pos.z })

				return true
			end
		end
	end

	return false
end



local function burn_node (pos, fire_chance, burn_all)
	if not utils.is_protected (pos, nil) then
		fire_chance = math.min (math.max (fire_chance, 0), 100)

		if math.random (100) <= fire_chance then
			explode.set_fire (pos, burn_all)
		end
	end
end



local function entity_is_drop (obj)
	return obj.get_luaentity and obj:get_luaentity () and
			 obj:get_luaentity ().name and
			 obj:get_luaentity ().name == "__builtin:item"
end



local function explode_entities (pos, radius, damage, drops)
	local objs = minetest.get_objects_inside_radius (pos, radius)

	for _, obj in ipairs (objs) do
		-- could be detached player from controller
		if obj.get_pos and obj:get_pos () then
			local obj_pos = obj:get_pos ()
			local dir = vector.direction (pos, obj_pos)
			local dist = vector.length (vector.subtract (obj_pos, pos))
			local vel = vector.multiply (dir, ((radius + 1) - dist) / (radius + 1) * damage * 5)

			if entity_is_drop (obj) then
				obj:add_velocity (vel)

			elseif not obj:get_armor_groups ().immortal then

				local ent_damage = ((radius - dist) / radius * damage / 2) + (damage / 2)
				local reason = { type = "set_hp", from = "lwcomponents" }

				if obj:is_player() then
					local parent = obj:get_attach ()

					if parent then
						obj:set_detach ()
					end

					obj:add_velocity (vel)
					obj:set_hp (obj:get_hp () - ent_damage, reason)

				else
					local luaobj = obj:get_luaentity ()

					-- object might have disappeared somehow
					if luaobj then
						if luaobj.name == "digistuff:controller_entity" then
							for _, child in ipairs (obj:get_children ()) do
								if child:is_player () then
									local def = utils.find_item_def ("digistuff:controller_programmed")

									if def and def.on_rightclick then
										def.on_rightclick (obj:get_pos (), ItemStack (), child)

										child:add_velocity (vel)
										child:set_hp (child:get_hp () - ent_damage, reason)
									end
								end
							end
						else
							local do_damage = true
							local do_knockback = true
							local entity_drops = {}
							local objdef = minetest.registered_entities[luaobj.name]

							if objdef and objdef.on_blast then
								do_damage, do_knockback, entity_drops = objdef.on_blast (luaobj, ent_damage)
							end

							if do_knockback then
								obj:add_velocity (vel)
							end

							if do_damage then
								obj:set_hp (obj:get_hp() - ent_damage, reason)
							end

							add_drops (drops, entity_drops)
						end
					end
				end
			end
		end
	end
end



local function spray_drops (pos, drops, damage)
	local max_vel = damage * 2.5

	for k, stack in pairs (drops) do
		local vel =
		{
			x = math.random (max_vel) - (max_vel / 2),
			y = math.random (max_vel) - (max_vel / 2),
			z = math.random (max_vel) - (max_vel / 2)
		}

		local drop = minetest.add_item (pos, stack)

		if drop then
			drop:set_velocity (vel)
		end
	end
end



local function add_effects (pos, radius, drops)
	minetest.add_particle ({
		pos = pos,
		velocity = vector.new (),
		acceleration = vector.new (),
		expirationtime = 0.4,
		size = 30, -- radius * 10,
		collisiondetection = false,
		vertical = false,
		texture = "lwcomponents_boom.png",
		glow = 14,
	})

	minetest.add_particlespawner ({
		amount = 64,
		time = 0.5,
		minpos = vector.subtract (pos, radius / 2),
		maxpos = vector.add (pos, radius / 2),
		minvel = {x = -10, y = -10, z = -10},
		maxvel = {x = 10, y = 10, z = 10},
		minacc = vector.new (),
		maxacc = vector.new (),
		minexptime = 1,
		maxexptime = 2.5,
		minsize = 9,  -- radius * 3,
		maxsize = 15, -- radius * 5,
		texture = "lwcomponents_smoke.png",
	})

	-- we just dropped some items. Look at the items entities and pick
	-- one of them to use as texture
	local texture = "lwcomponents_blast.png" --fallback texture
	local node
	local most = 0

	if drops then
		for name, stack in pairs (drops) do
			local count = stack:get_count()
			if count > most then
				most = count
				local def = minetest.registered_nodes[name]
				if def then
					node = { name = name }
				end
				if def and def.tiles and def.tiles[1] then
					if type (def.tiles[1]) == "table" then
						texture = def.tiles[1].name or "lwcomponents_blast.png"
					elseif type (def.tiles[1]) == "string" then
						texture = def.tiles[1]
					end
				end
			end
		end
	end

	minetest.add_particlespawner ({
		amount = 64,
		time = 0.1,
		minpos = vector.subtract (pos, radius / 2),
		maxpos = vector.add (pos, radius / 2),
		minvel = {x = -3, y = 0, z = -3},
		maxvel = {x = 3, y = 5,  z = 3},
		minacc = {x = 0, y = -10, z = 0},
		maxacc = {x = 0, y = -10, z = 0},
		minexptime = 0.8,
		maxexptime = 2.0,
		minsize = 1, -- radius * 0.33,
		maxsize = 3, -- radius,
		texture = texture,
		-- ^ only as fallback for clients without support for `node` parameter
		node = node,
		collisiondetection = true,
	})
end



function utils.boom (pos,									-- center of explosion
							node_radius, node_chance,		-- radius and chance in 100
							fire_radius, fire_chance,		-- radius and chance in 100
							entity_radius, entity_damage,	-- radius and max damage applied
							disable_drops,						-- true to disable drops
							node_filter,						-- node filter table as { buildable_to = true, buildable_to_undefined = false, ... }
							burn_all,							-- true to set fire to anything, otherwise only flammable
							sound)								-- sound on blast, if nil plays default

	pos = vector.round (pos)
	node_radius = math.floor (node_radius or 1)
	fire_radius = math.floor (fire_radius or node_radius)
	entity_radius = math.floor (entity_radius or node_radius * 2)
	node_chance = node_chance or 80
	fire_chance = fire_chance or 30
	entity_damage = math.floor (entity_damage or entity_radius)
	disable_drops = disable_drops == true
	node_filter = node_filter or { }
	burn_all = burn_all == true
	sound = sound or "lwcannon"

	local drops = { }
	local effects_radius = (node_radius > 0 and node_radius) or entity_radius
	local center_free = false

	if not utils.is_protected (pos, nil) then
		local center_node = utils.get_far_node (pos)

		if not center_node or center_node.name == "air" then
			center_free = true
		end
	end

	if node_radius > 0 and node_chance > 0 then
		local extents = node_radius * 2

		for y = -extents, extents, 1 do
			for z = -extents, extents, 1 do
				for x = -extents, extents, 1 do
					local node_pos = { x = x + pos.x, y = y + pos.y, z = z + pos.z }
					local length = vector.length ({ x = x, y = y, z = z })

					if node_chance > 0 and length <= node_radius then
						if explode_node (node_pos, node_chance, 1.0, drops, node_filter) then
							if vector.equals (pos, node_pos) then
								center_free = true
							end
						end
					end
				end
			end
		end
	end

	if fire_radius > 0 and fire_chance > 0 then
		local extents = fire_radius * 2

		for y = -extents, extents, 1 do
			for z = -extents, extents, 1 do
				for x = -extents, extents, 1 do
					local node_pos = { x = x + pos.x, y = y + pos.y, z = z + pos.z }
					local length = vector.length ({ x = x, y = y, z = z })

					if fire_chance > 0 and length <= fire_radius then
						burn_node (node_pos, fire_chance, burn_all)
					end
				end
			end
		end
	end

	minetest.sound_play (sound,
								{
									pos = pos,
									gain = 2.5,
									max_hear_distance = math.min (effects_radius * 20, 128)
								},
								true)

	if center_free then
		minetest.set_node (pos, { name = "lwcomponents:boom" })
	end

	explode_entities (pos, entity_radius, entity_damage, drops)

	if not disable_drops then
		spray_drops (pos, drops, entity_damage)
	end

	add_effects (pos, effects_radius, drops)


	minetest.log ("action", "A Shell explosion occurred at " .. minetest.pos_to_string (pos) ..
									" with radius " .. entity_radius)
end



minetest.register_node ("lwcomponents:boom", {
	description = S("Boom"),
	drawtype = "airlike",
	tiles = { "lwcomponents_boom.png" },
	inventory_image = "lwcomponents_boom.png",
	wield_image = "lwcomponents_boom.png",
	light_source = default.LIGHT_MAX,
	use_texture_alpha = "blend",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	climbable = false,
	buildable_to = true,
	floodable = true,
	is_ground_content = false,
	drop = "",
	paramtype = "light",
	param1 = 255,
	post_effect_color = { a = 128, r = 255, g = 0, b = 0 },
	groups = { dig_immediate = 3, not_in_creative_inventory = 1 },
	on_construct = function (pos)
		minetest.get_node_timer (pos):start (0.5)
	end,
	on_timer = function (pos, elapsed)
		minetest.remove_node (pos)

		return false
	end,
	-- unaffected by explosions
	on_blast = function() end,
})



--
