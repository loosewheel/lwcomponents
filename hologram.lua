local utils = ...
local S = utils.S



if utils.digilines_supported then



local hologram_block =
{
	black = {
		node = "lwcomponents:hologram_black",
		image = "lwhologram_black.png",
		color = { a = 128, r = 0, g = 0, b = 0 } },
	orange = {
		node = "lwcomponents:hologram_orange",
		image = "lwhologram_orange.png",
		color = { a = 128, r = 255, g = 128, b = 0 } },
	magenta = {
		node = "lwcomponents:hologram_magenta",
		image = "lwhologram_magenta.png",
		color = { a = 128, r = 255, g = 0, b = 255 } },
	sky = {
		node = "lwcomponents:hologram_sky",
		image = "lwhologram_sky.png",
		color = { a = 128, r = 0, g = 128, b = 255 } },
	yellow = {
		node = "lwcomponents:hologram_yellow",
		image = "lwhologram_yellow.png",
		color = { a = 128, r = 255, g = 255, b = 0 } },
	pink = {
		node = "lwcomponents:hologram_pink",
		image = "lwhologram_pink.png",
		color = { a = 128, r = 255, g = 128, b = 128 } },
	cyan = {
		node = "lwcomponents:hologram_cyan",
		image = "lwhologram_cyan.png",
		color = { a = 128, r = 0, g = 255, b = 255 } },
	gray = {
		node = "lwcomponents:hologram_gray",
		image = "lwhologram_gray.png",
		color = { a = 128, r = 128, g = 128, b = 128 } },
	silver = {
		node = "lwcomponents:hologram_silver",
		image = "lwhologram_silver.png",
		color = { a = 128, r = 192, g = 192, b = 192 } },
	red = {
		node = "lwcomponents:hologram_red",
		image = "lwhologram_red.png",
		color = { a = 128, r = 255, g = 0, b = 0 } },
	green = {
		node = "lwcomponents:hologram_green",
		image = "lwhologram_green.png",
		color = { a = 128, r = 0, g = 128, b = 0 } },
	blue = {
		node = "lwcomponents:hologram_blue",
		image = "lwhologram_blue.png",
		color = { a = 128, r = 0, g = 0, b = 255 } },
	brown = {
		node = "lwcomponents:hologram_brown",
		image = "lwhologram_brown.png",
		color = { a = 128, r = 128, g = 64, b = 0 } },
	lime = {
		node = "lwcomponents:hologram_lime",
		image = "lwhologram_lime.png",
		color = { a = 128, r = 0, g = 255, b = 0 } },
	purple = {
		node = "lwcomponents:hologram_purple",
		image = "lwhologram_purple.png",
		color = { a = 128, r = 128, g = 0, b = 128 } },
	white = {
		node = "lwcomponents:hologram_white",
		image = "lwhologram_white.png",
		color = { a = 128, r = 255, g = 255, b = 255 } },
}



local function rotate_to_dir (center, param2, point)
	local base = vector.subtract (point, center)

	if param2 == 1 then
		base = vector.rotate (base, { x = 0, y = (math.pi * 1.5), z = 0 })
	elseif param2 == 2 then
		base = vector.rotate (base, { x = 0, y = math.pi, z = 0 })
	elseif param2 == 3 then
		base = vector.rotate (base, { x = 0, y = (math.pi * 0.5), z = 0 })
	end

	return vector.add (base, center)
end



local function draw_map (pos, map)
	local meta = minetest.get_meta (pos)
	local holonode = minetest.get_node (pos)

	if meta and holonode and type (map) == "table" then
		local id = meta:get_int ("block_id")

		for y = 1, 15 do
			local layer = (type (map[y]) == "table" and map[y]) or { }

			for x = 1, 15 do
				local line = (type (layer[x]) == "table" and layer[x]) or { }

				for z = 1, 15 do
					local map_point = { x = z + pos.x - 8, y = y + pos.y + 1, z = (16 - x) + pos.z - 8 }
					local holopos = rotate_to_dir (pos, holonode.param2, map_point)

					local node = utils.get_far_node (holopos)
					local draw = false

					if node and node.name ~= "air" then
						if node.name:sub (1, 22) == "lwcomponents:hologram_" then
							local nodemeta = minetest.get_meta (holopos)

							if nodemeta and nodemeta:get_int ("block_id") == id then
								draw = true
							end
						end
					else
						draw = true
					end

					if draw then
						local holonode = hologram_block[line[z]]

						if node then
							utils.destroy_node (holopos)
						end

						if holonode then
							minetest.set_node (holopos, { name = holonode.node })

							local nodemeta = minetest.get_meta (holopos)

							if nodemeta then
								nodemeta:set_int ("block_id", id)
							end
						end
					end
				end
			end
		end
	end
end



local function clear_map (pos)
	draw_map (pos, { })
end



local function on_destruct (pos)
	clear_map (pos)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"size[7.5,3]"..
	"field[1,1;6,2;channel;Channel;${channel}]"..
	"button_exit[2.5,2;3,1;submit;Set]"
	local id = math.random (1000000)

	meta:set_string ("formspec", spec)
	meta:set_int ("block_id", id)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_node (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Hologram (owned by "..placer:get_player_name ()..")")
	end

	-- If return true no item is taken from itemstack
	return false
end



local function on_receive_fields (pos, formname, fields, sender)
	if not utils.can_interact_with_node (pos, sender) then
		return
	end

	local meta = minetest.get_meta(pos)

	if fields.submit then
		meta:set_string ("channel", fields.channel)
	end
end



local function on_blast (pos, intensity)
	local meta = minetest.get_meta (pos)

	if meta then
		if intensity >= 1.0 then

			clear_map (pos)

			minetest.remove_node (pos)

		else -- intensity < 1.0

			clear_map (pos)

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



local function can_dig (pos, player)
	if not utils.can_interact_with_node (pos, player) then
		return false
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

								if m[1] == "clear" then
									clear_map (pos)
								end

							elseif type (msg) == "table" then
								draw_map (pos, msg)

							end
						end
					end
				end,
			}
		}
	end

	return nil
end



minetest.register_node("lwcomponents:hologram", {
	description = S("Hologram"),
	tiles = { "lwhologram.png", "lwhologram.png", "lwhologram.png",
				 "lwhologram.png", "lwhologram.png", "lwhologram_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_destruct = on_destruct,
	after_place_node = after_place_node,
	on_receive_fields = on_receive_fields,
	on_blast = on_blast,
	can_dig = can_dig,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:hologram_locked", {
	description = S("Hologram (locked)"),
	tiles = { "lwhologram.png", "lwhologram.png", "lwhologram.png",
				 "lwhologram.png", "lwhologram.png", "lwhologram_face.png"},
	is_ground_content = false,
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	digiline = digilines_support (),

	on_destruct = on_destruct,
	after_place_node = after_place_node_locked,
	on_receive_fields = on_receive_fields,
	on_blast = on_blast,
	can_dig = can_dig,
	on_rightclick = on_rightclick
})



local function register_hologram_block (block)
	local bc = hologram_block[block]

	minetest.register_node(bc.node, {
		description = S("Hologram "..block),
		tiles = { bc.image },
		drawtype = "glasslike",
		light_source = 7,
		use_texture_alpha = "blend",
		sunlight_propagates = true,
		walkable = false,
		pointable = false,
		diggable = false,
		climbable = false,
		buildable_to = true,
		floodable = true,
		is_ground_content = false,
		groups = { not_in_creative_inventory = 1 },
		paramtype = "light",
		param1 = 255,
		post_effect_color = bc.color,
	})
end



register_hologram_block ("black")
register_hologram_block ("orange")
register_hologram_block ("magenta")
register_hologram_block ("sky")
register_hologram_block ("yellow")
register_hologram_block ("pink")
register_hologram_block ("cyan")
register_hologram_block ("gray")
register_hologram_block ("silver")
register_hologram_block ("red")
register_hologram_block ("green")
register_hologram_block ("blue")
register_hologram_block ("brown")
register_hologram_block ("lime")
register_hologram_block ("purple")
register_hologram_block ("white")



end -- utils.digilines_supported
