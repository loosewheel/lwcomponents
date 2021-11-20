


local connections = { }



function connections:new (mod_storage, name)
	local obj = { }

   setmetatable (obj, self)
   self.__index = self

   obj.connector_list = { }
   obj.name = tostring (name)
   obj.storage = mod_storage

	if mod_storage then
		local stored = mod_storage:get_string (obj.name)

		if stored == "" then
			stored = "{ }"
		end

		obj.connector_list = minetest.deserialize (stored)

		if not obj.connector_list then
			obj.connector_list = { }
		end
	end

	return obj
end



function connections:load ()
	if self.storage then
		local stored = self.storage:get_string (self.name)

		if stored == "" then
			stored = "{ }"
		end

		self.connector_list = minetest.deserialize (stored)
	end
end



function connections:store ()
	if self.storage then
		self.storage:set_string (self.name, minetest.serialize (self.connector_list))
	end
end




function connections:add_node (pos, id)
	self.connector_list[minetest.pos_to_string (pos, 0)] =
	{
		id = (id and tostring (id)) or nil,
		checked = false
	}

	self:store ()
end



function connections:remove_node (pos)
	self.connector_list[minetest.pos_to_string (pos, 0)] = nil

	self:store ()
end



function connections:set_id (pos, id)
	local con = self.connector_list[minetest.pos_to_string (pos, 0)]

	if con then
		con.id = (id and tostring (id)) or nil

		self:store ()

		return true
	end

	return false
end



local function is_connected (self, pos, id, tally, test_coords)
	if not id then
		return nil
	end

	local con = self.connector_list[minetest.pos_to_string (pos, 0)]

	if con and not con.checked then
		con.checked = true

		if con.id == id then
			con.checked = false

			return pos, tally
		end

		for i = 1, #test_coords do
			local result, agg = is_connected (self,
														 {
															 x = pos.x + test_coords[i].x,
															 y = pos.y + test_coords[i].y,
															 z = pos.z + test_coords[i].z
														 },
														 id,
														 tally,
														 test_coords)

			if result then
				con.checked = false

				return result, (tally + agg + 1)
			end
		end

		con.checked = false
	end

	return nil, 0
end



function connections:is_connected (pos, id)
	return is_connected (self,
								pos,
								tostring (id),
								0,
								{
									{ x =  1, y =  0, z =  0 },
									{ x = -1, y =  0, z =  0 },
									{ x =  0, y =  0, z =  1 },
									{ x =  0, y =  0, z = -1 },
									{ x =  0, y =  1, z =  0 },
									{ x =  0, y = -1, z =  0 }
								})
end



function connections:is_connected_horizontal (pos, id)
	return is_connected (self,
								pos,
								tostring (id),
								0,
								{
									{ x =  1, y =  0, z =  0 },
									{ x = -1, y =  0, z =  0 },
									{ x =  0, y =  0, z =  1 },
									{ x =  0, y =  0, z = -1 }
								})
end



function connections:is_connected_vertical (pos, id)
	return is_connected (self,
								pos,
								tostring (id),
								0,
								{
									{ x =  0, y =  1, z =  0 },
									{ x =  0, y = -1, z =  0 }
								})
end



local function get_connected_ids (self, pos, test_coords, list)
	local con = self.connector_list[minetest.pos_to_string (pos, 0)]

	if con and not con.checked then
		con.checked = true

		if con.id then
			list[#list + 1] =
			{
				pos = { x = pos.x, y = pos.y, z = pos.z },
				id = con.id
			}
		end

		for i = 1, #test_coords do
			get_connected_ids (self,
									 {
										  x = pos.x + test_coords[i].x,
										  y = pos.y + test_coords[i].y,
										  z = pos.z + test_coords[i].z
									  },
									  test_coords,
									  list)
		end

		con.checked = false
	end

	return list
end



function connections:get_connected_ids (pos)
	local list = get_connected_ids (self,
											  pos,
											  {
												  { x =  1, y =  0, z =  0 },
												  { x = -1, y =  0, z =  0 },
												  { x =  0, y =  0, z =  1 },
												  { x =  0, y =  0, z = -1 },
												  { x =  0, y =  1, z =  0 },
												  { x =  0, y = -1, z =  0 }
											  },
											  { })

	for i = #list, 1, -1 do
		for j = 1, i - 1, 1 do
			if list[i].pos.x == list[j].pos.x and
				list[i].pos.y == list[j].pos.y and
				list[i].pos.z == list[j].pos.z then

				list[i] = nil
				break
			end
		end
	end

	return list
end



function connections:get_connected_ids_horizontal (pos)
	return get_connected_ids (self,
									  pos,
									  {
										  { x =  1, y =  0, z =  0 },
										  { x = -1, y =  0, z =  0 },
										  { x =  0, y =  0, z =  1 },
										  { x =  0, y =  0, z = -1 }
									  },
									  { })
end



function connections:get_connected_ids_vertical (pos)
	return get_connected_ids (self,
									  pos,
									  {
										  { x =  0, y =  1, z =  0 },
										  { x =  0, y = -1, z =  0 }
									  },
									  { })
end



function connections:get_connected_ids_north_south (pos)
	return get_connected_ids (self,
									  pos,
									  {
										  { x =  0, y =  0, z =  1 },
										  { x =  0, y =  0, z = -1 }
									  },
									  { })
end



function connections:get_connected_ids_east_west (pos)
	return get_connected_ids (self,
									  pos,
									  {
										  { x =  1, y =  0, z =  0 },
										  { x = -1, y =  0, z =  0 }
									  },
									  { })
end



return connections



--
