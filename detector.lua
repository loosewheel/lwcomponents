local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local detect_interval = 0.5



local function mesecons_on (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		if meta:get_int ("power_on") == 0 then
			utils.mesecon_receptor_on (pos, utils.mesecon_default_rules)
			meta:set_int ("power_on", 1)
		end
	end
end



local function mesecons_off (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		if meta:get_int ("power_on") ~= 0 then
			utils.mesecon_receptor_off (pos, utils.mesecon_default_rules)
			meta:set_int ("power_on", 0)
		end
	end
end



local function to_relative_coords (pos, testpos)
	local base = { x = testpos.x - pos.x,
						y = testpos.y - pos.y,
						z = testpos.z - pos.z }
	local node = minetest.get_node (pos)

	if node then
		if node.param2 == 3 then -- +x
			return { x = (base.z * -1), y = base.y, z = base.x }
		elseif node.param2 == 0 then -- -z
			return { x = (base.x * -1), y = base.y, z = (base.z * -1) }
		elseif node.param2 == 1 then -- -x
			return { x = base.z, y = base.y, z = (base.x * -1) }
		elseif node.param2 == 2 then -- +z
			return { x = base.x, y = base.y, z = base.z }
		end
	end

	return { x = 0, y = 0, z = 0 }
end



local function send_detect_message (pos, item_type, name, label, item_pos, count)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 digiline.rules.default,
														 channel,
														 { action = "detect",
															type = item_type,
															name = name,
															label = label,
															pos = to_relative_coords (pos, item_pos),
															count = count })
			end
		end
	end
end



local function filter_item (pos, mode, testpos)
	local base = { x = math.floor (testpos.x - pos.x + 0.5),
						y = math.floor (testpos.y - pos.y + 0.5),
						z = math.floor (testpos.z - pos.z + 0.5) }

	if base.x == 0 and base.y == 0 and base.z == 0 then
		return false
	end

	if mode == 1 then
		-- all
		return true

	elseif mode == 2 then
		-- forward
		local node = minetest.get_node (pos)

		if node then
			if node.param2 == 0 then
				-- -z
				return (base.x == 0 and base.y == 0 and base.z < 0)
			elseif node.param2 == 1 then
				-- -x
				return (base.x < 0 and base.y == 0 and base.z == 0)
			elseif node.param2 == 2 then
				-- +z
				return (base.x == 0 and base.y == 0 and base.z > 0)
			elseif node.param2 == 3 then
				-- +x
				return (base.x > 0 and base.y == 0 and base.z == 0)
			end
		end

	elseif mode == 3 then
		-- up
		return (base.x == 0 and base.z == 0 and base.y > 0)

	elseif mode == 4 then
		-- down
		return (base.x == 0 and base.z == 0 and base.y < 0)

	end

	return false
end



local function detect (pos)
	local meta = minetest.get_meta (pos)
	local detected = false

	if meta then
		local radius = meta:get_int ("radius")
		local mode = meta:get_int ("mode")
		local object = minetest.get_objects_inside_radius (pos, radius + 0.5)

		for i = 1, #object do
			if object[i]:is_player () then

				-- player
				if meta:get_string ("players") == "true" and
					filter_item (pos, mode, object[i]:get_pos ()) then

					send_detect_message (pos,
												"player",
												object[i]:get_player_name (),
												object[i]:get_player_name (),
												object[i]:get_pos (),
												1)

					detected = true
				end

			elseif object[i].get_luaentity and object[i]:get_luaentity () and
					 object[i]:get_luaentity ().name and
					 object[i]:get_luaentity ().name == "__builtin:item" then

				-- drop
				if meta:get_string ("drops") == "true" and
					filter_item (pos, mode, object[i]:get_pos ()) then

					local stack = ItemStack (object[i]:get_luaentity ().itemstring or "")

					if stack and not stack:is_empty () then
						send_detect_message (pos,
													"drop",
													stack:get_name (),
													stack:get_name (),
													object[i]:get_pos (),
													stack:get_count ())

						detected = true
					end

				end

			elseif object[i].get_pos and object[i]:get_pos () then

				-- entity
				if meta:get_string ("entities") == "true" and
					filter_item (pos, mode, object[i]:get_pos ()) then

					local name = object[i]:get_nametag_attributes ()
					local label = ""

					if type (name) == "table" then
						label = tostring (name.text or "")
					end

					name = (object[i].get_luaentity and
							  object[i]:get_luaentity () and
							  object[i]:get_luaentity ().name) or ""

					send_detect_message (pos,
												"entity",
												name,
												label,
												object[i]:get_pos (),
												1)

					detected = true

				end

			end
		end


		if meta:get_string ("nodes") == "true" then
			for y = (pos.y - radius), (pos.y + radius) do
				for x = (pos.x - radius), (pos.x + radius) do
					for z = (pos.z - radius), (pos.z + radius) do
						local testpos = { x = x, y = y, z = z }
						local node = minetest.get_node (testpos)

						if node and node.name ~= "air" and node.name ~= "ignore" and
							filter_item (pos, mode, testpos) then

							send_detect_message (pos,
														"node",
														node.name,
														node.name,
														testpos,
														1)

							detected = true
						end
					end
				end
			end
		end

		if detected then
			mesecons_on (pos)
		else
			mesecons_off (pos)
		end
	end
end



local function get_form_spec (is_off, radius, entities, players, drops, nodes, mode)
	return
	"formspec_version[3]\n"..
	"size[11.75,9.0;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"button[8.25,1.0;2.5,0.8;"..((is_off and "start;Start") or "stop;Stop").."]\n"..
	"field[1.0,2.5;4.0,0.8;radius;Radius;"..tostring (radius).."]\n"..
	"button[5.5,2.5;2.0,0.8;setradius;Set]\n"..
	"checkbox[1.0,4.4;entities;Entities;"..entities.."]\n"..
	"checkbox[1.0,5.4;players;Players;"..players.."]\n"..
	"checkbox[1.0,6.4;drops;Drops;"..drops.."]\n"..
	"checkbox[1.0,7.4;nodes;Nodes;"..nodes.."]\n"..
	"textlist[4.875,4.0;5.875,4.0;mode;All,Forward,Up,Down;"..tostring (mode)..";false]"
end



local function update_form_spec (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		local is_off = node.name == "lwcomponents:detector" or
							node.name == "lwcomponents:detector_locked"

		meta:set_string ("formspec",
							  get_form_spec (is_off,
												  meta:get_int ("radius"),
												  meta:get_string ("entities"),
												  meta:get_string ("players"),
												  meta:get_string ("drops"),
												  meta:get_string ("nodes"),
												  meta:get_int ("mode")))
	end
end



local function start_detector (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		if node.name == "lwcomponents:detector" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:detector_on"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):start (detect_interval)
				update_form_spec (pos)
			end

		elseif node.name == "lwcomponents:detector_locked" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:detector_locked_on"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):start (detect_interval)
				update_form_spec (pos)
			end

		end
	end
end



local function stop_detector (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		if node.name == "lwcomponents:detector_on" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:detector"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):stop ()
				mesecons_off (pos)
				update_form_spec (pos)
			end

		elseif node.name == "lwcomponents:detector_locked_on" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:detector_locked"

				minetest.swap_node (pos, node)
				minetest.get_node_timer (pos):stop ()
				mesecons_off (pos)
				update_form_spec (pos)
			end

		end
	end
end



local function on_destruct (pos)
	minetest.get_node_timer (pos):stop ()

	mesecons_off (pos)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local is_off = itemstack and (itemstack:get_name () == "lwcomponents:detector" or
											itemstack:get_name () == "lwcomponents:detector_locked")

	meta:set_string ("inventory", "{ main = { }, filter = { } }")
	meta:set_string ("formspec", get_form_spec (is_off, 1, 0, 0, 0, 0, 1))

	meta:set_string ("entities", "false")
	meta:set_string ("players", "false")
	meta:set_string ("drops", "false")
	meta:set_string ("nodes", "false")
	meta:set_int ("mode", 1)
	meta:set_int ("radius", 1)
	meta:set_int ("power_on", 0)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Detector (owned by "..placer:get_player_name ()..")")
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
			local radius = math.min (math.max (tonumber (fields.radius) or 1, 1), 5)

			meta:set_int ("radius", radius)
			update_form_spec (pos)
		end
	end

	if fields.start then
		start_detector (pos)
	end

	if fields.stop then
		stop_detector (pos)
	end

	if fields.entities ~= nil then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("entities", fields.entities)
			update_form_spec (pos)
		end
	end

	if fields.players ~= nil then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("players", fields.players)
			update_form_spec (pos)
		end
	end

	if fields.drops ~= nil then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("drops", fields.drops)
			update_form_spec (pos)
		end
	end

	if fields.nodes ~= nil then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("nodes", fields.nodes)
			update_form_spec (pos)
		end
	end

	if fields.mode then
		local event = minetest.explode_textlist_event (fields.mode)

		if event.type == "CHG" then
			local meta = minetest.get_meta (pos)

			if meta then
				meta:set_int ("mode", event.index)
				update_form_spec (pos)
			end
		end
	end
end



local function can_dig (pos, player)
	if not utils.can_interact_with_node (pos, player) then
		return false
	end

	return true
end



local function on_blast (pos, intensity)
	local meta = minetest.get_meta (pos)

	if meta then
		if intensity >= 1.0 then
			on_destruct (pos)
			minetest.remove_node (pos)

		else -- intensity < 1.0
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



local function on_timer (pos, elapsed)
	detect (pos)

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



local function digilines_support ()
	if utils.digilines_supported then
		return
		{
			wire =
			{
				rules = digiline.rules.default,
			},

			effector =
			{
				action = function (pos, node, channel, msg)
					local meta = minetest.get_meta(pos)

					if meta then
						local this_channel = meta:get_string ("channel")

						if this_channel == channel then
							local m = { }
							for w in string.gmatch(msg, "[^%s]+") do
								m[#m + 1] = w
							end

							if m[1] == "start" then
								start_detector (pos)

							elseif m[1] == "stop" then
								stop_detector (pos)

							elseif m[1] == "radius" then
								local radius = math.min (math.max (tonumber (m[2] or 1) or 1, 1), 5)

								meta:set_int ("radius", radius)
								update_form_spec (pos)

							elseif m[1] == "entities" then
								meta:set_string ("entities", ((m[2] == "true") and "true") or "false")
								update_form_spec (pos)

							elseif m[1] == "players" then
								meta:set_string ("players", ((m[2] == "true") and "true") or "false")
								update_form_spec (pos)

							elseif m[1] == "drops" then
								meta:set_string ("drops", ((m[2] == "true") and "true") or "false")
								update_form_spec (pos)

							elseif m[1] == "nodes" then
								meta:set_string ("nodes", ((m[2] == "true") and "true") or "false")
								update_form_spec (pos)


							elseif m[1] == "mode" then
								if m[2] == "all" then
									meta:set_int ("mode", 1)
									update_form_spec (pos)

								elseif m[2] == "forward" then
									meta:set_int ("mode", 2)
									update_form_spec (pos)

								elseif m[2] == "up" then
									meta:set_int ("mode", 3)
									update_form_spec (pos)

								elseif m[2] == "down" then
									meta:set_int ("mode", 4)
									update_form_spec (pos)

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
			receptor =
			{
				state = utils.mesecon_state_off,
				rules = utils.mesecon_default_rules
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:detector", {
	description = S("Detector"),
	tiles = { "lwdetector_face.png", "lwdetector_face.png", "lwdetector.png",
				 "lwdetector.png", "lwdetector.png", "lwdetector_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:detector",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:detector_locked", {
	description = S("Detector (locked)"),
	tiles = { "lwdetector_face.png", "lwdetector_face.png", "lwdetector.png",
				 "lwdetector.png", "lwdetector.png", "lwdetector_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:detector_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:detector_on", {
	description = S("Detector"),
	tiles = { "lwdetector_face_on.png", "lwdetector_face_on.png", "lwdetector.png",
				 "lwdetector.png", "lwdetector.png", "lwdetector_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:detector",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:detector_locked_on", {
	description = S("Detector (locked)"),
	tiles = { "lwdetector_face_on.png", "lwdetector_face_on.png", "lwdetector.png",
				 "lwdetector.png", "lwdetector.png", "lwdetector_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:detector_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_timer = on_timer,
	on_rightclick = on_rightclick
})



end -- utils.digilines_supported or utils.mesecon_supported



--
