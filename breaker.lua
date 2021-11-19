local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local break_interval = 1.0



local function get_breaker_side (pos, param2, side)
	local base = nil

	if side == "left" then
		base = { x = -1, y = pos.y, z = 0 }
	elseif side == "right" then
		base = { x = 1, y = pos.y, z = 0 }
	elseif side == "back" then
		base = { x = 0, y = pos.y, z = -1 }
	else -- "front"
		base = { x = 0, y = pos.y, z = 1 }
	end

	if param2 == 3 then -- +x
		return { x = base.z + pos.x, y = base.y, z = (base.x * -1) + pos.z }
	elseif param2 == 0 then -- -z
		return { x = (base.x * -1) + pos.x, y = base.y, z = (base.z * -1) + pos.z }
	elseif param2 == 1 then -- -x
		return { x = (base.z * -1) + pos.x, y = base.y, z = base.x + pos.z }
	else -- param2 == 2 +z
		return { x = base.x + pos.x, y = base.y, z = base.z + pos.z }
	end
end



local function get_break_pos (pos, param2, range)
	local breakpos = { x = pos.x, y = pos.y, z = pos.z }

	for i = 1, range do
		breakpos = get_breaker_side (breakpos, param2, "front")

		if i < range then
			local node = minetest.get_node_or_nil (breakpos)

			if not node or node.name ~= "air" then
				return nil
			end
		end
	end

	return breakpos
end



local function send_break_message (pos, action, name, range)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = action,
															name = name,
															range = range })
			end
		end
	end
end



local function get_tool (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			local stack = inv:get_stack ("tool", 1)

			if stack and not stack:is_empty () then
				return stack
			end
		end
	end

	return nil
end



local function add_wear (pos, wear)
	if wear > 0 then
		local meta = minetest.get_meta (pos)

		if meta then
			local inv = meta:get_inventory ()

			if inv then
				local stack = inv:get_stack ("tool", 1)

				if stack and not stack:is_empty () then
					local cur_wear = stack:get_wear ()

					if (cur_wear + wear) >= 65535 then
						inv:set_stack ("tool", 1, nil)
						send_break_message (pos, "tool", stack:get_name ())
					else
						stack:set_wear (cur_wear + wear)
						inv:set_stack ("tool", 1, stack)
					end
				end
			end
		end
	end
end



local function can_break_node (pos, breakpos)
	local node = minetest.get_node (pos)

	if node then
		local dig_node = minetest.get_node_or_nil (breakpos)

		if dig_node and dig_node.name ~= "air" then
			local node_def = minetest.registered_nodes[dig_node.name]

			if node_def then
				-- try tool first
				local tool = get_tool (pos)

				if tool then
					local dig_params = nil
					local tool_def = minetest.registered_items[tool:get_name ()]

					if tool_def then
						dig_params =
							minetest.get_dig_params (node_def.groups,
															 tool_def.tool_capabilities)

						if dig_params.diggable then
							return true, tool:get_name (), dig_params.wear
						end
					end
				end

				-- then try hand
				dig_params =
					minetest.get_dig_params (node_def.groups,
													 minetest.registered_items[""].tool_capabilities)

				if dig_params.diggable then
					return true, nil, 0
				end
			end
		end
	end

	return false
end



local function dig_node (pos, toolname)
	local node = minetest.get_node_or_nil (pos)
	local dig = false
	local drops = nil

	if toolname == true then
		dig = true
		toolname = nil
	end

	if node and node.name ~= "air" and node.name ~= "ignore" then
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

			if def and def.sounds and def.sounds.dug then
				pcall (minetest.sound_play, def.sounds.dug, { pos = pos })
			end

			minetest.remove_node (pos)
		end
	end

	return drops
end



local function break_node (pos, range)
	local node = minetest.get_node_or_nil (pos)

	if node then
		local breakpos = get_break_pos (pos, node.param2, range)

		if breakpos then
			local diggable, toolname, wear = can_break_node (pos, breakpos)

			if diggable then
				local breaknode = minetest.get_node_or_nil (breakpos)

				if breaknode and breaknode.name ~= "air" then
					local drops = dig_node (breakpos, toolname)

					if drops then
						local break_name = breaknode.name
						local eject_pos = get_breaker_side (pos, node.param2, "back")

						for i = 1, #drops do
							utils.item_drop (drops[i], nil, eject_pos)
						end

						add_wear (pos, wear)
						send_break_message (pos, "break", break_name, range)
					end
				end
			end
		end
	end
end



local function breaker_off (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:breaker_on" then
			node.name = "lwcomponents:breaker"

			minetest.get_node_timer (pos):stop ()
			minetest.swap_node (pos, node)

		elseif node.name == "lwcomponents:breaker_locked_on" then
			node.name = "lwcomponents:breaker_locked"

			minetest.get_node_timer (pos):stop ()
			minetest.swap_node (pos, node)

		end
	end
end



local function breaker_on (pos, range)
	local node = minetest.get_node (pos)

	range = tonumber (range) or 1

	if node and range < 6 and range > 0 then
		if node.name == "lwcomponents:breaker" then
			node.name = "lwcomponents:breaker_on"

			minetest.swap_node (pos, node)
			break_node (pos, range)
			minetest.get_node_timer (pos):start (break_interval)

		elseif node.name == "lwcomponents:breaker_locked" then
			node.name = "lwcomponents:breaker_locked_on"

			minetest.swap_node (pos, node)
			break_node (pos, range)
			minetest.get_node_timer (pos):start (break_interval)

		end
	end
end



local function eject_tool (pos, side)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if meta and node then
		local inv = meta:get_inventory ()

		if inv then
			local stack = inv:get_stack ("tool", 1)

			if stack and not stack:is_empty () then
				utils.item_drop (stack, nil, get_breaker_side (pos, node.param2, side))
				inv:set_stack ("tool", 1, nil)
			end
		end
	end
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"formspec_version[3]\n"..
	"size[11.75,10.75;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"list[context;tool;5.0,2.75;1,1;]\n"..
	"list[current_player;main;1.0,5.0;8,4;]\n"..
	"listring[]"

	meta:set_string ("inventory", "{ tool = { } }")
	meta:set_string ("formspec", spec)

	local inv = meta:get_inventory ()

	inv:set_size ("tool", 1)
	inv:set_width ("tool", 1)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Dropper (owned by "..placer:get_player_name ()..")")
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
			if not inv:is_empty ("tool") then
				return false
			end
		end
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



local function on_blast (pos, intensity)
	local meta = minetest.get_meta (pos)

	if meta then
		if intensity >= 1.0 then
			local inv = meta:get_inventory ()

			if inv then
				local slots = inv:get_size ("tool")

				for slot = 1, slots do
					local stack = inv:get_stack ("tool", slot)

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
				local slots = inv:get_size ("tool")

				for slot = 1, slots do
					local stack = inv:get_stack ("tool", slot)

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



local function on_timer (pos, elapsed)
	breaker_off (pos)
end



local function allow_metadata_inventory_put (pos, listname, index, stack, player)
	if listname == "tool" then
		if stack and not stack:is_empty () then
			local def = utils.find_item_def (stack:get_name ())

			if def and def.tool_capabilities then
				return 1
			end
		end
	end

	return 0
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

							if m[1] == "break" then
								breaker_on (pos, m[2])

							elseif m[1] == "eject" then
								eject_tool (pos, m[2])

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
					breaker_on (pos, 1)
				end,
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:breaker", {
	description = S("Breaker"),
	tiles = { "lwbreaker.png", "lwbreaker.png", "lwbreaker.png",
				 "lwbreaker.png", "lwbreaker_rear.png", "lwbreaker_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:breaker",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
	allow_metadata_inventory_put = allow_metadata_inventory_put
})



minetest.register_node("lwcomponents:breaker_locked", {
	description = S("Breaker (locked)"),
	tiles = { "lwbreaker.png", "lwbreaker.png", "lwbreaker.png",
				 "lwbreaker.png", "lwbreaker_rear.png", "lwbreaker_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:breaker_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
	allow_metadata_inventory_put = allow_metadata_inventory_put
})




minetest.register_node("lwcomponents:breaker_on", {
	description = S("Breaker"),
	tiles = { "lwbreaker.png", "lwbreaker.png", "lwbreaker.png",
				 "lwbreaker.png", "lwbreaker_rear.png", "lwbreaker_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:breaker",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
	allow_metadata_inventory_put = allow_metadata_inventory_put
})



minetest.register_node("lwcomponents:breaker_locked_on", {
	description = S("Breaker (locked)"),
	tiles = { "lwbreaker.png", "lwbreaker.png", "lwbreaker.png",
				 "lwbreaker.png", "lwbreaker_rear.png", "lwbreaker_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:breaker_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick,
	allow_metadata_inventory_put = allow_metadata_inventory_put
})



utils.hopper_add_container({
	{"bottom", "lwcomponents:breaker", "tool"}, -- insert items below from hopper above
	{"side", "lwcomponents:breaker", "tool"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"bottom", "lwcomponents:breaker_locked", "tool"}, -- insert items below from hopper above
	{"side", "lwcomponents:breaker_locked", "tool"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"bottom", "lwcomponents:breaker_on", "tool"}, -- insert items below from hopper above
	{"side", "lwcomponents:breaker_on", "tool"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"bottom", "lwcomponents:breaker_locked_on", "tool"}, -- insert items below from hopper above
	{"side", "lwcomponents:breaker_locked_on", "tool"}, -- insert items from hopper at side
})



end -- utils.digilines_supported or utils.mesecon_supported
