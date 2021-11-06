local utils = ...
local S = utils.S



if utils.unifieddyes_supported and utils.mesecon_supported and utils.digilines_supported then



mesecon.register_node (":lwcomponents:solid_conductor",
	{
		description = S("Solid Color Conductor"),
		tiles = { "lwsolid_conductor.png" },
		is_ground_content = false,
		sounds = ( default and default.node_sound_wood_defaults() ),
		paramtype2 = "color",
		palette = "unifieddyes_palette_extended.png",
		on_rotate = false,
		drop = "lwcomponents:solid_conductor_off",
		digiline = { wire = { rules = mesecon.rules.default } },
		on_construct = unifieddyes.on_construct,
		on_dig = unifieddyes.on_dig,
	},
	{
		tiles = { "lwsolid_conductor.png" },
		mesecons =
		{
			conductor =
			{
				rules = mesecon.rules.default,
				state = mesecon.state.off,
				onstate = "lwcomponents:solid_conductor_on",
			}
		},
		groups = {
			dig_immediate = 2,
			ud_param2_colorable = 1,
		},
	},
	{
		tiles = { "lwsolid_conductor.png" },
		mesecons =
		{
			conductor =
			{
				rules = mesecon.rules.default,
				state = mesecon.state.on,
				offstate = "lwcomponents:solid_conductor_off",
			}
		},
		groups = {
			dig_immediate = 2,
			ud_param2_colorable = 1,
			not_in_creative_inventory = 1
		},
	}
)



unifieddyes.register_color_craft ({
	output = "lwcomponents:solid_conductor_off 3",
	palette = "extended",
	type = "shapeless",
	neutral_node = "lwcomponents:solid_conductor_off",
	recipe = {
		"NEUTRAL_NODE",
		"NEUTRAL_NODE",
		"NEUTRAL_NODE",
		"MAIN_DYE"
	}
})



mesecon.register_node (":lwcomponents:solid_horizontal_conductor",
	{
		description = S("Solid Color Horizontal Conductor"),
		tiles = { "lwsolid_conductor.png" },
		is_ground_content = false,
		sounds = ( default and default.node_sound_wood_defaults() ),
		paramtype2 = "color",
		palette = "unifieddyes_palette_extended.png",
		on_rotate = false,
		drop = "lwcomponents:solid_horizontal_conductor_off",
		digiline = { wire = { rules = mesecon.rules.flat } },
		on_construct = unifieddyes.on_construct,
		on_dig = unifieddyes.on_dig,
	},
	{
		tiles = { "lwsolid_conductor.png" },
		mesecons =
		{
			conductor =
			{
				rules = mesecon.rules.flat,
				state = mesecon.state.off,
				onstate = "lwcomponents:solid_horizontal_conductor_on",
			}
		},
		groups = {
			dig_immediate = 2,
			ud_param2_colorable = 1,
		},
	},
	{
		tiles = { "lwsolid_conductor.png" },
		mesecons =
		{
			conductor =
			{
				rules = mesecon.rules.flat,
				state = mesecon.state.on,
				offstate = "lwcomponents:solid_horizontal_conductor_off",
			}
		},
		groups = {
			dig_immediate = 2,
			ud_param2_colorable = 1,
			not_in_creative_inventory = 1
		},
	}
)



unifieddyes.register_color_craft ({
	output = "lwcomponents:solid_horizontal_conductor_off 3",
	palette = "extended",
	type = "shapeless",
	neutral_node = "lwcomponents:solid_horizontal_conductor_off",
	recipe = {
		"NEUTRAL_NODE",
		"NEUTRAL_NODE",
		"NEUTRAL_NODE",
		"MAIN_DYE"
	}
})



end -- utils.unifieddyes_supported and utils.mesecon_supported and utils.digilines_supported then
