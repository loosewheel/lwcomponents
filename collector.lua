local utils = ...
local S = utils.S



if utils.digilines_supported then



local collect_interval = 0.5



local function send_collect_message (pos, name, count)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "collect",
															name = name,
															count = count })
			end
		end
	end
end



local function filter_item (pos, item)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv:is_empty ("filter") then
			return true
		end

		local slots = inv:get_size ("filter")
		for i = 1, slots do
			local stack = inv:get_stack ("filter", i)

			if stack and not stack:is_empty () and
				stack:get_name () == item then

				return true
			end
		end
	end

	return false
end



local function get_form_spec (is_off)
	return
	"formspec_version[3]\n"..
	"size[11.75,13.75;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"button[8.25,1.0;2.5,0.8;"..((is_off and "start;Start") or "stop;Stop").."]\n"..
	"list[context;filter;8.5,2.5;2,4;]\n"..
	"list[context;main;1.0,2.5;4,4;]\n"..
	"list[current_player;main;1.0,8.0;8,4;]\n"..
	"listring[]"
end



local function start_collector (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:collector" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:collector_on"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):start (collect_interval)

				meta:set_string ("formspec", get_form_spec (false))
			end

		elseif node.name == "lwcomponents:collector_locked" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:collector_locked_on"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):start (collect_interval)

				meta:set_string ("formspec", get_form_spec (false))
			end

		end
	end
end



local function stop_collector (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:collector_on" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:collector"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):stop ()

				meta:set_string ("formspec", get_form_spec (true))
			end

		elseif node.name == "lwcomponents:collector_locked_on" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:collector_locked"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):stop ()

				meta:set_string ("formspec", get_form_spec (true))
			end

		end
	end
end



local function on_destruct (pos)
	minetest.get_node_timer (pos):stop ()
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local is_off = itemstack and (itemstack:get_name () == "lwcomponents:collector" or
											itemstack:get_name () == "lwcomponents:collector_locked")

	meta:set_string ("inventory", "{ main = { }, filter = { } }")
	meta:set_string ("formspec", get_form_spec (is_off))

	local inv = meta:get_inventory ()

	inv:set_size ("main", 16)
	inv:set_width ("main", 4)
	inv:set_size ("filter", 8)
	inv:set_width ("filter", 2)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Collector (owned by "..placer:get_player_name ()..")")
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

	elseif fields.start then
		start_collector (pos)

	elseif fields.stop then
		stop_collector (pos)

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

			if not inv:is_empty ("filter") then
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

				slots = inv:get_size ("filter")

				for slot = 1, slots do
					local stack = inv:get_stack ("filter", slot)

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

				slots = inv:get_size ("filter")

				for slot = 1, slots do
					local stack = inv:get_stack ("filter", slot)

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
	end

	return itemstack
end



local function on_timer (pos, elapsed)
	local list = minetest.get_objects_inside_radius (pos, 2)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			for i = 1, #list do
				if list[i].get_luaentity and list[i]:get_luaentity () and
					list[i]:get_luaentity ().name and
					list[i]:get_luaentity ().name == "__builtin:item" then

					local stack = utils.item_pickup (list[i]:get_luaentity (), false)

					if stack and inv:room_for_item ("main", stack) and
						filter_item (pos, stack:get_name ()) then

						local name = stack:get_name ()
						local count = stack:get_count ()

						inv:add_item ("main", stack)
						utils.item_pickup (list[i]:get_luaentity ())

						send_collect_message (pos, name, count)
					end
				end
			end
		end
	end

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

						if this_channel ~= "" and this_channel == channel and
							type (msg) == "string" then

							local m = { }
							for w in string.gmatch(msg, "[^%s]+") do
								m[#m + 1] = w
							end

							if m[1] == "start" then
								start_collector (pos)

							elseif m[1] == "stop" then
								stop_collector (pos)

							end
						end
					end
				end,
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:collector", {
	description = S("Collector"),
	tiles = { "lwcollector.png", "lwcollector.png", "lwcollector.png",
				 "lwcollector.png", "lwcollector.png", "lwcollector.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:collector",
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node,
	can_dig = can_dig,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:collector_locked", {
	description = S("Collector (locked)"),
	tiles = { "lwcollector.png", "lwcollector.png", "lwcollector.png",
				 "lwcollector.png", "lwcollector.png", "lwcollector.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:collector_locked",
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node_locked,
	can_dig = can_dig,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:collector_on", {
	description = S("Collector"),
	tiles = { "lwcollector_on.png", "lwcollector_on.png", "lwcollector_on.png",
				 "lwcollector_on.png", "lwcollector_on.png", "lwcollector_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:collector",
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node,
	can_dig = can_dig,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:collector_locked_on", {
	description = S("Collector (locked)"),
	tiles = { "lwcollector_on.png", "lwcollector_on.png", "lwcollector_on.png",
				 "lwcollector_on.png", "lwcollector_on.png", "lwcollector_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:collector_locked",
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node_locked,
	can_dig = can_dig,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



utils.hopper_add_container({
	{"top", "lwcomponents:collector", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:collector", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:collector", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:collector_locked", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:collector_locked", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:collector_locked", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:collector_on", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:collector_on", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:collector_on", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:collector_locked_on", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:collector_locked_on", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:collector_locked_on", "main"}, -- insert items from hopper at side
})



end -- utils.digilines_supported



--
