local utils = ...
local S = utils.S



if utils.digilines_supported and utils.mesecon_supported then



local function get_mesecon_rule_for_side (side)
	local base = nil

	if side == "white" then
		return { { x = 0, y = 1, z = 0 } }
	elseif side == "black" then
		return { { x = 0, y = -1, z = 0 } } -- down doesn't work
	elseif side == "red" then
		return { { x = -1, y = 0, z = 0 } }
	elseif side == "green" then
		return { { x = 1, y = 0, z = 0 } }
	elseif side == "blue" then
		return { { x = 0, y = 0, z = -1 } }
	elseif side == "yellow" then
		return { { x = 0, y = 0, z = 1 } }
	elseif side == "switch" then
		return nil
	else
		return
		{
			{ x =  1, y =  0, z =  0 },
			{ x = -1, y =  0, z =  0 },
			{ x =  0, y =  0, z =  1 },
			{ x =  0, y =  0, z = -1 },
			{ x =  0, y =  1, z =  0 },
			{ x =  0, y = -1, z =  0 }, -- down doesn't work
		}
	end
end



local function digilines_support ()
	return
	{
		wire =
		{
			rules =
			{
				{ x =  0, y =  0, z = -1 },
				{ x =  1, y =  0, z =  0 },
				{ x = -1, y =  0, z =  0 },
				{ x =  0, y =  0, z =  1 },
				{ x =  1, y =  1, z =  0 },
				{ x =  1, y = -1, z =  0 },
				{ x = -1, y =  1, z =  0 },
				{ x = -1, y = -1, z =  0 },
				{ x =  0, y =  1, z =  1 },
				{ x =  0, y = -1, z =  1 },
				{ x =  0, y =  1, z = -1 },
				{ x =  0, y = -1, z = -1 },
				{ x =  0, y =  1, z =  0 },
				{ x =  0, y = -1, z =  0 }
			}
		},

		effector =
		{
			action = function (pos, node, channel, msg)
				local meta = minetest.get_meta(pos)

				if meta then
					local mychannel = meta:get_string ("channel")

					if mychannel == channel then
						if type (msg) == "string" then
							local words = { }

							for word in string.gmatch (msg, "%S+") do
								words[#words + 1] = word
							end

							if words[1] == "on" then
								utils.mesecon_receptor_on (pos, get_mesecon_rule_for_side (words[2]))
							elseif words[1] == "off" then
								utils.mesecon_receptor_off (pos, get_mesecon_rule_for_side (words[2]))
							end
						end
					end
				end
			end,
		}
	}
end



local function mesecon_support ()
	return
	{
		receptor =
		{
			state = mesecon.state.off,
			rules =
			{
				{ x =  1, y =  0, z =  0 },
				{ x = -1, y =  0, z =  0 },
				{ x =  0, y =  0, z =  1 },
				{ x =  0, y =  0, z = -1 },
				{ x =  0, y =  1, z =  0 },
				{ x =  0, y = -1, z =  0 }, -- down doesn't work
			}
		},
	}
end



local function on_construct (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		meta:set_string ("channel", "")

		local formspec =
		"formspec_version[3]\n"..
		"size[6.0,4.0]\n"..
		"field[1.0,0.8;4.0,1.0;channel;Channel;]\n"..
		"button_exit[2.0,2.5;2.0,1.0;set;Set]\n"

		meta:set_string ("formspec", formspec)
	end
end



local function on_destruct (pos)
	utils.mesecon_receptor_off (pos, get_mesecon_rule_for_side ())
end



local function on_receive_fields (pos, formname, fields, sender)
	if fields.channel then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("channel", fields.channel or "")

			local formspec =
			"formspec_version[3]\n"..
			"size[6.0,4.0]\n"..
			"field[1.0,0.8;4.0,1.0;channel;Channel;"..minetest.formspec_escape (meta:get_string ("channel")).."]\n"..
			"button_exit[2.0,2.5;2.0,1.0;set;Set]\n"

			meta:set_string ("formspec", formspec)
		end
	end
end



minetest.register_node ("lwcomponents:digiswitch", {
   description = S("Digilines Switch"),
   tiles = { "lwdigiswitch_white.png", "lwdigiswitch_black.png",
				 "lwdigiswitch_green.png", "lwdigiswitch_red.png",
				 "lwdigiswitch_yellow.png", "lwdigiswitch_blue.png" },
   sunlight_propagates = false,
   drawtype = "normal",
   node_box = {
      type = "fixed",
      fixed = {
         {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
      }
   },
	groups = { cracky = 2, oddly_breakable_by_hand = 2 },
	sounds = default.node_sound_stone_defaults (),
	mesecons = mesecon_support (),
	digiline = digilines_support (),
	_digistuff_channelcopier_fieldname = "channel",

   on_construct = on_construct,
   on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
})



end -- utils.digilines_supported and utils.mesecon_supported
