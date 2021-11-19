local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local deploy_interval = 1.0



local function send_deploy_message (pos, slot, name, range)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "deploy",
															name = name,
															slot = slot,
															range = range })
			end
		end
	end
end



local function deployer_front (pos, param2)
	if param2 == 0 then
		return { x = pos.x, y = pos.y, z = pos.z - 1 }
	elseif param2 == 1 then
		return { x = pos.x - 1, y = pos.y, z = pos.z }
	elseif param2 == 2 then
		return { x = pos.x, y = pos.y, z = pos.z + 1 }
	elseif param2 == 3 then
		return { x = pos.x + 1, y = pos.y, z = pos.z }
	else
		return { x = pos.x, y = pos.y, z = pos.z }
	end
end



local function get_deploy_pos (pos, param2, range)
	local deploypos = { x = pos.x, y = pos.y, z = pos.z }

	for i = 1, range do
		deploypos = deployer_front (deploypos, param2)

		if i < range then
			local node = minetest.get_node_or_nil (deploypos)

			if not node or node.name ~= "air" then
				local nodedef = utils.find_item_def (node.name)

				if not nodedef or not nodedef.buildable_to then
					return nil
				end
			end
		end
	end

	return deploypos
end



local function place_node (itemname, pos)
	local node = minetest.get_node_or_nil ({ x = pos.x, y = pos.y - 1, z = pos.z })

	if not node then
		return false
	end

	local nodedef = utils.find_item_def (node.name)

	if node.name == "air" or not nodedef or (nodedef and nodedef.buildable_to) then
		return false
	end

	node = minetest.get_node_or_nil (pos)

	if not node then
		return false
	end

	nodedef = utils.find_item_def (node.name)

	if node.name ~= "air" then
		if not nodedef or not nodedef.buildable_to or minetest.is_protected (pos, "") then
			return false
		end
	end

	local stack = ItemStack (itemname)
	local itemdef = utils.find_item_def (itemname)

	if stack and itemdef then
		local placed = false
		local pointed_thing =
		{
			type = "node",
			under = { x = pos.x, y = pos.y - 1, z = pos.z },
			above = pos,
		}

		if node.name ~= "air" and nodedef and nodedef.buildable_to then
			pointed_thing =
			{
				type = "node",
				under = pos,
				above = { x = pos.x, y = pos.y + 1, z = pos.z },
			}
		end

		if itemdef and itemdef.on_place then
			local result, msg = pcall (itemdef.on_place, stack, nil, pointed_thing)

			placed = result

			if not placed then
				if utils.settings.alert_handler_errors then
					minetest.log ("error", "on_place handler for "..itemname.." crashed - "..msg)
				end
			end
		end

		if not placed then
			if not minetest.registered_nodes[itemname] then
				return false
			end

			minetest.set_node (pos, { name = itemname, param1 = 0, param2 = 0 })

			if itemdef and itemdef.after_place_node then
				local result, msg = pcall (itemdef.after_place_node, pos, nil, stack, pointed_thing)

				if not result then
					if utils.settings.alert_handler_errors then
						minetest.log ("error", "after_place_node handler for "..nodename.." crashed - "..msg)
					end
				end
			end

			if itemdef and  itemdef.sounds and itemdef.sounds.place then
				pcall (minetest.sound_play, itemdef.sounds.place, { pos = pos })
			end
		end
	end

	return true
end



-- slot:
--    nil - next item, no drop if empty
--    number - 1 item from slot, no drop if empty
--    string - name of item to drop, no drop if none
-- range:
-- 	1 - 5 from front of deployer
local function deploy_item (pos, node, slot, range)
	local meta = minetest.get_meta (pos)

	range = math.min (math.max (tonumber (range) or 1, 1), 5)

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
					local deploypos = get_deploy_pos (pos, node.param2, range)

					if item and deploypos then
						if place_node (name, deploypos) then
							stack:set_count (stack:get_count () - 1)
							inv:set_stack ("main", slot, stack)

							send_deploy_message (pos, slot, name, range)

							return true, slot, name, range
						end
					end
				end
			end
		end
	end

	return false
end



local function deployer_off (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:deployer_on" then
			node.name = "lwcomponents:deployer"

			minetest.get_node_timer (pos):stop ()
			minetest.swap_node (pos, node)

		elseif node.name == "lwcomponents:deployer_locked_on" then
			node.name = "lwcomponents:deployer_locked"

			minetest.get_node_timer (pos):stop ()
			minetest.swap_node (pos, node)

		end
	end
end



local function deployer_on (pos, node, slot, range)
	local node = minetest.get_node (pos)

	range = tonumber (range) or 1

	if slot and tostring (slot) == "nil" then
		slot = nil
	end

	if node and range < 6 and range > 0 then
		if node.name == "lwcomponents:deployer" then
			node.name = "lwcomponents:deployer_on"

			minetest.swap_node (pos, node)
			deploy_item (pos, node, slot, range)
			minetest.get_node_timer (pos):start (deploy_interval)

		elseif node.name == "lwcomponents:deployer_locked" then
			node.name = "lwcomponents:deployer_locked_on"

			minetest.swap_node (pos, node)
			deploy_item (pos, node, slot, range)
			minetest.get_node_timer (pos):start (deploy_interval)

		end
	end
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
		meta:set_string ("infotext", "Deployer (owned by "..placer:get_player_name ()..")")
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



local function on_timer (pos, elapsed)
	deployer_off (pos)
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

							if m[1] == "deploy" then
								if tostring (m[2]) == nil then
									m[2] = "nil"
								elseif m[2] and tonumber (m[2]) then
									m[2] = tonumber (m[2])
								end

								deployer_on (pos, node, m[2], m[3])
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
					deployer_on (pos, node, "nil", 1)
				end
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:deployer", {
	description = S("Deployer"),
	tiles = { "lwdeployer.png", "lwdeployer.png", "lwdeployer.png",
				 "lwdeployer.png", "lwdeployer.png", "lwdeployer_face.png"},
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
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:deployer_locked", {
	description = S("Deployer (locked)"),
	tiles = { "lwdeployer.png", "lwdeployer.png", "lwdeployer.png",
				 "lwdeployer.png", "lwdeployer.png", "lwdeployer_face.png"},
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
	on_timer = on_timer,
	on_rightclick = on_rightclick
})




minetest.register_node("lwcomponents:deployer_on", {
	description = S("Deployer"),
	tiles = { "lwdeployer.png", "lwdeployer.png", "lwdeployer.png",
				 "lwdeployer.png", "lwdeployer.png", "lwdeployer_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:deployer",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:deployer_locked_on", {
	description = S("Deployer (locked)"),
	tiles = { "lwdeployer.png", "lwdeployer.png", "lwdeployer.png",
				 "lwdeployer.png", "lwdeployer.png", "lwdeployer_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:deployer_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



utils.hopper_add_container({
	{"top", "lwcomponents:deployer", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:deployer", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:deployer", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:deployer_locked", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:deployer_locked", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:deployer_locked", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:deployer_on", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:deployer_on", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:deployer_on", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:deployer_locked_on", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:deployer_locked_on", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:deployer_locked_on", "main"}, -- insert items from hopper at side
})


end -- utils.digilines_supported or utils.mesecon_supported



--
