local utils, mod_storage = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local transfer_rate = 0.1
local conduit_interval = 1.0
local conduit_connections = utils.connections:new (mod_storage, "conduit_connections")



local function get_target_list (pos)
	local tlist = conduit_connections:get_connected_ids (pos)
	local list = { }

	for i = 1, #tlist do
		if tlist[i].pos.x ~= pos.x or
			tlist[i].pos.y ~= pos.y or
			tlist[i].pos.y ~= pos.y then

			list[#list + 1] = tlist[i].id
		end
	end

	return list
end



local function send_targets_message (pos)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "targets",
															targets = get_target_list (pos) })
			end
		end
	end
end



local function deliver_slot (pos, slot)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()
		local transfer_data = minetest.deserialize (meta:get_string ("transfer_data"))

		if inv then
			local item = inv:get_stack ("transfer", slot)

			if transfer_data[slot] and item and not item:is_empty () then
				local tmeta = minetest.get_meta (transfer_data[slot].pos)

				if tmeta then
					local tinv = tmeta:get_inventory ()

					if tinv then
						tinv:add_item ("main", item)

						--send_conduit_message (pos, target, slot)
					end
				end
			end

			transfer_data[slot] = nil
			meta:set_string ("transfer_data", minetest.serialize (transfer_data))
			inv:set_stack ("transfer", slot, nil)
		end
	end
end



local function run_deliveries (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()
		local transfer_data = minetest.deserialize (meta:get_string ("transfer_data")) or { }

		if inv then
			local slots = inv:get_size ("transfer")
			local tm = minetest.get_us_time ()

			for i = 1, slots do
				if transfer_data[i] and
					(transfer_data[i].due <= tm or
					 tm < (transfer_data[i].due - 1000000000)) then

					deliver_slot (pos, i)
				end
			end
		end

		return not inv:is_empty ("transfer")
	end

	return false
end



local function deliver_all (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			local slots = inv:get_size ("transfer")

			for i = 1, slots do
				local item = inv:get_stack ("transfer", i)

				if item and not item:is_empty () then
					deliver_slot (pos, i)
				end
			end
		end

		meta:set_string ("transfer_data", minetest.serialize({ }))
		inv:set_list ("transfer", { })
	end
end



local function delivered_earliest (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()
		local transfer_data = minetest.deserialize (meta:get_string ("transfer_data")) or { }

		if inv then
			local slots = inv:get_size ("transfer")
			local slot = 0
			local tm = 0

			for i = 1, slots do
				if transfer_data[i] and transfer_data[i].due < tm then
					slot = i
					tm = transfer_data[i].due
				end
			end

			if slot > 0 then
				deliver_slot (pos, slot)
			end
		end
	end
end



local function get_transfer_free_slot (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			local slots = inv:get_size ("transfer")

			for i = 1, slots do
				local item = inv:get_stack ("transfer", i)

				if not item or item:is_empty () then
					return i
				end
			end
		end
	end

	return 0
end



local function add_to_send_list (pos, item, destpos, distance)
	local slot = get_transfer_free_slot (pos)

	while slot < 1 do
		delivered_earliest (pos)
	end

	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()
		local transfer_data = minetest.deserialize (meta:get_string ("transfer_data")) or { }

		if inv then
			transfer_data[slot] =
			{
				pos = destpos,
				due = minetest.get_us_time () + (transfer_rate * 1000000 * distance)
			}

			inv:add_item ("transfer", item)

			meta:set_string ("transfer_data", minetest.serialize (transfer_data))

			local timer = minetest.get_node_timer (pos)

			if not timer:is_started () then
				timer:start (conduit_interval)
			end
		end
	end
end



local function send_to_target (pos, target, slot)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		target = (target and tostring (target)) or meta:get_string ("target")

		if inv and target:len () > 0 then
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

						local tpos, distance = conduit_connections:is_connected (pos, target)

						if tpos then
							local tmeta = minetest.get_meta (tpos)

							if tmeta then
								local tinv = tmeta:get_inventory ()

								if tinv and tinv:room_for_item ("main", item) then
									add_to_send_list (pos, item, tpos, distance)

									stack:set_count (stack:get_count () - 1)
									inv:set_stack ("main", slot, stack)

									--send_conduit_message (pos, target, slot)

									return true, target, slot
								end
							end
						end
					end
				end
			end
		end
	end

	return false
end



local function run_conduit (pos)
	local meta = minetest.get_meta (pos)
	local automatic = false

	if meta then
		automatic = meta:get_string ("automatic") == "true"
	end

	if automatic then
		send_to_target (pos)
	end

	return run_deliveries (pos) or automatic
end



local function get_formspec (pos)
	local meta = minetest.get_meta (pos)
	local automatic = "false"

	if meta then
		automatic = meta:get_string ("automatic")
	end

	return
		"formspec_version[3]\n"..
		"size[11.75,12.25;true]\n"..
		"field[1.0,1.5;3.0,0.8;channel;Channel;${channel}]\n"..
		"button[4.2,1.5;1.5,0.8;setchannel;Set]\n"..
		"field[1.0,3.0;3.0,0.8;target;Target;${target}]\n"..
		"button[4.2,3.0;1.5,0.8;settarget;Set]\n"..
		"checkbox[1.0,4.5;automatic;Automatic;"..automatic.."]\n"..
		"list[context;main;6.0,1.0;4,4;]\n"..
		"list[current_player;main;1.0,6.5;8,4;]\n"..
		"listring[]"
end



local function on_construct (pos)
	conduit_connections:add_node (pos)
end



local function on_destruct (pos)
	deliver_all (pos)
	conduit_connections:remove_node (pos)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"formspec_version[3]"..
	"size[7.0,3.8]"..
	"field[0.5,1.0;6.0,0.8;channel;Channel;${channel}]"..
	"button[2.0,2.3;3.0,0.8;setchannel;Set]"

	meta:set_string ("inventory", "{ main = { }, transfer = { } }")
	meta:set_string ("formspec", spec)
	meta:set_string ("transfer_data", minetest.serialize({ }))
	meta:set_string ("automatic", "false")

	local inv = meta:get_inventory ()

	inv:set_size ("main", 16)
	inv:set_width ("main", 4)

	inv:set_size ("transfer", 32)
	inv:set_width ("transfer", 8)

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
			if tostring (fields.channel):len () > 0 then
				if meta:get_string ("channel"):len () < 1 then
					meta:set_string ("formspec", get_formspec (pos))
				end

				meta:set_string ("channel", fields.channel)

				conduit_connections:set_id (pos, tostring (fields.channel))

			elseif meta:get_string ("channel"):len () > 0 then
				if can_dig (pos, sender) ~= false then
					local spec =
					"formspec_version[3]"..
					"size[7.0,3.8]"..
					"field[0.5,1.0;6.0,0.8;channel;Channel;${channel}]"..
					"button[2.0,2.3;3.0,0.8;setchannel;Set]"

					meta:set_string ("channel", fields.channel)

					meta:set_string ("formspec", spec)

					conduit_connections:set_id (pos, nil)

				elseif sender and sender:is_player () then
					fields.channel = meta:get_string ("channel")

					local spec =
					"formspec_version[3]"..
					"size[8.0,4.0,false]"..
					"label[2.5,1.0;Conduit not empty]"..
					"button_exit[3.0,2.0;2.0,1.0;close;Close]"

					minetest.show_formspec (sender:get_player_name (),
													"lwcomponents:conduit_not_empty",
													spec)

				end
			end
		end
	end

	if fields.settarget then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("target", fields.target)
		end
	end

	if fields.automatic then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("automatic", fields.automatic)
			meta:set_string ("formspec", get_formspec (pos))

			local timer = minetest.get_node_timer (pos)

			if not timer:is_started () then
				timer:start (conduit_interval)
			end
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
	end

	return itemstack
end



local function on_timer (pos, elapsed)
	return run_conduit (pos)
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

								if m[1] == "target" then
									meta:set_string ("target", (m[2] and tostring (m[2])) or "")

								elseif m[1] == "targets" then
									send_targets_message (pos)

								elseif m[1] == "transfer" then
									send_to_target (pos)

								end

							elseif type (msg) == "table" then
								if msg.action and tostring (msg.action) == "transfer" then
									send_to_target (pos, msg.target, msg.slot or msg.item)
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
					send_to_target (pos)
				end
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:conduit", {
	description = S("Conduit"),
	drawtype = "glasslike_framed",
	tiles = { "lwconduit_edge.png", "lwconduit.png" },
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_construct = on_construct,
	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node,
	can_dig = can_dig,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:conduit_locked", {
	description = S("Conduit (locked)"),
	drawtype = "glasslike_framed",
	tiles = { "lwconduit_edge.png", "lwconduit.png" },
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_construct = on_construct,
	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node_locked,
	can_dig = can_dig,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



utils.hopper_add_container({
	{"top", "lwcomponents:conduit", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:conduit", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:conduit", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:conduit_locked", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:conduit_locked", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:conduit_locked", "main"}, -- insert items from hopper at side
})



end -- utils.digilines_supported or utils.mesecon_supported
