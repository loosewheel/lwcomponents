local version = "0.1.25"
local mod_storage = minetest.get_mod_storage ()



lwcomponents = { }



function lwcomponents.version ()
	return version
end


local utils = { }
local modpath = minetest.get_modpath ("lwcomponents")

loadfile (modpath.."/settings.lua") (utils)
utils.get_dummy_player = loadfile (modpath.."/dummy_player.lua") ()
loadfile (modpath.."/utils.lua") (utils, mod_storage)
loadfile (modpath.."/explode.lua") (utils)
loadfile (modpath.."/api.lua") (utils)
utils.connections = loadfile (modpath.."/connections.lua") ()
loadfile (modpath.."/dropper.lua") (utils)
loadfile (modpath.."/collector.lua") (utils)
loadfile (modpath.."/dispenser.lua") (utils)
loadfile (modpath.."/detector.lua") (utils)
loadfile (modpath.."/siren.lua") (utils)
loadfile (modpath.."/puncher.lua") (utils)
loadfile (modpath.."/player_button.lua") (utils)
loadfile (modpath.."/hologram.lua") (utils)
loadfile (modpath.."/breaker.lua") (utils)
loadfile (modpath.."/deployer.lua") (utils)
loadfile (modpath.."/fan.lua") (utils)
loadfile (modpath.."/conduit.lua") (utils, mod_storage)
loadfile (modpath.."/hopper.lua") (utils, mod_storage)
loadfile (modpath.."/cannon.lua") (utils)
loadfile (modpath.."/cannon_shell.lua") (utils)
loadfile (modpath.."/pistons.lua") (utils)
loadfile (modpath.."/through_wire.lua") (utils)
loadfile (modpath.."/camera.lua") (utils)
loadfile (modpath.."/storage.lua") (utils)
loadfile (modpath.."/force_field.lua") (utils)
loadfile (modpath.."/extras.lua") (utils)
loadfile (modpath.."/digiswitch.lua") (utils)
loadfile (modpath.."/movefloor.lua") (utils)
loadfile (modpath.."/solid_conductor.lua") (utils)
loadfile (modpath.."/crafting.lua") (utils)



--
