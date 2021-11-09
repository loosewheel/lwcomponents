local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local sound_interval = 5.0



local siren_sounds =
{
	"lwsiren-buzz",
	"lwsiren-horn",
	"lwsiren-raid",
	"lwsiren-siren",
}



local function start_sound (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local handle = meta:get_int ("sound_handle")

		if handle ~= 0 then
			minetest.sound_stop (handle)
			meta:set_int ("sound_handle", 0)
		end

		local sound = siren_sounds[meta:get_int ("sound")]

		if sound then
			handle = minetest.sound_play (
				sound,
				{
					pos = pos,
					max_hear_distance = meta:get_int ("distance"),
					gain = meta:get_int ("gain") / 100
				})

			meta:set_int ("sound_handle", handle)
		end
	end
end



local function stop_sound (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		local handle = meta:get_int ("sound_handle")

		if handle ~= 0 then
			minetest.sound_stop (handle)
			meta:set_int ("sound_handle", 0)
		end
	end
end



local function get_form_spec (is_off, distance, gain, sound)
	return
	"formspec_version[3]\n"..
	"size[11.75,6.0;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]\n"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]\n"..
	"button[8.25,1.0;2.5,0.8;"..((is_off and "start;Start") or "stop;Stop").."]\n"..
	"label[1.0,2.5;Distance]\n"..
	"scrollbaroptions[min=0;max=100;smallstep=10;largestep=10;thumbsize=10]\n"..
	"scrollbar[1.0,2.9;6.0,0.5;horizontal;distance;"..tostring (distance).."]\n"..
	"label[1.0,4.2;Volume]\n"..
	"scrollbaroptions[min=0;max=100;smallstep=10;largestep=10;thumbsize=10]\n"..
	"scrollbar[1.0,4.5;6.0,0.5;horizontal;gain;"..tostring (gain).."]\n"..
	"textlist[7.75,2.25;3.0,2.75;sound;Buzzer,Horn,Raid,Siren;"..tostring (sound)..";false]"
end



local function update_form_spec (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		local is_off = node.name == "lwcomponents:siren" or
							node.name == "lwcomponents:siren_locked"

		meta:set_string ("formspec",
							  get_form_spec (is_off,
												  meta:get_int ("distance"),
												  meta:get_int ("gain"),
												  meta:get_int ("sound")))
	end
end



local function start_siren (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		if node.name == "lwcomponents:siren" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren_on"

				stop_sound (pos)
				minetest.swap_node (pos, node)
				update_form_spec (pos)
			end

		elseif node.name == "lwcomponents:siren_locked" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren_locked_on"

				stop_sound (pos)
				minetest.swap_node (pos, node)
				update_form_spec (pos)
			end

		end
	end
end



local function stop_siren (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		if node.name == "lwcomponents:siren_on" or
			node.name == "lwcomponents:siren_alarm" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren"

				minetest.get_node_timer (pos):stop ()
				stop_sound (pos)
				minetest.swap_node (pos, node)
				update_form_spec (pos)
			end

		elseif node.name == "lwcomponents:siren_locked_on" or
				 node.name == "lwcomponents:siren_locked_alarm" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren_locked"

				minetest.get_node_timer (pos):stop ()
				stop_sound (pos)
				minetest.swap_node (pos, node)
				update_form_spec (pos)
			end

		end
	end
end



local function start_alarm (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		if node.name == "lwcomponents:siren_on" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren_alarm"

				minetest.get_node_timer (pos):start (sound_interval)
				start_sound (pos)
				minetest.swap_node (pos, node)
			end

		elseif node.name == "lwcomponents:siren_locked_on" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren_locked_alarm"

				minetest.get_node_timer (pos):start (sound_interval)
				start_sound (pos)
				minetest.swap_node (pos, node)
			end

		end
	end
end



local function stop_alarm (pos)
	local node = minetest.get_node (pos)
	local meta = minetest.get_meta (pos)

	if node and meta then
		if node.name == "lwcomponents:siren_alarm" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren_on"

				minetest.get_node_timer (pos):stop ()
				stop_sound (pos)
				minetest.swap_node (pos, node)
			end

		elseif node.name == "lwcomponents:siren_locked_alarm" then
			local meta = minetest.get_meta (pos)

			if meta then
				node.name = "lwcomponents:siren_locked_on"

				minetest.get_node_timer (pos):stop ()
				stop_sound (pos)
				minetest.swap_node (pos, node)
			end

		end
	end
end



local function on_destruct (pos)
	minetest.get_node_timer (pos):stop ()
	stop_sound (pos)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local is_off = itemstack and (itemstack:get_name () == "lwcomponents:siren" or
											itemstack:get_name () == "lwcomponents:siren_locked")

	meta:set_string ("formspec", get_form_spec (is_off, 10, 50, 1))

	meta:set_int ("sound", 1)
	meta:set_int ("distance", 10)
	meta:set_int ("gain", 50)
	meta:set_int ("sound_handle", 0)

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

	if fields.start then
		start_siren (pos)
	end

	if fields.stop then
		stop_siren (pos)
	end

	if fields.sound then
		local event = minetest.explode_textlist_event (fields.sound)

		if event.type == "CHG" then
			local meta = minetest.get_meta (pos)

			if meta then
				meta:set_int ("sound", event.index)
			end
		end
	end

	if fields.gain then
		local event = minetest.explode_scrollbar_event (fields.gain)

		if event.type == "CHG" then
			local meta = minetest.get_meta (pos)

			if meta then
				meta:set_int ("gain", event.value)
			end
		end
	end

	if fields.distance then
		local event = minetest.explode_scrollbar_event (fields.distance)

		if event.type == "CHG" then
			local meta = minetest.get_meta (pos)

			if meta then
				meta:set_int ("distance", event.value)
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
	start_sound (pos)

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

	else
		update_form_spec (pos)
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

						if this_channel ~= "" and this_channel == channel then
							local m = { }
							for w in string.gmatch(msg, "[^%s]+") do
								m[#m + 1] = w
							end

							if m[1] == "start" then
								start_siren (pos)

							elseif m[1] == "stop" then
								stop_siren (pos)

							elseif m[1] == "siren" then
								if m[2] == "on" then
									start_alarm (pos)

								elseif m[2] == "off" then
									stop_alarm (pos)

								end

							elseif m[1] == "distance" then
								local distance = math.min (math.max (tonumber (m[2] or 1) or 1, 1), 100)

								meta:set_int ("distance", distance)

							elseif m[1] == "volume" then
								local volume = math.min (math.max (tonumber (m[2] or 1) or 1, 1), 100)

								meta:set_int ("gain", volume)

							elseif m[1] == "sound" then
								if m[2] == "buzzer" then
									meta:set_int ("sound", 1)
									update_form_spec (pos)

								elseif m[2] == "horn" then
									meta:set_int ("sound", 2)
									update_form_spec (pos)

								elseif m[2] == "raid" then
									meta:set_int ("sound", 3)
									update_form_spec (pos)

								elseif m[2] == "siren" then
									meta:set_int ("sound", 4)
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
			effector =
			{
				rules = utils.mesecon_default_rules,

				action_on = function (pos, node)
					-- do something to turn the effector on
					start_alarm (pos)
				end,

				action_off = function (pos, node)
					-- do something to turn the effector off
					stop_alarm (pos)
				end,
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:siren", {
	description = S("Siren"),
	tiles = { "lwsiren_base.png", "lwsiren_base.png", "lwsiren.png",
				 "lwsiren.png", "lwsiren.png", "lwsiren.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:siren",
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



minetest.register_node("lwcomponents:siren_locked", {
	description = S("Siren (locked)"),
	tiles = { "lwsiren_base.png", "lwsiren_base.png", "lwsiren.png",
				 "lwsiren.png", "lwsiren.png", "lwsiren.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:siren_locked",
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



minetest.register_node("lwcomponents:siren_on", {
	description = S("Siren"),
	tiles = { "lwsiren_base.png", "lwsiren_base.png", "lwsiren_on.png",
				 "lwsiren_on.png", "lwsiren_on.png", "lwsiren_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:siren",
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



minetest.register_node("lwcomponents:siren_locked_on", {
	description = S("Siren (locked)"),
	tiles = { "lwsiren_base.png", "lwsiren_base.png", "lwsiren_on.png",
				 "lwsiren_on.png", "lwsiren_on.png", "lwsiren_on.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	floodable = false,
	drop = "lwcomponents:siren_locked",
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



minetest.register_node("lwcomponents:siren_alarm", {
	description = S("Siren"),
	tiles = { "lwsiren_base.png", "lwsiren_base.png", "lwsiren_alarm.png",
				 "lwsiren_alarm.png", "lwsiren_alarm.png", "lwsiren_alarm.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:siren",
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



minetest.register_node("lwcomponents:siren_locked_alarm", {
	description = S("Siren (locked)"),
	tiles = { "lwsiren_base.png", "lwsiren_base.png", "lwsiren_alarm.png",
				 "lwsiren_alarm.png", "lwsiren_alarm.png", "lwsiren_alarm.png"},
	is_ground_content = false,
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	light_source = 3,
	floodable = false,
	drop = "lwcomponents:siren_locked",
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
