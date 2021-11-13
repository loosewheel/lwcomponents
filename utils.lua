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



-- check for lwdrops
if minetest.global_exists ("lwdrops") then
	utils.lwdrops_supported = true
	utils.on_destroy = lwdrops.on_destroy
	utils.item_pickup = lwdrops.item_pickup
	utils.item_drop = lwdrops.item_drop
else
	utils.lwdrops_supported = false

	-- dummy
	utils.on_destroy = function (itemstack)
	end

	utils.item_pickup = function (entity, cleanup)
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

	utils.item_drop = function (itemstack, dropper, pos)
		return minetest.item_drop (itemstack, dropper, pos)
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



-- check for mobs
if minetest.global_exists ("mobs") then
	utils.mobs_supported = true
else
	utils.mobs_supported = false
end



-- check for digistuff
if minetest.global_exists ("digistuff") then
	utils.digistuff_supported = true
else
	utils.digistuff_supported = false
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



--
