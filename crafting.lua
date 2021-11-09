local utils = ...
local S = utils.S



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

end -- utils.digilines_supported



if utils.mesecon_supported and mesecon.mvps_push then

minetest.register_craft ({
   output = "lwcomponents:movefloor",
   recipe = {
      { "default:stick", "default:stick", "default:stick" },
      { "default:stick", "default:steel_ingot", "default:stick" },
      { "default:stick", "default:stick", "default:stick" },
   }
})

end -- utils.mesecon_supported and mesecon.mvps_push



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
	output = "lwcomputers:solid_conductor_off 3",
	recipe = {
		{ "default:mese_crystal_fragment", "group:wood", ""},
		{ "group:wood", "group:wood", "dye:white" },
	},
})


minetest.register_craft ({
	output = "lwcomputers:solid_horizontal_conductor_off 3",
	recipe = {
		{ "group:wood", "group:wood", ""},
		{ "default:mese_crystal_fragment", "group:wood", "dye:white" },
	},
})

end -- utils.unifieddyes_supported and utils.mesecon_supported then



--
