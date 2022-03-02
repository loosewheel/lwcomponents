local utils, mod_storage = ...
local S = utils.S



if utils.hopper_supported then



local hopper_interval = 1.0



local hopper_list = minetest.deserialize (mod_storage:get_string ("hopper_list"))
if type (hopper_list) ~= "table" then
	hopper_list = {}
end



local function add_hopper_to_list (pos)
	hopper_list[minetest.pos_to_string (pos, 0)] = true

	mod_storage:set_string ("hopper_list", minetest.serialize (hopper_list))
end



local function remove_hopper_from_list (pos)
	hopper_list[minetest.pos_to_string (pos, 0)] = nil

	mod_storage:set_string ("hopper_list", minetest.serialize (hopper_list))
end



local input_dir =
{
	[0] = { x = 0, y = 1, z = 0 },
	{ x = 0, y = 0, z = 1 },
	{ x = 0, y = 0, z = -1 },
	{ x = 1, y = 0, z = 0 },
	{ x = -1, y = 0, z = 0 },
	{ x = 0, y = -1, z = 0 }
}

local function get_input_dir (node)
	return input_dir[math.floor (node.param2 / 4)]
end



local function get_output_dir (node)
	if node then
		if node.name == "lwcomponents:hopper" then
			return vector.multiply (get_input_dir (node), -1)
		elseif node.name == "lwcomponents:hopper_horz" then
			return minetest.facedir_to_dir (node.param2)
		end
	end

	return nil
end



local function get_drop (pos)
	local objs = minetest.get_objects_inside_radius (pos, 1)

	for _, obj in pairs (objs) do
		local obj_pos = (obj.get_pos and obj:get_pos ())

		if obj_pos and utils.is_drop (obj) then
			obj_pos = vector.round (obj_pos)

			if vector.equals (pos, obj_pos) then
				local stack = ItemStack (obj:get_luaentity ().itemstring)

				if stack and not stack:is_empty () then
					stack:set_count (1)

					return stack, obj
				end
			end
		end
	end
end



local function take_drop (obj)
	if utils.is_drop (obj) then
		local stack = ItemStack (obj:get_luaentity ().itemstring)

		if stack and not stack:is_empty () then
			stack:set_count (stack:get_count () - 1)

			if stack:is_empty () then
				obj:get_luaentity().itemstring = ""
				obj:remove()
			else
				obj:get_luaentity().itemstring = stack:to_string ()
			end
		end
	end
end



local function next_item_to_take (src_pos, src_node, src_inv_name)
	if not src_inv_name or not minetest.registered_nodes[src_node.name] then
		return
	end

	local src_meta = minetest.get_meta (src_pos)
	local src_inv = (src_meta and src_meta:get_inventory ()) or nil

	if src_inv then
		local slots = src_inv:get_size (src_inv_name)

		for slot = 1, slots, 1 do
			local stack = src_inv:get_stack (src_inv_name, slot)

			if stack and not stack:is_empty () then
				stack:set_count (1)

				return stack, slot
			end
		end
	end
end



local function take_item (src_pos, src_inv_name, slot)
	local src_meta = minetest.get_meta (src_pos)
	local src_inv = (src_meta and src_meta:get_inventory ()) or nil

	if src_inv then
		local stack = src_inv:get_stack (src_inv_name, slot)

		if stack and not stack:is_empty () then
			stack:set_count (stack:get_count () - 1)

			src_inv:set_stack (src_inv_name, slot, stack)
		end
	end
end



local function place_item (dest_pos, dest_node, dest_inv_name, stack, placer)
	local dest_def = minetest.registered_nodes[dest_node.name]

	if not dest_inv_name or not dest_def then
		return
	end

	local dest_meta = minetest.get_meta (dest_pos)
	local dest_inv = (dest_meta and dest_meta:get_inventory ()) or nil

	if dest_inv then
		local slots = dest_inv:get_size (dest_inv_name)

		-- find existing stack
		for slot = 1, slots, 1 do
			local inv_stack = dest_inv:get_stack (dest_inv_name, slot)

			if inv_stack and not inv_stack:is_empty () and
				utils.is_same_item (inv_stack, stack) and
				inv_stack:get_count () < inv_stack:get_stack_max () and
				(dest_def.allow_metadata_inventory_put == nil or
				 placer == nil or
				 dest_def.allow_metadata_inventory_put(dest_pos, dest_inv_name, slot, stack, placer) > 0) then

				inv_stack:set_count (inv_stack:get_count () + 1)
				dest_inv:set_stack (dest_inv_name, slot, inv_stack)

				if dest_def.on_metadata_inventory_put and placer then
					dest_def.on_metadata_inventory_put (dest_pos, dest_inv_name, slot, stack, placer)
				end

				return true
			end
		end

		-- find empty slot
		for slot = 1, slots, 1 do
			local inv_stack = dest_inv:get_stack (dest_inv_name, slot)

			if not inv_stack or inv_stack:is_empty () and
				(dest_def.allow_metadata_inventory_put == nil or
				 placer == nil or
				 dest_def.allow_metadata_inventory_put(dest_pos, dest_inv_name, slot, stack, placer) > 0) then

				dest_inv:set_stack (dest_inv_name, slot, stack)

				if dest_def.on_metadata_inventory_put and placer then
					dest_def.on_metadata_inventory_put (dest_pos, dest_inv_name, slot, stack, placer)
				end

				return true
			end
		end
	end

	return false
end



local function run_hopper_action (pos)
	local node = utils.get_far_node (pos)
	local dest_dir = get_output_dir (node)

	if dest_dir then
		local dest_pos = vector.add (pos, dest_dir)
		local dest_node = utils.get_far_node (dest_pos)

		if dest_node then
			local registered_dest_invs = hopper.get_registered_inventories_for (dest_node.name)

			if registered_dest_invs then
				local meta = minetest.get_meta (pos)
				local placer_name = (meta and meta:get_string ("placer_name")) or nil
				local placer = (placer_name and minetest.get_player_by_name (placer_name)) or
									utils.get_dummy_player (true, placer_name or "<unknown>")
				local src_pos = vector.add (pos, get_input_dir (node))
				local drop = nil
				local stack = nil
				local slot = nil
				local src_inv_name = nil

				stack, drop = get_drop (src_pos)

				if not stack then
					local src_node = utils.get_far_node (src_pos)

					if src_node then
						local registered_src_invs = hopper.get_registered_inventories_for (src_node.name)

						if registered_src_invs then
							src_inv_name = registered_src_invs["top"]
							stack, slot = next_item_to_take (src_pos, src_node, src_inv_name)
						end
					end
				end

				if stack then
					local dest_side = (node.name == "lwcomponents:hopper" and "bottom") or "side"
					local dest_inv_name = registered_dest_invs[dest_side]

					if place_item (dest_pos, dest_node, dest_inv_name, stack, placer) then
						if drop then
							take_drop (drop)
						else
							take_item (src_pos, src_inv_name, slot)
						end
					end
				end
			end
		end
	end
end



local function on_construct (pos)
	add_hopper_to_list (pos)
end



local function on_destruct (pos)
	remove_hopper_from_list (pos)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)

	meta:set_string ("placer_name", (placer and placer:get_player_name ()) or "")

	-- If return true no item is taken from itemstack
	return false
end



local function on_place (itemstack, placer, pointed_thing)
	if pointed_thing and pointed_thing.type == "node" then
		local stack = ItemStack (itemstack)
		local dir = vector.direction (pointed_thing.above, pointed_thing.under)

		if dir.y == 0 then
			minetest.item_place (ItemStack ("lwcomponents:hopper_horz"), placer, pointed_thing)

			if not utils.is_creative (placer) then
				stack:set_count (stack:get_count () - 1)
			end

			return stack
		end
	end

	return minetest.item_place (itemstack, placer, pointed_thing)
end



minetest.register_node ("lwcomponents:hopper", {
   description = S("Hopper"),
   tiles = { "lwcomponents_hopper_top.png", "lwcomponents_hopper_vert_spout.png",
				 "lwcomponents_hopper_side.png", "lwcomponents_hopper_side.png",
				 "lwcomponents_hopper_side.png", "lwcomponents_hopper_side.png" },
   drawtype = "nodebox",
   node_box = {
      type = "fixed",
		fixed = {
			{-0.3125, -0.5, -0.3125, 0.3125, -0.25, 0.3125}, -- spout_vert
			{-0.375, -0.375, -0.375, 0.375, 0.3125, 0.375}, -- body
			{-0.5, 0, -0.5, -0.3125, 0.5, 0.5}, -- funnel_1
			{-0.5, 0, 0.3125, 0.5, 0.5, 0.5}, -- funnel_2
			{-0.5, 0, -0.5, 0.5, 0.5, -0.3125}, -- funnel_3
			{0.3125, 0, -0.5, 0.5, 0.5, 0.5}, -- funnel_4
		}
   },
   selection_box = {
      type = "fixed",
		fixed = {
			{-0.3125, -0.5, -0.3125, 0.3125, -0.25, 0.3125}, -- spout_vert
			{-0.375, -0.375, -0.375, 0.375, 0.3125, 0.375}, -- body
			{-0.5, 0, -0.5, 0.5, 0.5, 0.5}, -- funnel
		}
   },
   collision_box = {
      type = "fixed",
		fixed = {
			{-0.375, -0.375, -0.375, 0.375, 0.3125, 0.375}, -- body
			{-0.5, 0, -0.5, 0.5, 0.5, 0.5}, -- funnel
			{-0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125}, -- spout_side
		}
   },
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	drop = "lwcomponents:hopper",
	groups = { cracky = 3 },
	sounds = default.node_sound_stone_defaults (),

   on_construct = on_construct,
   on_destruct = on_destruct,
	after_place_node = after_place_node,
	on_place = on_place,
})



minetest.register_node ("lwcomponents:hopper_horz", {
   description = S("Hopper"),
   tiles = { "lwcomponents_hopper_top.png", "lwcomponents_hopper_bottom.png",
				 "lwcomponents_hopper_side.png", "lwcomponents_hopper_side.png",
				 "lwcomponents_hopper_side_spout.png", "lwcomponents_hopper_side.png" },
   drawtype = "nodebox",
   node_box = {
      type = "fixed",
		fixed = {
			{-0.375, -0.375, -0.375, 0.375, 0.3125, 0.375}, -- body
			{-0.5, 0, -0.5, -0.3125, 0.5, 0.5}, -- funnel_1
			{-0.5, 0, 0.3125, 0.5, 0.5, 0.5}, -- funnel_2
			{-0.5, 0, -0.5, 0.5, 0.5, -0.3125}, -- funnel_3
			{0.3125, 0, -0.5, 0.5, 0.5, 0.5}, -- funnel_4
			{-0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125}, -- spout_side
		}
   },
   selection_box = {
      type = "fixed",
		fixed = {
			{-0.375, -0.375, -0.375, 0.375, 0.3125, 0.375}, -- body
			{-0.5, 0, -0.5, 0.5, 0.5, 0.5}, -- funnel
			{-0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125}, -- spout_side
		}
   },
   collision_box = {
      type = "fixed",
		fixed = {
			{-0.375, -0.375, -0.375, 0.375, 0.3125, 0.375}, -- body
			{-0.5, 0, -0.5, 0.5, 0.5, 0.5}, -- funnel
			{-0.3125, -0.3125, 0.5, 0.3125, 0.3125, 0.3125}, -- spout_side
		}
   },
	paramtype = "light",
	param1 = 0,
	paramtype2 = "facedir",
	param2 = 0,
	drop = "lwcomponents:hopper",
	groups = { cracky = 3, not_in_creative_inventory = 1 },
	sounds = default.node_sound_stone_defaults (),

   on_construct = on_construct,
   on_destruct = on_destruct,
	after_place_node = after_place_node,
})



local function run_hoppers ()
	for spos, _ in pairs (hopper_list) do
		run_hopper_action (minetest.string_to_pos (spos))
	end

	minetest.after (hopper_interval, run_hoppers)
end



minetest.register_on_mods_loaded (function ()
	minetest.after (3.0, run_hoppers)
end)



end -- utils.hopper_supported
