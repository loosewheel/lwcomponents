local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local function send_punch_message (pos, item_type, name, label)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "punch",
															type = item_type,
															name = name,
															label = label })
			end
		end
	end
end



local function direction_vector (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local mode = meta:get_int ("mode")

		if mode == 2 then
			return { x = 0, y = 1, z = 0 }
		elseif mode == 3 then
			return { x = 0, y = -1, z = 0 }
		else
			local node = minetest.get_node (pos)

			if node then
				if node.param2 == 0 then
					return { x = 0, y = 0, z = -1 }
				elseif node.param2 == 1 then
					return { x = -1, y = 0, z = 0 }
				elseif node.param2 == 2 then
					return { x = 0, y = 0, z = 1 }
				elseif node.param2 == 3 then
					return { x = 1, y = 0, z = 0 }
				end
			end
		end
	end

	return { x = 0, y = 0, z = 0 }
end



local function punch (pos)
	local meta = minetest.get_meta (pos)
	local node = minetest.get_node (pos)

	if meta and node and
		(node.name == "lwcomponents:puncher_on" or
		 node.name == "lwcomponents:puncher_locked_on") then

		local reach = tonumber (meta:get_string ("reach")) or 1
		local dir = direction_vector (pos)
		local punched = false

		for r = 1, reach do
			local tpos = vector.add (pos, vector.multiply (dir, r))
			local object = minetest.get_objects_inside_radius (tpos, 0.68)

			for i = 1, #object do
				if object[i]:is_player () then

					-- player
					if meta:get_string ("players") == "true" then

						object[i]:punch (object[i],
											  1.0,
											  { full_punch_interval = 1.0,
												 damage_groups = { fleshy = 4 } },
												vector.direction (pos, object[i]:get_pos ()))

						send_punch_message (pos,
												  "player",
												  object[i]:get_player_name (),
												  object[i]:get_player_name ())

						punched = true
					end

				elseif not utils.is_drop (object[i]) and object[i].get_pos
							and object[i]:get_pos () then

					-- entity
					if meta:get_string ("entities") == "true" then
						local name = object[i]:get_nametag_attributes ()
						local label = ""

						if type (name) == "table" then
							label = tostring (name.text or "")
						end

						name = (object[i].get_luaentity and
								  object[i]:get_luaentity () and
								  object[i]:get_luaentity ().name) or ""

						object[i]:punch (object[i],
											  1.0,
											  { full_punch_interval = 1.0,
												 damage_groups = { fleshy = 4 } },
												vector.direction (pos, object[i]:get_pos ()))

						send_punch_message (pos,
												  "entity",
												  name,
												  label)

						punched = true
					end

				end

			end

			if punched then
				break
			end
		end
	end
end



local function get_form_spec (is_off, mode, entities, players)
	return
	"formspec_version[3]\n"..
	"size[11.75,7.0;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"button[8.25,1.0;2.5,0.8;"..((is_off and "start;Start") or "stop;Stop").."]\n"..
	"field[1.0,2.5;4.0,0.8;reach;Reach;${reach}]\n"..
	"button[5.5,2.5;2.0,0.8;setreach;Set]\n"..
	"checkbox[1.0,4.4;entities;Entities;"..entities.."]\n"..
	"checkbox[1.0,5.4;players;Players;"..players.."]\n"..
	"textlist[4.875,4.0;5.875,2.0;mode;Forward,Up,Down;"..tostring (mode)..";false]"
end



local function update_form_spec (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		local is_off = node.name == "lwcomponents:puncher" or
							node.name == "lwcomponents:puncher_locked"

		meta:set_string ("formspec", get_form_spec (is_off,
																  meta:get_int ("mode"),
																  meta:get_string ("entities"),
																  meta:get_string ("players")))
	end
end



local function start_puncher (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:puncher" then
			node.name = "lwcomponents:puncher_on"

			minetest.swap_node (pos, node)
			update_form_spec (pos)

		elseif node.name == "lwcomponents:puncher_locked" then
			node.name = "lwcomponents:puncher_locked_on"

			minetest.swap_node (pos, node)
			update_form_spec (pos)

		end
	end
end



local function stop_puncher (pos)
	local node = minetest.get_node (pos)

	if node then
		if node.name == "lwcomponents:puncher_on" then
			node.name = "lwcomponents:puncher"

			minetest.swap_node (pos, node)
			update_form_spec (pos)

		elseif node.name == "lwcomponents:puncher_locked_on" then
			node.name = "lwcomponents:puncher_locked"

			minetest.swap_node (pos, node)
			update_form_spec (pos)

		end
	end
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local is_off = itemstack and (itemstack:get_name () == "lwcomponents:puncher" or
											itemstack:get_name () == "lwcomponents:puncher_locked")

	meta:set_string ("formspec", get_form_spec (is_off, 1, "false", "false"))

	meta:set_string ("reach", "1")
	meta:set_int ("mode", 1)
	meta:set_string ("entities", "false")
	meta:set_string ("players", "false")

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Puncher (owned by "..placer:get_player_name ()..")")
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

	if fields.setreach then
		local meta = minetest.get_meta (pos)

		if meta then
			local reach = math.min (math.max (tonumber (fields.reach) or 1, 1), 5)

			meta:set_string ("reach", tostring (reach))
		end
	end

	if fields.start then
		start_puncher (pos)
	end

	if fields.stop then
		stop_puncher (pos)
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
			minetest.remove_node (pos)

		else -- intensity < 1.0
			local node = minetest.get_node_or_nil (pos)
			if node then
				local items = minetest.get_node_drops (node, nil)

				if items and #items > 0 then
					local stack = ItemStack (items[1])

					if stack then
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

							if m[1] == "start" then
								start_puncher (pos)

							elseif m[1] == "stop" then
								stop_puncher (pos)

							elseif m[1] == "reach" then
								local reach = math.min (math.max (tonumber (m[2]) or 1, 1), 5)

								meta:set_string ("reach", tostring (reach))

							elseif m[1] == "entities" then
								meta:set_string ("entities", ((m[2] == "true") and "true") or "false")
								update_form_spec (pos)

							elseif m[1] == "players" then
								meta:set_string ("players", ((m[2] == "true") and "true") or "false")
								update_form_spec (pos)


							elseif m[1] == "mode" then
								if m[2] == "forward" then
									meta:set_int ("mode", 1)
									update_form_spec (pos)

								elseif m[2] == "up" then
									meta:set_int ("mode", 2)
									update_form_spec (pos)

								elseif m[2] == "down" then
									meta:set_int ("mode", 3)
									update_form_spec (pos)

								end

							elseif m[1] == "punch" then
								punch (pos)

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
					punch (pos)
				end
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:puncher", {
	description = S("Puncher"),
	tiles = { "lwpuncher_face.png", "lwpuncher_face.png", "lwpuncher.png",
				 "lwpuncher.png", "lwpuncher.png", "lwpuncher_face.png"},
	is_ground_content = false,
	groups = { cracky = 3, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:puncher",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:puncher_locked", {
	description = S("Puncher (locked)"),
	tiles = { "lwpuncher_face.png", "lwpuncher_face.png", "lwpuncher.png",
				 "lwpuncher.png", "lwpuncher.png", "lwpuncher_face.png"},
	is_ground_content = false,
	groups = { cracky = 3, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:puncher_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:puncher_on", {
	description = S("Puncher"),
	tiles = { "lwpuncher_face_on.png", "lwpuncher_face_on.png", "lwpuncher.png",
				 "lwpuncher.png", "lwpuncher.png", "lwpuncher_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:puncher",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:puncher_locked_on", {
	description = S("Puncher (locked)"),
	tiles = { "lwpuncher_face_on.png", "lwpuncher_face_on.png", "lwpuncher.png",
				 "lwpuncher.png", "lwpuncher.png", "lwpuncher_face_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1, wires_connect = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	drop = "lwcomponents:puncher_locked",
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),

	on_receive_fields = on_receive_fields,
	can_dig = can_dig,
	after_place_node = after_place_node_locked,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



end -- utils.digilines_supported or utils.mesecon_supported



--
