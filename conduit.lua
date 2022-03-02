local utils, mod_storage = ...
local S = utils.S



local transfer_rate = 0.1
local conduit_interval = 1.0
local conduit_connections = utils.connections:new (mod_storage, "conduit_connections")


-- forward declare
local run_initialize = nil



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



local function get_target_for_item (meta, inv, stack)
	if meta then
		if inv then
			local slots = inv:get_size ("filter")

			for slot = 1, slots, 1 do
				local s = inv:get_stack ("filter", slot)

				if s and not s:is_empty () and utils.is_same_item (s, stack) then
					local target = meta:get_string ("target"..slot)

					if target ~= "" then
						return target
					end
				end
			end
		end

		if meta:get_string ("target") ~= "" then
			return meta:get_string ("target")
		end
	end

	return nil
end



local function deliver_slot (pos, slot)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()
		local transfer_data = minetest.deserialize (meta:get_string ("transfer_data"))

		if inv then
			local item = inv:get_stack ("transfer", slot)

			if transfer_data[slot] and item and not item:is_empty () then
				local tnode = utils.get_far_node (transfer_data[slot].pos)

				if tnode and (tnode.name == "lwcomponents:conduit" or
								  tnode.name == "lwcomponents:conduit_locked") then
					local tmeta = minetest.get_meta (transfer_data[slot].pos)

					if tmeta then
						local tinv = tmeta:get_inventory ()

						if tinv then
							tinv:add_item ("main", item)
						end
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



local function deliver_earliest (pos)
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
		deliver_earliest (pos)
		slot = get_transfer_free_slot (pos)
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

			inv:set_stack ("transfer", slot, item)

			meta:set_string ("transfer_data", minetest.serialize (transfer_data))

			run_initialize (pos)
		end
	end
end



local function send_to_target (pos, target, slot)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			if not slot then
				local slots = inv:get_size ("main")

				for i = 1, slots do
					local stack = inv:get_stack ("main", i)

					if not stack:is_empty () and stack:get_count () > 0 then
						if target or get_target_for_item (meta, inv, stack) then
							slot = i
							break
						end
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

				if stack and not stack:is_empty () then
					local name = stack:get_name ()
					local item = ItemStack (stack)

					target = (target and tostring (target)) or
								get_target_for_item (meta, inv, stack)

					if item and target then
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



local function get_formspec (pos)
	local meta = minetest.get_meta (pos)
	local automatic = "false"
	local filters = ""

	if meta then
		automatic = meta:get_string ("automatic")
	end

	for i = 1, 8, 1 do
		filters = string.format ("%sfield[12.7,%0.2f;3.0,0.8;target%d;;${target%d}]"..
										 "button[15.9,%0.2f;1.5,0.8;settarget%d;Set]",
										 filters,
										 (i * 1.25) + 0.35,
										 i,
										 i,
										 (i * 1.25) + 0.35,
										 i)
	end

	return
		"formspec_version[3]"..
		"size[18.4,12.25;true]"..
		"field[1.0,1.5;3.0,0.8;channel;Channel;${channel}]"..
		"button[4.2,1.5;1.5,0.8;setchannel;Set]"..
		"field[1.0,3.0;3.0,0.8;target;Target;${target}]"..
		"button[4.2,3.0;1.5,0.8;settarget;Set]"..
		"checkbox[1.0,4.5;automatic;Automatic;"..automatic.."]"..
		"list[context;main;6.0,1.0;4,4;]"..
		"list[current_player;main;1.0,6.5;8,4;]"..
		"listring[]"..
		"label[11.5,1.25;Filter]"..
		"list[context;filter;11.5,1.5;1,8;]"..
		filters
end



local function run_conduit (pos, id)
	local node = utils.get_far_node (pos)

	if node then
		if node.name == "lwcomponents:conduit" or
				node.name == "lwcomponents:conduit_locked" then
			local meta = minetest.get_meta (pos)

			if meta and id == meta:get_int ("conduit_id") then
				local automatic = meta:get_string ("automatic") == "true"

				if automatic then
					send_to_target (pos)
				end

				if run_deliveries (pos) or automatic then
					minetest.after (conduit_interval, run_conduit, pos, id)
				else
					meta:set_int ("run_active", 0)
				end
			end
		else
			conduit_connections:remove_node (pos)
		end
	end
end



run_initialize = function (pos)
	local meta = minetest.get_meta (pos)

	if meta then
		if meta:get_int ("run_active") == 0 then
			meta:set_int ("run_active", 1)
			minetest.after (conduit_interval, run_conduit, pos, meta:get_int ("conduit_id"))
		end
	end
end



local function count_table_keys (t)
	local count = 0

	for k, v in pairs (t) do
		count = count + 1
	end

	return count
end



local function send_inventory_message (pos)
	if utils.digilines_supported then
		local meta = minetest.get_meta (pos)
		local inv = (meta and meta:get_inventory ()) or nil

		if meta and inv then
			local channel = meta:get_string ("channel")

			if channel:len () > 0 then
				local inventory = { }
				local slots = inv:get_size ("main")

				for slot = 1, slots, 1 do
					local stack = inv:get_stack ("main", slot)

					if stack and not stack:is_empty () then
						local name = stack:get_name ()
						local description = nil
						local custom = false
						local pallet_index = nil
						local tstack = stack:to_table ()

						if tstack and tstack.meta and count_table_keys (tstack.meta) > 0 then
							custom = true

							pallet_index = tstack.meta.palette_index
						end

						if stack:get_short_description () ~= "" then
							description = stack:get_short_description ()
						elseif stack:get_description () ~= "" then
							description = stack:get_description ()
						else
							description = name

							local def = utils.find_item_def (name)

							if def then
								if def.short_description then
									description = def.short_description
								elseif def.description then
									description = def.description
								end
							end
						end

						inventory[slot] =
						{
							name = stack:get_name (),
							description = utils.unescape_description (description),
							count = stack:get_count (),
							custom = custom,
							pallet_index = pallet_index,
						}
					else
						inventory[slot] =
						{
							name = "",
							description = "",
							count = 0,
							custom = false,
							pallet_index = nil,
						}
					end
				end

				utils.digilines_receptor_send (pos,
														 utils.digilines_default_rules,
														 channel,
														 { action = "inventory",
															inventory = inventory })
			end
		end
	end

end



local function on_construct (pos)
	conduit_connections:add_node (pos)
end



local function on_destruct (pos)
	deliver_all (pos)
	conduit_connections:remove_node (pos)
end



local function after_place_base (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)
	local spec =
	"formspec_version[3]"..
	"size[7.0,3.8]"..
	"field[0.5,1.0;6.0,0.8;channel;Channel;${channel}]"..
	"button[2.0,2.3;3.0,0.8;setchannel;Set]"

	meta:set_string ("inventory", "{ main = { }, transfer = { }, filter = { } }")
	meta:set_string ("formspec", spec)
	meta:set_string ("transfer_data", minetest.serialize({ }))
	meta:set_string ("automatic", "false")
	meta:set_int ("conduit_id", math.random (1000000))

	local inv = meta:get_inventory ()

	inv:set_size ("main", 16)
	inv:set_width ("main", 4)

	inv:set_size ("transfer", 32)
	inv:set_width ("transfer", 8)

	inv:set_size ("filter", 8)
	inv:set_width ("filter", 1)
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
		meta:set_string ("infotext", "Conduit (owned by "..placer:get_player_name ()..")")
	end

	utils.pipeworks_after_place (pos)

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

			if fields.automatic == "true" then
				meta:set_int ("run_active", 0)
			end

			run_initialize (pos)
		end
	end

	for i = 1, 8, 1 do
		if fields[string.format ("settarget%d", i)] then
			local meta = minetest.get_meta (pos)

			if meta then
				local name = string.format ("target%d", i)

				meta:set_string (name, fields[name])
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



local function allow_metadata_inventory_put (pos, listname, index, stack, player)
	if listname == "filter" then
		local meta = minetest.get_meta (pos)

		if meta then
			local inv = meta:get_inventory ()

			if inv then
				inv:set_stack ("filter", index, ItemStack (stack:get_name ()))
			end
		end

		return 0
	end

	return stack:get_stack_max ()
end



local function allow_metadata_inventory_take (pos, listname, index, stack, player)
	if listname == "filter" then
		local meta = minetest.get_meta (pos)

		if meta then
			local inv = meta:get_inventory ()

			if inv then
				inv:set_stack ("filter", index, nil)
			end
		end

		return 0
	end

	return stack:get_stack_max ()
end



local function allow_metadata_inventory_move (pos, from_list, from_index,
															 to_list, to_index, count, player)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			if from_list == "filter" then
				if to_list == "filter" then
					return 1
				end

				inv:set_stack ("filter", from_index, nil)

				return 0

			elseif to_list == "filter" then
				local stack = inv:get_stack (from_list, from_index)

				if stack and not stack:is_empty () then
					inv:set_stack ("filter", to_index, ItemStack (stack:get_name ()))
				end

				return 0

			else
				local stack = inv:get_stack (from_list, from_index)

				if stack and not stack:is_empty () then
					return stack:get_stack_max ()
				end
			end
		end
	end

	return utils.settings.default_stack_max
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

								elseif m[1] == "inventory" then
									send_inventory_message (pos)

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



local function pipeworks_support ()
	if utils.pipeworks_supported then
		return
		{
			priority = 100,
			input_inventory = "main",
			connect_sides = { left = 1, right = 1, front = 1, back = 1, bottom = 1, top = 1 },

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



local conduit_groups = { cracky = 3 }
if utils.pipeworks_supported then
	conduit_groups.tubedevice = 1
	conduit_groups.tubedevice_receiver = 1
end



minetest.register_node("lwcomponents:conduit", {
	description = S("Conduit"),
	tiles = { "lwconduit.png" },
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = 				{ -0.375, -0.375, -0.375, 0.375, 0.375, 0.375 }, -- body
		connect_top = 		{ -0.3125, 0.3125, -0.3125, 0.3125, 0.5, 0.3125 }, -- top
		connect_bottom =	{-0.3125, -0.5, -0.3125, 0.3125, -0.3125, 0.3125}, -- down
		connect_front = 	{ -0.3125, -0.3125, -0.5, 0.3125, 0.3125, -0.3125 }, -- front
		connect_back =  	{ -0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125 }, -- back
		connect_left =  	{ -0.5, -0.3125, -0.3125, -0.3125, 0.3125, 0.3125 }, -- left
		connect_right = 	{ 0.3125, -0.3125, -0.3125, 0.5, 0.3125, 0.3125 }, -- right
	},
	connect_sides = { "top", "bottom", "front", "back", "left", "right" },
	connects_to = { "lwcomponents:conduit", "lwcomponents:conduit_locked",
						 "lwcomponents:hopper", "lwcomponents:hopper_horz",
						 "hopper:hopper", "hopper:hopper_side",
						 "group:tube", "pipeworks:filter", "pipeworks:mese_filter",
						 "pipeworks:digiline_filter" },
	selection_box = {
		type = "connected",
		fixed = 				{ -0.375, -0.375, -0.375, 0.375, 0.375, 0.375 }, -- body
		connect_top = 		{ -0.3125, 0.3125, -0.3125, 0.3125, 0.5, 0.3125 }, -- top
		connect_bottom =	{-0.3125, -0.5, -0.3125, 0.3125, -0.3125, 0.3125}, -- down
		connect_front = 	{ -0.3125, -0.3125, -0.5, 0.3125, 0.3125, -0.3125 }, -- front
		connect_back =  	{ -0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125 }, -- back
		connect_left =  	{ -0.5, -0.3125, -0.3125, -0.3125, 0.3125, 0.3125 }, -- left
		connect_right = 	{ 0.3125, -0.3125, -0.3125, 0.5, 0.3125, 0.3125 }, -- right
	},
	collision_box = {
		type = "connected",
		fixed = 				{ -0.375, -0.375, -0.375, 0.375, 0.375, 0.375 }, -- body
		connect_top = 		{ -0.3125, 0.3125, -0.3125, 0.3125, 0.5, 0.3125 }, -- top
		connect_bottom =	{-0.3125, -0.5, -0.3125, 0.3125, -0.3125, 0.3125}, -- down
		connect_front = 	{ -0.3125, -0.3125, -0.5, 0.3125, 0.3125, -0.3125 }, -- front
		connect_back =  	{ -0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125 }, -- back
		connect_left =  	{ -0.5, -0.3125, -0.3125, -0.3125, 0.3125, 0.3125 }, -- left
		connect_right = 	{ 0.3125, -0.3125, -0.3125, 0.5, 0.3125, 0.3125 }, -- right
	},
	is_ground_content = false,
	groups = table.copy (conduit_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_construct = on_construct,
	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node,
	can_dig = can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	allow_metadata_inventory_move = allow_metadata_inventory_move

})



minetest.register_node("lwcomponents:conduit_locked", {
	description = S("Conduit (locked)"),
	tiles = { "lwconduit.png" },
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed = 				{ -0.375, -0.375, -0.375, 0.375, 0.375, 0.375 }, -- body
		connect_top = 		{ -0.3125, 0.3125, -0.3125, 0.3125, 0.5, 0.3125 }, -- top
		connect_bottom =	{-0.3125, -0.5, -0.3125, 0.3125, -0.3125, 0.3125}, -- down
		connect_front = 	{ -0.3125, -0.3125, -0.5, 0.3125, 0.3125, -0.3125 }, -- front
		connect_back =  	{ -0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125 }, -- back
		connect_left =  	{ -0.5, -0.3125, -0.3125, -0.3125, 0.3125, 0.3125 }, -- left
		connect_right = 	{ 0.3125, -0.3125, -0.3125, 0.5, 0.3125, 0.3125 }, -- right
	},
	connect_sides = { "top", "bottom", "front", "back", "left", "right" },
	connects_to = { "lwcomponents:conduit", "lwcomponents:conduit_locked",
						 "lwcomponents:hopper", "lwcomponents:hopper_horz",
						 "hopper:hopper", "hopper:hopper_side",
						 "group:tube", "pipeworks:filter", "pipeworks:mese_filter",
						 "pipeworks:digiline_filter" },
	selection_box = {
		type = "connected",
		fixed = 				{ -0.375, -0.375, -0.375, 0.375, 0.375, 0.375 }, -- body
		connect_top = 		{ -0.3125, 0.3125, -0.3125, 0.3125, 0.5, 0.3125 }, -- top
		connect_bottom =	{-0.3125, -0.5, -0.3125, 0.3125, -0.3125, 0.3125}, -- down
		connect_front = 	{ -0.3125, -0.3125, -0.5, 0.3125, 0.3125, -0.3125 }, -- front
		connect_back =  	{ -0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125 }, -- back
		connect_left =  	{ -0.5, -0.3125, -0.3125, -0.3125, 0.3125, 0.3125 }, -- left
		connect_right = 	{ 0.3125, -0.3125, -0.3125, 0.5, 0.3125, 0.3125 }, -- right
	},
	collision_box = {
		type = "connected",
		fixed = 				{ -0.375, -0.375, -0.375, 0.375, 0.375, 0.375 }, -- body
		connect_top = 		{ -0.3125, 0.3125, -0.3125, 0.3125, 0.5, 0.3125 }, -- top
		connect_bottom =	{-0.3125, -0.5, -0.3125, 0.3125, -0.3125, 0.3125}, -- down
		connect_front = 	{ -0.3125, -0.3125, -0.5, 0.3125, 0.3125, -0.3125 }, -- front
		connect_back =  	{ -0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125 }, -- back
		connect_left =  	{ -0.5, -0.3125, -0.3125, -0.3125, 0.3125, 0.3125 }, -- left
		connect_right = 	{ 0.3125, -0.3125, -0.3125, 0.5, 0.3125, 0.3125 }, -- right
	},
	is_ground_content = false,
	groups = table.copy (conduit_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "light",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,
	_digistuff_channelcopier_fieldname = "channel",

	mesecons = mesecon_support (),
	digiline = digilines_support (),
	tube = pipeworks_support (),

	on_construct = on_construct,
	on_destruct = on_destruct,
	on_receive_fields = on_receive_fields,
	after_place_node = after_place_node_locked,
	can_dig = can_dig,
	after_dig_node = utils.pipeworks_after_dig,
	on_blast = on_blast,
	on_rightclick = on_rightclick,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	allow_metadata_inventory_move = allow_metadata_inventory_move
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



-- legacy code v0.1.23 (24-2-22)
local function convert_conduits ()
	local list = conduit_connections:get_full_list ()

	for _, data in ipairs (list) do
		local node = utils.get_far_node (data.pos)

		if node and (node.name == "lwcomponents:conduit" or
						 node.name == "lwcomponents:conduit_locked") then
			local meta = minetest.get_meta (data.pos)

			if meta then
				if meta:get_int ("conduit_id") == 0 then
					meta:set_int ("conduit_id", math.random (1000000))

					if meta:get_string ("automatic") == "true" then
						meta:set_int ("run_active", 1)
					else
						local inv = meta:get_inventory ()

						if inv and not inv:is_empty ("transfer") then
							meta:set_int ("run_active", 1)
						end
					end
				end

				-- added v0.1.25 (2-3-22)
				local tmeta = meta:to_table ()

				if tmeta and tmeta.inventory then
					if not tmeta.inventory.filter then
						tmeta.inventory.filter =
						{
							[1] = "", [2] = "", [3] = "", [4] = "",
							[5] = "", [6] = "", [7] = "", [8] = ""
						}

						meta:from_table (tmeta)

						if meta:get_string ("channel") ~= "" then
							meta:set_string ("formspec", get_formspec (data.pos))
						end
					end
				end
			end
		end
	end
end



local function restart_conduits ()
	convert_conduits ()

	local list = conduit_connections:get_id_list ()

	for _, data in ipairs (list) do
		local meta = minetest.get_meta (data.pos)

		if meta and meta:get_int ("run_active") ~= 0 then
			minetest.after (conduit_interval + (math.random (10) / 10),
								 run_conduit, data.pos, meta:get_int ("conduit_id"))
		end
	end

end



minetest.register_on_mods_loaded (function ()
	minetest.after (3.0, restart_conduits)
end)



--
