local utils = ...



-- function (spawn_pos, itemstack, owner, spawner_pos, spawner_dir)
function lwcomponents.register_spawner (itemname, spawn_func)
	return utils.register_spawner (itemname, spawn_func)
end



--
