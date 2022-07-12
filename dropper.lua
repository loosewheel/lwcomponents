local utils = ...
local S = utils.S



if utils.digilines_supported or utils.mesecon_supported then



local function drop_pos (pos, node)
	if node.param2 == 0 then
		return { x = pos.x, y = pos.y, z = pos.z - 1 }
	elseif node.param2 == 1 then
		return { x = pos.x - 1, y = pos.y, z = pos.z }
	elseif node.param2 == 2 then
		return { x = pos.x, y = pos.y, z = pos.z + 1 }
	elseif node.param2 == 3 then
		return { x = pos.x + 1, y = pos.y, z = pos.z }
	else
		return { x = pos.x, y = pos.y, z = pos.z }
	end
end



local function send_drop_message (pos, slot, name, qty)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)

		if meta then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "drop",
															name = name,
															slot = slot,
															qty = qty })
			end
		end
	end
end



-- slot:
--    nil or "nil"- next item, no drop if empty, max qty or less of first found item
--    number - qty items from slot, no drop if empty, max qty or less
--    string - name of item to drop, no drop if none, max qty or less
local function drop_item (pos, node, slot, qty)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			local item

			if qty then
				qty = tonumber (qty)
			end

			if not qty then
				qty = tonumber (meta:get_string ("quantity")) or 1
			end

			qty = math.max (qty, 1)

			if not slot or (type (slot) == "string" and slot == "nil") then
				local slots = inv:get_size ("main")

				for i = 1, slots do
					local stack = inv:get_stack ("main", i)

					if not stack:is_empty () and stack:get_count () > 0 then
						item = stack:get_name ()
						break
					end
				end

				slot = nil

			elseif type (slot) == "string" then
				item = slot
				slot = nil

			else
				slot = tonumber (slot)
			end

			if slot then
				local stack = inv:get_stack ("main", slot)

				if not stack:is_empty () and stack:get_count () > 0 then
					item = stack:get_name ()
					local drop

					if stack:get_count () >= qty then
						drop = qty
						stack:set_count (stack:get_count () - qty)
						inv:set_stack ("main", slot, stack)
					else
						drop = stack:get_count ()
						inv:set_stack ("main", slot, nil)
					end

					if drop > 0 then
						utils.item_drop (ItemStack (item.." "..drop), nil, drop_pos (pos, node))

						send_drop_message (pos, slot, item, drop)

						return true, slot, item
					end
				end

			elseif item then
				local slots = inv:get_size ("main")
				local drop = 0

				for i = 1, slots do
					local stack = inv:get_stack ("main", i)

					if not stack:is_empty () and stack:get_count () > 0 then
						if item == stack:get_name () then
							local remain = qty - drop

							slot = (slot and -1) or i

							if stack:get_count () > remain then
								stack:set_count (stack:get_count () - remain)
								drop = qty
								inv:set_stack ("main", i, stack)
							else
								drop = drop + stack:get_count ()
								inv:set_stack ("main", i, nil)
							end
						end
					end

					if drop == qty then
						break
					end
				end

				if drop > 0 then
					utils.item_drop (ItemStack (item.." "..drop), nil, drop_pos (pos, node))

					send_drop_message (pos, slot, item, drop)

					return true, slot, item
				end
			end
		end
	end

	return false
end



local function get_formspec ()
	return
	"formspec_version[3]\n"..
	"size[11.75,13.75;true]\n"..
	"field[1.0,1.0;4.0,0.8;channel;Channel;${channel}]"..
	"button[5.5,1.0;2.0,0.8;setchannel;Set]"..
	"list[context;main;1.0,2.5;4,4;]"..
	"list[current_player;main;1.0,8.0;8,4;]"..
	"listring[]"..
	"field[6.5,2.9;2.75,0.8;quantity;Qty;${quantity}]"..
	"button[9.25,2.9;1.5,0.8;setquantity;Set]"
end



local function after_place_base (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)

	meta:set_string ("inventory", "{ main = { } }")
	meta:set_string ("quantity", "1")
	meta:set_string ("formspec", get_formspec ())

	local inv = meta:get_inventory ()

	inv:set_size ("main", 16)
	inv:set_width ("main", 4)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	after_place_base (pos, placer, itemstack, pointed_thing)
	utils.pipeworks_after_place (pos)

	-- If return true no item is taken from itemstack
	return false
end



local function after_place_node_locked (pos, placer, itemstack, pointed_thing)
	after_place_base (pos, placer, itemstack, pointed_thing)

	if placer and placer:is_player () then
		local meta = minetest.get_meta (pos)

		meta:set_string ("owner", placer:get_player_name ())
		meta:set_string ("infotext", "Dropper (owned by "..placer:get_player_name ()..")")
	end

	utils.pipeworks_after_place (pos)

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

	if fields.setquantity then
		local meta = minetest.get_meta (pos)

		if meta then
			local qty = math.max (tonumber (fields.quantity or 1) or 1, 1)
			meta:set_string ("quantity", tostring (qty))
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
			if not inv:is_empty ("main") then
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
			end

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
	else
		local meta = minetest.get_meta (pos)

		if meta then
			if meta:get_string ("quantity") == "" then
				meta:set_string ("quantity", "1")
				meta:set_string ("formspec", get_formspec ())
			end
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

							if m[1] == "drop" then
								if m[2] and tonumber (m[2]) then
									m[2] = tonumber (m[2])
								end

								if m[3] and tonumber (m[3]) then
									m[3] = tonumber (m[3])
								else
									m[3] = nil
								end

								drop_item (pos, node, m[2], m[3])
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
					drop_item (pos, node)
				end
			}
		}
	end

	return nil
end



local function pipeworks_support ()
	if utils.pipeworks_supported then
		return
		{
			priority = 100,
			input_inventory = "main",
			connect_sides = { left = 1, right = 1, back = 1, bottom = 1, top = 1 },

			insert_object = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:add_item ("main", stack)
				end

				return stack
			end,

			can_insert = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:room_for_item ("main", stack)
				end

				return false
			end,

			can_remove = function (pos, node, stack, dir)
				-- returns the maximum number of items of that stack that can be removed
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					local slots = inv:get_size ("main")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("main", i)

						if s and not s:is_empty () and utils.is_same_item (stack, s) then
							return s:get_count ()
						end
					end
				end

				return 0
			end,

			remove_items = function (pos, node, stack, dir, count)
				-- removes count items and returns them
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil
				local left = count

				if inv then
					local slots = inv:get_size ("main")

					for i = 1, slots, 1 do
						local s = inv:get_stack ("main", i)

						if s and not s:is_empty () and utils.is_same_item (s, stack) then
							if s:get_count () > left then
								s:set_count (s:get_count () - left)
								inv:set_stack ("main", i, s)
								left = 0
							else
								left = left - s:get_count ()
								inv:set_stack ("main", i, nil)
							end
						end

						if left == 0 then
							break
						end
					end
				end

				local result = ItemStack (stack)
				result:set_count (count - left)

				return result
			end
		}
	end

	return nil
end



local dropper_groups = { cracky = 3, wires_connect = 1 }
if utils.pipeworks_supported then
	dropper_groups.tubedevice = 1
	dropper_groups.tubedevice_receiver = 1
end



minetest.register_node("lwcomponents:dropper", {
	description = S("Dropper"),
	tiles = { "lwdropper.png", "lwdropper.png", "lwdropper.png",
				 "lwdropper.png", "lwdropper.png", "lwdropper_face.png"},
	is_ground_content = false,
	groups = table.copy (dropper_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node,
	can_dig = can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



minetest.register_node("lwcomponents:dropper_locked", {
	description = S("Dropper (locked)"),
	tiles = { "lwdropper.png", "lwdropper.png", "lwdropper.png",
				 "lwdropper.png", "lwdropper.png", "lwdropper_face.png"},
	is_ground_content = false,
	groups = table.copy (dropper_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 1,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node_locked,
	can_dig = can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	on_blast = on_blast,
	on_rightclick = on_rightclick
})



utils.hopper_add_container({
	{"top", "lwcomponents:dropper", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:dropper", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:dropper", "main"}, -- insert items from hopper at side
})



utils.hopper_add_container({
	{"top", "lwcomponents:dropper_locked", "main"}, -- take items from above into hopper below
	{"bottom", "lwcomponents:dropper_locked", "main"}, -- insert items below from hopper above
	{"side", "lwcomponents:dropper_locked", "main"}, -- insert items from hopper at side
})


end -- utils.digilines_supported or utils.mesecon_supported



--
