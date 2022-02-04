local utils = ...
local S = utils.S



if utils.mesecon_supported then



local through_wire_get_rules = function (node)
	local rules = { {x = -1, y = 0, z = 0},
						 {x =  2, y = 0, z = 0},
						 {x =  3, y = 0, z = 0} }

	if node.param2 == 2 then
		rules = mesecon.rotate_rules_left(rules)
	elseif node.param2 == 3 then
		rules = mesecon.rotate_rules_right(mesecon.rotate_rules_right(rules))
	elseif node.param2 == 0 then
		rules = mesecon.rotate_rules_right(rules)
	end

	return rules
end



mesecon.register_node ("lwcomponents:through_wire", {
	description = S("Mesecons Through Wire"),
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	is_ground_content = false,
	sunlight_propagates = true,
	walkable = false,
	on_rotate = false,
	selection_box = {
		type = "fixed",
		fixed = { -3/16, -8/16, -8/16, 3/16, 3/16, 8/16 }
	},
	node_box = {
		type = "fixed",
		fixed = {
			{ -3/16, -3/16, 13/32        , 3/16,  3/16  , 8/16        }, -- the smaller bump
			{ -1/32, -1/32, 1/2          , 1/32,  1/32  , 3/2         }, -- the wire through the block
			{ -2/32, -1/2 , 0.5002-3/32  , 2/32,  0     , 0.5         }, -- the vertical wire bit
			{ -2/32, -1/2 , -16/32+0.001 , 2/32,  -14/32,  7/16+0.002 }  -- the horizontal wire
		}
	},
	drop = "lwcomponents:through_wire_off",
	sounds = default.node_sound_defaults(),
}, {
	tiles = { "mesecons_wire_off.png" },
	groups = { dig_immediate = 3 },
	mesecons = {
		conductor = {
			state = mesecon.state.off,
			rules = through_wire_get_rules,
			onstate = "lwcomponents:through_wire_on"
		}
	}
}, {
	tiles = { "mesecons_wire_on.png" },
	groups = { dig_immediate = 3, not_in_creative_inventory = 1 },
	mesecons = {
		conductor = {
			state = mesecon.state.on,
			rules = through_wire_get_rules,
			offstate = "lwcomponents:through_wire_off"
		}
	}
})



end -- utils.mesecon_supported



--
