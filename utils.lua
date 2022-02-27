local utils, mod_storage = ...



if minetest.get_translator and minetest.get_translator ("lwcomponents") then
	utils.S = minetest.get_translator ("lwcomponents")
elseif minetest.global_exists ("intllib") then
   if intllib.make_gettext_pair then
      utils.S = intllib.make_gettext_pair ()
   else
      utils.S = intllib.Getter ()
   end
else
   utils.S = function (s) return s end
end



-- check for mesecon
if minetest.global_exists ("mesecon") then
	utils.mesecon_supported = true
	utils.mesecon_state_on = mesecon.state.on
	utils.mesecon_state_off = mesecon.state.off
	utils.mesecon_receptor_on = mesecon.receptor_on
	utils.mesecon_receptor_off = mesecon.receptor_off
	utils.mesecon_default_rules = mesecon.rules.default
	utils.mesecon_flat_rules = mesecon.rules.flat

else
	utils.mesecon_supported = false
	utils.mesecon_state_on = "on"
	utils.mesecon_state_off = "off"
	utils.mesecon_default_rules = { }
	utils.mesecon_flat_rules = { }

	-- dummies
	utils.mesecon_receptor_on = function (pos, rules)
	end

	utils.mesecon_receptor_off = function (pos, rules)
	end

end



-- check for digilines
if minetest.global_exists ("digilines") then
	utils.digilines_supported = true
	utils.digilines_default_rules = digiline.rules.default
	utils.digilines_flat_rules = {
		{ x =  1, y = 0, z =  0 },
		{ x = -1, y = 0, z =  0 },
		{ x =  0, y = 0, z =  1 },
		{ x =  0, y = 0, z = -1 },
	}
	utils.digilines_receptor_send = digilines.receptor_send
else
	utils.digilines_supported = false
	utils.digilines_default_rules = { }
	utils.digilines_flat_rules = { }

	-- dummy
	utils.digilines_receptor_send = function (pos, rules, channel, msg)
	end
end



-- check for unifieddyes
if minetest.global_exists ("unifieddyes") then
	utils.unifieddyes_supported = true
else
	utils.unifieddyes_supported = false
end



-- check for hopper
if minetest.global_exists ("hopper") then
	utils.hopper_supported = true

	utils.hopper_add_container = function (list)
		hopper:add_container (list)
	end
else
	utils.hopper_supported = false

	utils.hopper_add_container = function (list)
	end
end



-- check for digistuff
if minetest.global_exists ("digistuff") then
	utils.digistuff_supported = true
else
	utils.digistuff_supported = false
end



-- check for pipeworks
if minetest.global_exists ("pipeworks") then
	utils.pipeworks_supported = true
	utils.pipeworks_after_place = pipeworks.after_place
	utils.pipeworks_after_dig = pipeworks.after_dig
else
	utils.pipeworks_supported = false
	utils.pipeworks_after_place = function (pos)
	end
	utils.pipeworks_after_dig = function (pos)
	end
end



function utils.on_destroy (itemstack)
	local stack = ItemStack (itemstack)

	if stack and stack:get_count () > 0 then
		local def = utils.find_item_def (stack:get_name ())

		if def and def.on_destroy then
			def.on_destroy (stack)
		end
	end
end



function utils.item_pickup (entity, cleanup)
	local stack = nil

	if entity and entity.name and entity.name == "__builtin:item" and
		entity.itemstring and entity.itemstring ~= "" then

		stack = ItemStack (entity.itemstring)

		if cleanup ~= false then
			entity.itemstring = ""
			entity.object:remove ()
		end
	end

	return stack
end



function utils.item_drop (itemstack, dropper, pos)
	if itemstack then
		local def = utils.find_item_def (itemstack:get_name ())

		if def and def.on_drop then
			return def.on_drop (itemstack, dropper, pos)
		end
	end

	return minetest.item_drop (itemstack, dropper, pos)
end



function utils.can_interact_with_node (pos, player)
	if not player or not player:is_player () then
		return false
	end

	if minetest.check_player_privs (player, "protection_bypass") then
		return true
	end

	local meta = minetest.get_meta (pos)
	if meta then
		local owner = meta:get_string ("owner")
		local name = player:get_player_name ()

		if not owner or owner == "" or owner == name then
			return true
		end
	end

	return false
end



function utils.get_far_node (pos)
	local node = minetest.get_node (pos)

	if node.name == "ignore" then
		minetest.get_voxel_manip ():read_from_map (pos, pos)

		node = minetest.get_node (pos)

		if node.name == "ignore" then
			return nil
		end
	end

	return node
end



function utils.find_item_def (name)
	local def = minetest.registered_items[name]

	if not def then
		def = minetest.registered_craftitems[name]
	end

	if not def then
		def = minetest.registered_nodes[name]
	end

	if not def then
		def = minetest.registered_tools[name]
	end

	return def
end



function utils.is_same_item (item1, item2)
	local copy1 = ItemStack (item1)
	local copy2 = ItemStack (item2)

	if copy1 and copy2 then
		copy1:set_count (1)
		copy2:set_count (1)

		return copy1:to_string () == copy2:to_string ()
	end

	return false
end



function utils.destroy_node (pos)
	local node = utils.get_far_node (pos)

	if node then
		local items = minetest.get_node_drops (node, nil)

		if items then
			for i = 1, #items do
				local stack = ItemStack (items[i])

				if stack and not stack:is_empty () then
					local name = stack:get_name ()
					local def = utils.find_item_def (name)

					if def then
						if def.preserve_metadata then
							def.preserve_metadata (pos, node, minetest.get_meta (pos), { stack })
						end

						utils.on_destroy (stack)
					end
				end
			end
		end

		minetest.remove_node (pos)
	end
end



utils.registered_spawners = { }
-- each entry [spawner_itemname] = spawner_func



function utils.register_spawner (itemname, spawn_func)
	if type (itemname) == "string" and type (spawn_func) == "function" then
		if not utils.registered_spawners[itemname] then
			utils.registered_spawners[itemname] = spawn_func

			return true
		end
	end

	return false
end



function utils.spawn_registered (itemname, spawn_pos, itemstack, owner, spawner_pos, spawner_dir, force)
	local func = utils.registered_spawners[itemname]

	if func then
		local result, obj, cancel = pcall (func, spawn_pos, itemstack, owner, spawner_pos, spawner_dir, force)

		if result and (obj == nil or type (obj) == "userdata" or type (obj) == "table") then
			return obj, cancel
		end

		minetest.log ("error", "lwcomponents.register_spawner spawner function for "..itemname.." failed "..
									  ((type (obj) == "string" and obj) or ""))

		return nil, true
	end

	return nil, false
end



function utils.can_place (pos)
	local node = minetest.get_node_or_nil (pos)

	if node and node.name ~= "air" then
		local def = minetest.registered_nodes[node.name]

		if not def or not def.buildable_to then
			return false
		end
	end

	return true
end



function utils.is_protected (pos, player)
	local name = (player and player:get_player_name ()) or ""

	return minetest.is_protected (pos, name)
end



function utils.get_on_rightclick (pos, player)
	local node = minetest.get_node_or_nil (pos)

	if node then
		local def = minetest.registered_nodes[node.name]

		if def and def.on_rightclick and
			not (player and player:is_player () and
				  player:get_player_control ().sneak) then

				return def.on_rightclick
		end
	end

	return nil
end



function utils.is_creative (player)
	if minetest.settings:get_bool ("creative_mode") then
		return true
	end

	if player and player:is_player () then
		return minetest.is_creative_enabled (player:get_player_name ()) or
				 minetest.check_player_privs (player, "creative")
	end

	return false
end



--
