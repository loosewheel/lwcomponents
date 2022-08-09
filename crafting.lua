local utils = ...



minetest.register_craft( {
	output = "lwcomponents:cannon",
	recipe = {
		{ "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
		{ "default:chest", "default:wood", "" },
		{ "default:copper_ingot", "default:stone", "" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:cannon_locked",
	recipe = {
		{ "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
		{ "default:chest_locked", "default:wood", "" },
		{ "default:copper_ingot", "default:stone", "" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:storage_unit 2",
	recipe = {
		{ "default:steel_ingot", "group:wood", "group:wood" },
		{ "group:wood", "", "group:wood" },
		{ "group:wood", "group:wood", "default:chest" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:storage_unit_locked 2",
	recipe = {
		{ "default:steel_ingot", "group:wood", "group:wood" },
		{ "group:wood", "", "group:wood" },
		{ "group:wood", "group:wood", "default:chest_locked" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:storage_indexer",
	recipe = {
		{ "default:steel_ingot", "group:wood" },
		{ "group:wood", "default:chest" }
	},
})


minetest.register_craft( {
	output = "lwcomponents:storage_indexer_locked",
	recipe = {
		{ "default:steel_ingot", "group:wood" },
		{ "group:wood", "default:chest_locked" }
	},
})


minetest.register_craft( {
	output = "lwcomponents:crafter",
	recipe = {
		{ "default:steel_ingot", "group:wood", "default:steel_ingot" },
		{ "group:wood", "", "group:wood" },
		{ "default:copper_ingot", "group:wood", "default:chest" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:crafter_locked",
	recipe = {
		{ "default:steel_ingot", "group:wood", "default:steel_ingot" },
		{ "group:wood", "", "group:wood" },
		{ "default:copper_ingot", "group:wood", "default:chest_locked" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:force_field",
	recipe = {
		{ "default:steel_ingot", "default:mese_crystal", "group:wood" },
		{ "default:mese_crystal", "default:diamondblock", "default:mese_crystal" },
		{ "default:stone", "default:mese_crystal", "default:chest" }
	},
})


minetest.register_craft( {
	output = "lwcomponents:force_field_locked",
	recipe = {
		{ "default:steel_ingot", "default:mese_crystal", "group:wood" },
		{ "default:mese_crystal", "default:diamondblock", "default:mese_crystal" },
		{ "default:stone", "default:mese_crystal", "default:chest_locked" }
	},
})


minetest.register_craft( {
	output = "lwcomponents:conduit 5",
	recipe = {
		{ "default:stone", "", "default:stone" },
		{ "", "default:chest", "" },
		{ "default:stone", "default:steel_ingot", "default:stone" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:conduit_locked 5",
	recipe = {
		{ "default:stone", "", "default:stone" },
		{ "", "default:chest_locked", "" },
		{ "default:stone", "default:steel_ingot", "default:stone" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:destroyer",
	recipe = {
		{ "default:stone", "", "group:wood" },
		{ "", "default:steel_ingot", "" },
		{ "group:wood", "", "default:stone" }
	},
})


minetest.register_craft( {
	output = "lwcomponents:cannon_shell 10",
	recipe = {
		{ "default:steel_ingot", "default:steel_ingot" },
		{ "", "default:coalblock" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:cannon_soft_shell 10",
	recipe = {
		{ "default:steel_ingot", "default:steel_ingot" },
		{ "default:copper_lump", "default:coalblock" },
	},
})


if minetest.global_exists ("fire") then

minetest.register_craft( {
	output = "lwcomponents:cannon_fire_shell 10",
	recipe = {
		{ "default:steel_ingot", "default:steel_ingot" },
		{ "default:iron_lump", "default:coalblock" },
	},
})

end -- minetest.global_exists ("fire")



if utils.mesecon_supported then

minetest.register_craft( {
	output = "lwcomponents:through_wire_off 2",
	recipe = {
		{ "", "mesecons:wire_00000000_off" },
		{ "mesecons:wire_00000000_off", "" },
	},
})

end -- utils.mesecon_supported


if utils.hopper_supported then

minetest.register_craft( {
	output = "lwcomponents:hopper",
	recipe = {
		{ "default:stone", "default:steel_ingot", "default:stone" },
		{ "", "default:stone", "" },
	},
})

end


if utils.digilines_supported or utils.mesecon_supported then

minetest.register_craft( {
	output = "lwcomponents:dropper",
	recipe = {
		{ "default:stone", "default:chest" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:dropper_locked",
	recipe = {
		{ "default:stone", "default:chest_locked" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:dispenser",
	recipe = {
		{ "default:chest", "default:stone" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:dispenser_locked",
	recipe = {
		{ "default:chest_locked", "default:stone" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:detector",
	recipe = {
		{ "default:copper_ingot", "default:steel_ingot" },
		{ "default:stone", "default:chest" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:detector_locked",
	recipe = {
		{ "default:copper_ingot", "default:steel_ingot" },
		{ "default:stone", "default:chest_locked" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:siren",
	recipe = {
		{ "group:wood", "default:chest" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:siren_locked",
	recipe = {
		{ "group:wood", "default:chest_locked" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:puncher",
	recipe = {
		{ "default:chest", "default:sword_stone" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:puncher_locked",
	recipe = {
		{ "default:chest_locked", "default:sword_stone" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:breaker",
	recipe = {
		{ "default:chest", "default:pick_stone" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:breaker_locked",
	recipe = {
		{ "default:chest_locked", "default:pick_stone" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:deployer",
	recipe = {
		{ "default:chest", "group:wood" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:deployer_locked",
	recipe = {
		{ "default:chest_locked", "group:wood" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:fan",
	recipe = {
		{ "default:chest", "default:steel_ingot" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:fan_locked",
	recipe = {
		{ "default:chest_locked", "default:steel_ingot" },
		{ "default:copper_ingot", "default:steel_ingot" },
	},
})


minetest.register_craft({
	output = "lwcomponents:piston 2",
	recipe = {
		{ "group:wood", "group:wood", "group:wood" },
		{ "default:cobble", "default:steel_ingot", "default:cobble" },
		{ "default:stone", "default:copper_ingot", "default:stone" },
	}
})


minetest.register_craft({
	output = "lwcomponents:piston_sticky",
	recipe = {
		{"group:sapling"},
		{"lwcomponents:piston"},
	}
})


end -- utils.digilines_supported or utils.mesecon_supported



if utils.digilines_supported then

minetest.register_craft( {
	output = "lwcomponents:collector",
	recipe = {
		{ "default:copper_ingot", "default:steel_ingot" },
		{ "default:chest", "default:stone" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:collector_locked",
	recipe = {
		{ "default:copper_ingot", "default:steel_ingot" },
		{ "default:chest_locked", "default:stone" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:hologram",
	recipe = {
		{ "dye:red", "dye:green", "dye:blue" },
		{ "default:copper_ingot", "default:steel_ingot", "default:copper_ingot" },
		{ "default:chest", "default:stone", "default:glass" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:hologram_locked",
	recipe = {
		{ "dye:red", "dye:green", "dye:blue" },
		{ "default:copper_ingot", "default:steel_ingot", "default:copper_ingot" },
		{ "default:chest_locked", "default:stone", "default:glass" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:camera",
	recipe = {
		{ "default:copper_ingot", "default:iron_lump" },
		{ "default:chest", "default:stone" },
	},
})


minetest.register_craft( {
	output = "lwcomponents:camera_locked",
	recipe = {
		{ "default:copper_ingot", "default:iron_lump" },
		{ "default:chest_locked", "default:stone" },
	},
})

end -- utils.digilines_supported



if utils.digilines_supported and utils.digistuff_supported then


minetest.register_craft({
	output = "lwcomponents:player_button",
	recipe = {
		{ "mesecons_button:button_off", "digilines:wire_std_00000000" }
	},
})


end -- utils.digilines_supported and utils.digistuff_supported



if utils.mesecon_supported then

minetest.register_craft ({
   output = "lwcomponents:movefloor",
   recipe = {
      { "default:stick", "default:stick", "default:stick" },
      { "default:stick", "default:steel_ingot", "default:stick" },
      { "default:stick", "default:stick", "default:stick" },
   }
})

end -- utils.mesecon_supported



if utils.digilines_supported and utils.mesecon_supported then

minetest.register_craft ({
   output = "lwcomponents:digiswitch 2",
   recipe = {
      { "default:stone", "default:stone" },
      { "default:copper_ingot", "default:mese_crystal_fragment" },
      { "default:stick", "default:stick" },
   }
})

end -- utils.digilines_supported and utils.mesecon_supported



if utils.unifieddyes_supported and utils.mesecon_supported then

minetest.register_craft ({
	output = "lwcomponents:solid_conductor_off 3",
	recipe = {
		{ "default:mese_crystal_fragment", "group:wood", ""},
		{ "group:wood", "group:wood", "dye:white" },
	},
})


minetest.register_craft ({
	output = "lwcomponents:solid_horizontal_conductor_off 3",
	recipe = {
		{ "group:wood", "group:wood", ""},
		{ "default:mese_crystal_fragment", "group:wood", "dye:white" },
	},
})

end -- utils.unifieddyes_supported and utils.mesecon_supported then



--
