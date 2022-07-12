local utils = ...


utils.settings = { }

utils.settings.spawn_mobs =
	minetest.settings:get_bool ("lwcomponents_spawn_mobs", true)

utils.settings.alert_handler_errors =
	minetest.settings:get_bool ("lwcomponents_alert_handler_errors", true)

utils.settings.max_piston_nodes =
	tonumber (minetest.settings:get ("lwcomponents_max_piston_nodes") or 15)

utils.settings.use_player_when_placing =
	minetest.settings:get_bool ("lwcomponents_use_player_when_placing", false)

utils.settings.default_stack_max =
	tonumber (minetest.settings:get ("default_stack_max")) or 99



--
