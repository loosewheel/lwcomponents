local version = "0.1.34"
local mod_storage = minetest.get_mod_storage ()



lwcomponents = { }



function lwcomponents.version ()
	return version
end


local utils = { }
local modpath = minetest.get_modpath ("lwcomponents")

loadfile (modpath.."/settings.lua") (utils)
utils.get_dummy_player = loadfile (modpath.."/dummy_player.lua") ()
loadfile (modpath.."/utils.lua") (utils)
loadfile (modpath.."/long_process.lua") (utils)
-- ugly hack warnign
local oldregnode = minetest.register_node
function minetest.register_node(name,def)
	local n="lwcomponents:"
	if name:sub(1,#n) == n and name:find("locked") then
		for _,k in pairs{"take","put","move"} do
			local k="allow_metadata_inventory_"..k
			if not def[k] then
				def[k]=utils[k]
			else
				local f=def[k]
				def[k]=function(...)
					local e=utils[k](...)
					if not e or e==0 then return e end
					return f(...)
				end
			end
		end
	end
	return oldregnode(name,def)
end
-- /ugly hack
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
loadfile (modpath.."/crafter.lua") (utils)
loadfile (modpath.."/force_field.lua") (utils)
loadfile (modpath.."/destroyer.lua") (utils)
loadfile (modpath.."/extras.lua") (utils)
loadfile (modpath.."/digiswitch.lua") (utils)
loadfile (modpath.."/movefloor.lua") (utils)
loadfile (modpath.."/solid_conductor.lua") (utils)
loadfile (modpath.."/crafting.lua") (utils)
minetest.register_node=oldregnode


--
