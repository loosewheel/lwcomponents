local utils = ...
local S = utils.S



if utils.digilines_supported and utils.mesecon_supported then



local function get_mesecon_rule_for_side (side)
	if side == "white" then
		return { { x = 0, y = 1, z = 0 } }
	elseif side == "black" then
		return { { x = 0, y = -1, z = 0 } }
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
			{ x =  0, y = -1, z =  0 },
		}
	end
end



local side_bits =
{
	["white"]	= 0,
	["black"]	= 1,
	["red"]		= 2,
	["green"]	= 3,
	["blue"]		= 4,
	["yellow"]	= 5
}



local function get_side_bit (side)
	if side then
		if side == "switch" then
			return 64
		end

		local bit = side_bits[side]

		if bit then
			return math.pow (2, bit)
		end
	end

	return 63
end



local function is_side_on (bits, side)
	local bit = get_side_bit (side)

	for i = 0, 6, 1 do
		if (bit % 2) == 1 and (bits % 2) ~= 1 then
			return false
		end

		bit = math.floor (bit / 2)
		bits = math.floor (bits / 2)
	end

	return true
end



local function set_side_bit (bits, side, on)
	local bit = get_side_bit (side)
	local result = 0

	for i = 0, 6, 1 do
		if (bit % 2) == 1 then
			if on then
				result = result + math.pow (2, i)
			end
		elseif (bits % 2) == 1 then
			result = result + math.pow (2, i)
		end

		bit = math.floor (bit / 2)
		bits = math.floor (bits / 2)
	end

	return result
end



local function get_powered_rules (node)
	local rules = { }

	if is_side_on (node.param1, "switch") then
		rules = table.copy (utils.mesecon_default_rules)

		if is_side_on (node.param1, "white") then
			rules[#rules + 1] = get_mesecon_rule_for_side ("white")[1]
		end

		if is_side_on (node.param1, "black") then
			rules[#rules + 1] = get_mesecon_rule_for_side ("black")[1]
		end
	else
		local sides =
		{
			"white",
			"black",
			"red",
			"green",
			"blue",
			"yellow",
		}

		for _, side in ipairs (sides) do
			if is_side_on (node.param1, side) then
				rules[#rules + 1] = get_mesecon_rule_for_side (side)[1]
			end
		end
	end

	return rules
end



local function get_node_name (node)
	if node.param1 ~= 0 then
		return "lwcomponents:digiswitch_on"
	end

	return "lwcomponents:digiswitch"
end



local function switch_on (pos, side)
	utils.mesecon_receptor_on (pos, get_mesecon_rule_for_side (side))

	local node = utils.get_far_node (pos)
	if node then
		node.param1 = set_side_bit (node.param1, side, true)
		node.name = get_node_name (node)
		minetest.swap_node (pos, node)
	end
end



local function switch_off (pos, side)
	utils.mesecon_receptor_off (pos, get_mesecon_rule_for_side (side))

	local node = utils.get_far_node (pos)
	if node then
		node.param1 = set_side_bit (node.param1, side, false)
		node.name = get_node_name (node)
		minetest.swap_node (pos, node)
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

					if mychannel ~= "" and mychannel == channel then
						if type (msg) == "string" then
							local words = { }

							for word in string.gmatch (msg, "%S+") do
								words[#words + 1] = word
							end

							if words[1] == "on" then
								switch_on (pos, words[2])
							elseif words[1] == "off" then
								switch_off (pos, words[2])
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
	}
end



local function mesecon_support_on ()
	return
	{
		receptor =
		{
			state = mesecon.state.on,
			rules = get_powered_rules
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
		"field[1.0,0.8;4.0,1.0;channel;Channel;${channel}]\n"..
		"button_exit[2.0,2.5;2.0,1.0;set;Set]\n"

		meta:set_string ("formspec", formspec)
	end
end



local function on_destruct (pos)
	local node = utils.get_far_node (pos)

	if node then
		local rules = get_powered_rules (node)

		if #rules > 0 then
			utils.mesecon_receptor_off (pos, rules)
		end
	end
end



local function on_receive_fields (pos, formname, fields, sender)
	if fields.channel then
		local meta = minetest.get_meta (pos)

		if meta then
			meta:set_string ("channel", fields.channel or "")
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
	paramtype = "none",
	param1 = 0,
	groups = { cracky = 2, oddly_breakable_by_hand = 2 },
	sounds = default.node_sound_stone_defaults (),
	mesecons = mesecon_support (),
	digiline = digilines_support (),
	_digistuff_channelcopier_fieldname = "channel",

   on_construct = on_construct,
   on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
})



minetest.register_node ("lwcomponents:digiswitch_on", {
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
	paramtype = "none",
	param1 = 0,
	groups = { cracky = 2, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),
	mesecons = mesecon_support_on (),
	digiline = digilines_support (),
	_digistuff_channelcopier_fieldname = "channel",

   on_construct = on_construct,
   on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
})



end -- utils.digilines_supported and utils.mesecon_supported
