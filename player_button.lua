local utils = ...
local S = utils.S



if utils.digilines_supported and utils.digistuff_supported then



local function on_contruct (pos)
	local meta = minetest.get_meta(pos)
	local spec =
	"size[7.5,3]"..
	"field[1,1;6,2;channel;Channel;${channel}]"..
	"button_exit[2.5,2;3,1;submit;Set]"

	meta:set_string("formspec", spec)
end



local function on_receive_fields (pos, formname, fields, sender)
	local meta = minetest.get_meta(pos)

	if fields.submit then
		if fields.channel ~= "" then
			meta:set_string ("channel", fields.channel)
			meta:set_string ("formspec", "")
			minetest.swap_node (pos, { name = "lwcomponents:player_button_off",
												param2 = minetest.get_node(pos).param2 })
		else
			minetest.chat_send_player (sender:get_player_name(), "Please set a channel!")
		end
	end
end



local function player_button_push (pos, node, player)
	local meta = minetest.get_meta (pos)

	if player and player:is_player () then
		local channel = meta:get_string ("channel")
		local formspec = meta:get_string ("formspec")

		if channel:len () > 0 and formspec:len () == 0 then
			utils.digilines_receptor_send (pos,
													 digistuff.button_get_rules (node),
													 channel,
													 { action = "player",
														name = player:get_player_name () })
		end
	end

	if node.name == "lwcomponents:player_button_off" then
		node.name = "lwcomponents:player_button_on"

		minetest.swap_node(pos, node)

		if digistuff.mesecons_installed then
			minetest.sound_play ("mesecons_button_push", { pos = pos })
		end

		minetest.get_node_timer (pos):start (0.25)
	end
end



local function player_button_turnoff (pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)

	if node.name == "lwcomponents:player_button_on" then
		node.name = "lwcomponents:player_button_off"

		minetest.swap_node (pos, node)

		if digistuff.mesecons_installed then
			minetest.sound_play ("mesecons_button_pop", { pos = pos })
		end
	end
end



minetest.register_node ("lwcomponents:player_button", {
	description = "Player Button",
	drawtype = "nodebox",
	tiles = {
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button.png"
	},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "facedir",
	legacy_wallmounted = true,
	walkable = false,
	sunlight_propagates = true,
	drop = "lwcomponents:player_button",
	selection_box = {
	type = "fixed",
		fixed = { -6/16, -6/16, 5/16, 6/16, 6/16, 8/16 }
	},
	node_box = {
		type = "fixed",
		fixed = {
			{ -6/16, -6/16, 6/16, 6/16, 6/16, 8/16 },	-- the thin plate behind the button
			{ -4/16, -2/16, 4/16, 4/16, 2/16, 6/16 }	-- the button itself
		}
	},
	groups = { dig_immediate = 2, digiline_receiver = 1 },
	_digistuff_channelcopier_fieldname = "channel",
	sounds = default and default.node_sound_stone_defaults(),

	digiline =
	{
		receptor = {},
		wire = {
			rules = digistuff.button_get_rules,
		},
	},

	on_construct = on_contruct,
	after_place_node = digistuff.place_receiver,
	after_destruct = digistuff.remove_receiver,
	on_receive_fields = on_receive_fields,
})



minetest.register_node ("lwcomponents:player_button_off", {
	description = "Player Button",
	drawtype = "nodebox",
	tiles = {
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button.png"
	},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "facedir",
	legacy_wallmounted = true,
	walkable = false,
	sunlight_propagates = true,
	drop = "lwcomponents:player_button",
	selection_box = {
	type = "fixed",
		fixed = { -6/16, -6/16, 5/16, 6/16, 6/16, 8/16 }
	},
	node_box = {
		type = "fixed",
		fixed = {
			{ -6/16, -6/16, 6/16, 6/16, 6/16, 8/16 },	-- the thin plate behind the button
			{ -4/16, -2/16, 4/16, 4/16, 2/16, 6/16 }	-- the button itself
		}
	},
	groups = { dig_immediate = 2, digiline_receiver = 1, not_in_creative_inventory = 1 },
	_digistuff_channelcopier_fieldname = "channel",
	sounds = default and default.node_sound_stone_defaults(),

	digiline =
	{
		receptor = {},
		wire = {
			rules = digistuff.button_get_rules,
		},
		effector = {
			action = digistuff.button_handle_digilines,
		},
	},

	after_destruct = digistuff.remove_receiver,
	on_rightclick = player_button_push,
})



minetest.register_node ("lwcomponents:player_button_on", {
	description = "Player Button",
	drawtype = "nodebox",
	tiles = {
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_side.png",
	"lwplayer_button_on.png"
	},
	use_texture_alpha = "clip",
	paramtype = "light",
	paramtype2 = "facedir",
	legacy_wallmounted = true,
	walkable = false,
	sunlight_propagates = true,
	light_source = 7,
	drop = "lwcomponents:player_button",
	selection_box = {
		type = "fixed",
		fixed = { -6/16, -6/16, 5/16, 6/16, 6/16, 8/16 }
	},
	node_box = {
		type = "fixed",
		fixed = {
			{ -6/16, -6/16,  6/16, 6/16, 6/16, 8/16 },
			{ -4/16, -2/16, 11/32, 4/16, 2/16, 6/16 }
		}
	},
	groups = { dig_immediate = 2, digiline_receiver = 1, not_in_creative_inventory = 1 },
	_digistuff_channelcopier_fieldname = "channel",
	sounds = default and default.node_sound_stone_defaults(),

	digiline =
	{
		receptor = {},
		wire = {
			rules = digistuff.button_get_rules,
		},
	},

	after_destruct = digistuff.remove_receiver,
--	on_rightclick = player_button_push,
	on_timer = player_button_turnoff,
})



end -- utils.digilines_supported and utils.digistuff_supported
