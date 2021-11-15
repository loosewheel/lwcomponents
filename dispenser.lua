local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local function dispense_dir (node)
	if node.param2 == 0 then
		return { x = 0, y = 0, z = -1 }
	elseif node.param2 == 1 then
		return { x = -1, y = 0, z = 0 }
	elseif node.param2 == 2 then
		return { x = 0, y = 0, z = 1 }
	elseif node.param2 == 3 then
		return { x = 1, y = 0, z = 0 }
	else
		return { x = 0, y = 0, z = 0 }
	end
end



local function dispense_pos (pos, node)
	if node.param2 == 0 then
		return { x = pos.x, y = pos.y, z = pos.z - 1 }
	elseif node.param2 == 1 then
		return { x = pos.x - 1, y = pos.y, z = pos.z }
	elseif node.param2 == 2 then
		return { x = pos.x, y = pos.y, z = pos.z + 1 }
	elseif node.param2 == 3 then
		return { x = pos.x + 1, y = pos.y, z = pos.z }
	else
		return { x = pos.x, y = pos.y, z = pos.z }
	end
end



local function dispense_velocity (node)
	local force = 25 --math.random (30 , 35)
	local tilt = (math.random (1 , 2001) - 1001) / 1000
	local sway = (math.random (1 , 4001) - 2001) / 1000

	if node.param2 == 0 then
		return { x = sway, y = tilt, z = -force }
	elseif node.param2 == 1 then
		return { x = -force, y = tilt, z = sway }
	elseif node.param2 == 2 then
		return { x = sway, y = tilt, z = force }
	elseif node.param2 == 3 then
		return { x = force, y = tilt, z = sway }
	else
		return { x = 0, y = 0, z = 0 }
	end
end



local function send_dispense_message (pos, slot, name)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "dispense",
															name = name,
															slot = slot })
			end
		end
	end
end



local function try_spawn (pos, node, item, owner)
	if utils.mobs_supported and utils.settings.spawn_mobs then
		local mob = item:get_name ()
		local item_def = minetest.registered_craftitems[mob]
		local spawn_pos = dispense_pos (pos, node)

		if item_def and item_def.groups and item_def.groups.spawn_egg then
			if mob:sub (mob:len () - 3) == "_set" then
				mob = mob:sub (1, mob:len () - 4)

				if minetest.registered_entities[mob] then
					local data = item:get_metadata ()
					local smob = minetest.add_entity (spawn_pos, mob, data)
					local ent = smob and smob:get_luaentity ()

					if ent then
						-- set owner if not a monster
						if owner:len () > 0 and ent.type ~= "monster" then
							ent.owner = owner
							ent.tamed = true
						end
					end

					return smob
				end

			else
				if minetest.registered_entities[mob] then
					local smob = minetest.add_entity (spawn_pos, mob)
					local ent = smob and smob:get_luaentity ()

					if ent then
						-- set owner if not a monster
						if owner:len () > 0 and ent.type ~= "monster" then
							ent.owner = owner
							ent.tamed = true
						end
					end

					return smob
				end

			end

		elseif mob == "mobs:egg" then
			if math.random (1, 10) == 1 then
				local smob = minetest.add_entity (spawn_pos, "mobs_animal:chicken")
				local ent = smob and smob:get_luaentity ()

				if ent then
					-- set owner if not a monster
					if owner:len () > 0 and ent.type ~= "monster" then
						ent.owner = owner
						ent.tamed = true
					end
				end

				return smob
			end
		end
	end

	return nil
end



-- slot:
--    nil - next item, no dispense if empty
--    number - 1 item from slot, no dispense if empty
--    string - name of item to dispense, no dispense if none
local function dispense_item (pos, node, slot)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			if not slot then
				local slots = inv:get_size ("main")

				for i = 1, slots do
					local stack = inv:get_stack ("main", i)

					if not stack:is_empty () and stack:get_count () > 0 then
						slot = i
						break
					end
				end

			elseif type (slot) == "string" then
				local name = slot
				slot = nil

				local slots = inv:get_size ("main")

				for i = 1, slots do
					local stack = inv:get_stack ("main", i)

					if not stack:is_empty () and stack:get_count () > 0 then
						if name == stack:get_name () then
							slot = i
							break
						end
					end
				end

			else
				slot = tonumber (slot)

			end

			if slot then
				local stack = inv:get_stack ("main", slot)

				if not stack:is_empty () and stack:get_count () > 0 then
					local name = stack:get_name ()
					local item = ItemStack (stack)

					if item then
						item:set_count (1)
						local spawn_pos = dispense_pos (pos, node)
						local owner = meta:get_string ("owner")

						local obj, cancel = utils.spawn_registered (name,
																				  spawn_pos,
																				  item,
																				  owner,
																				  pos,
																				  dispense_dir (node))

						if obj == nil and cancel then
							return false
						end

						if not obj then
							obj = try_spawn (pos, node, item, owner)
						end

						if not obj then
							obj = minetest.add_item (spawn_pos, item)
						end

						if obj then
							obj:set_velocity (dispense_velocity (node))

							stack:set_count (stack:get_count () - 1)
							inv:set_stack ("main", slot, stack)

							send_dispense_message (pos, slot, name)

							return true, slot, name
						end
					end
				end
			end
		end
	end

	return false
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"formspec_version[3]\n"..
	"size[11.75,13.75;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"list[context;main;3.5,2.5;4,4;]\n"..
	"list[current_player;main;1.0,8.0;8,4;]\n"..
	"listring[]"

	meta:set_string ("inventory", "{ main = { } }")
	meta:set_string ("formspec", spec)

	local inv = meta:get_inventory ()

	inv:set_size ("main", 16)
	inv:set_width ("main", 4)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Dispenser (owned by "..placer:get_player_name ()..")")
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

							if m[1] == "dispense" then
								if m[2] and tonumber (m[2]) then
									m[2] = tonumber (m[2])
								end

								dispense_item (pos, node, m[2])
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
					dispense_item (pos, node)
				end
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:dispenser", {
	description = S("Dispenser"),
	tiles = { "lwdispenser.png", "lwdispenser.png", "lwdispenser.png",
				 "lwdispenser.png", "lwdispenser.png", "lwdispenser_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node,
	can_dig = can_dig,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:dispenser_locked", {
	description = S("Dispenser (locked)"),
	tiles = { "lwdispenser.png", "lwdispenser.png", "lwdispenser.png",
				 "lwdispenser.png", "lwdispenser.png", "lwdispenser_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node_locked,
	can_dig = can_dig,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



utils.hopper_add_container({
	{"top", "lwcomponents:dispenser", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:dispenser", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:dispenser", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:dispenser_locked", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:dispenser_locked", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:dispenser_locked", "main"}, -- insert items from hopper at side
})



end -- utils.digilines_supported or utils.mesecon_supported



--
