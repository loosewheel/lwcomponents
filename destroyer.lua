local utils = ...
local S = utils.S



local function trash (pos)
	local meta = minetest.get_meta (pos)
	local inv = (meta and meta:get_inventory ()) or nil

	if inv then
		local stack = inv:get_stack ("trash", 1)

		if stack and not stack:is_empty () then
			utils.on_destroy (stack)

			inv:set_stack ("trash", 1, nil)
		end
	end
end



local function trash_delayed (pos)
	minetest.after (0.1, trash, pos)
end



local function after_place_node (pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta (pos)

	if meta then
		local inv = meta:get_inventory ()

		if inv then
			meta:set_string ("inventory", "{ trash = { [1] = '' } }")
			meta:set_string ("formspec",
				"formspec_version[3]"..
				"size[11.75,8.5,false]"..
				"label[5.15,1.0;Destroy]"..
				"list[context;trash;5.3,1.25;1,1;]"..
				"list[current_player;main;1.0,2.75;8,4;]"..
				"listring[]")

			inv:set_size ("trash", 1)
			inv:set_width ("trash", 1)
		end
	end

	utils.pipeworks_after_place (pos)

	-- If return true no item is taken from itemstack
	return false
end



local function on_metadata_inventory_put (pos, listname, index, stack, player)
	if listname == "trash" then
		trash_delayed (pos)
	end
end



local function on_metadata_inventory_move (pos, from_list, from_index,
														 to_list, to_index, count, player)
	if to_list == "trash" then
		trash_delayed (pos)
	end
end



local function pipeworks_support ()
	if utils.pipeworks_supported then
		return
		{
			priority = 100,
			input_inventory = "trash",
			connect_sides = { left = 1, right = 1, front = 1, back = 1, bottom = 1, top = 1 },

			insert_object = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					trash_delayed (pos)

					return inv:add_item ("trash", stack)
				end

				return stack
			end,

			can_insert = function (pos, node, stack, direction)
				local meta = minetest.get_meta (pos)
				local inv = (meta and meta:get_inventory ()) or nil

				if inv then
					return inv:room_for_item ("trash", stack)
				end

				return false
			end,

			can_remove = function (pos, node, stack, dir)
				-- returns the maximum number of items of that stack that can be removed
				return 0
			end,

			remove_items = function (pos, node, stack, dir, count)
				-- removes count items and returns them
				return stack
			end
		}
	end

	return nil
end



local destroyer_groups = { cracky = 3 }
if utils.pipeworks_supported then
	destroyer_groups.tubedevice = 1
	destroyer_groups.tubedevice_receiver = 1
end



minetest.register_node("lwcomponents:destroyer", {
	description = S("Destroyer"),
	drawtype = "normal",
	tiles = { "lwcomponents_destroyer_top.png", "lwcomponents_destroyer_top.png",
				 "lwcomponents_destroyer_side.png", "lwcomponents_destroyer_side.png",
				 "lwcomponents_destroyer_side.png", "lwcomponents_destroyer_side.png" },
	is_ground_content = false,
	groups = table.copy (destroyer_groups),
	sounds = default.node_sound_stone_defaults (),
	paramtype = "none",
	param1 = 0,
	paramtype2 = "none",
	param2 = 0,
	floodable = false,

	tube = pipeworks_support (),

	after_place_node = after_place_node,
	after_dig_node = utils.pipeworks_after_dig,
	on_metadata_inventory_put = on_metadata_inventory_put,
	on_metadata_inventory_move = on_metadata_inventory_move,
})



utils.hopper_add_container({
	{"bottom", "lwcomponents:destroyer", "trash"}, -- insert items below from hopper above
	{"side", "lwcomponents:destroyer", "trash"}, -- insert items from hopper at side
})



--
