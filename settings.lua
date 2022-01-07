local utils = ...


utils.settings = { }

utils.settings.spawn_mobs =
	minetest.settings:get_bool ("lwcomponents_spawn_mobs", true)

utils.settings.alert_handler_errors =
	minetest.settings:get_bool ("lwcomponents_alert_handler_errors", true)

utils.settings.max_piston_nodes =
	tonumber(minetest.settings:get("lwcomponents_max_piston_nodes") or 15)



--
