local utils = ...



local RUN_INTERVAL = 0.1



local processes = { index = 0, current = 0 }
local after_job



local function run_processes ()
	if #processes > 0 then
		processes.index = (processes.index % #processes) + 1

		local process = processes[processes.index]

		processes.current = processes.index
		process.timer = os.clock ()
		process.resume ()
		processes.current = 0
	end

	if #processes > 0 then
		after_job = minetest.after (RUN_INTERVAL, run_processes)
	else
		processes.index = 0
		processes.current = 0
		after_job = nil
	end
end



local long_process = { }



function long_process.remove (id)
	if id then
		for i = 1, #processes, 1 do
			if processes[i].id == id then
				local breaker = ((processes.current == id) and processes[i].breaker)

				if processes.current == i then
					processes.current = 0
				elseif processes.current > i then
					processes.current = processes.current - 1
				end

				if processes.index >= i then
					processes.index = processes.index - 1
				end

				table.remove (processes, i)

				if breaker then
					breaker ()
				end

				return true
			end
		end
	elseif processes[processes.current] then
		local breaker = processes[processes.current].breaker

		if processes.index >= processes.current then
			processes.index = processes.index - 1
		end

		table.remove (processes, processes.current)
		processes.current = 0

		if breaker then
			breaker ()
		end

		return true
	end

	return false
end



function long_process.breaker (id)
	if id then
		for i = 1, #processes, 1 do
			if processes[i].id == id then
				return processes[i].breaker
			end
		end
	elseif processes[processes.current] then
		return processes[processes.current].breaker
	end

	return nil
end



function long_process.timer (id)
	if id then
		for i = 1, #processes, 1 do
			if processes[i].id == id then
				return processes[i].timer
			end
		end
	elseif processes[processes.current] then
		return processes[processes.current].timer
	end

	return os.clock () + 3600
end



function long_process.expire (secs, id)
	if id then
		for i = 1, #processes, 1 do
			if processes[i].id == id then
				if (processes[i].timer + secs) <= os.clock () then
					processes[i].breaker ()

					return true
				end
			end
		end
	elseif processes[processes.current] then
		if (processes[processes.current].timer + secs) <= os.clock () then
			processes[processes.current].breaker ()

			return true
		end
	end

	return false
end



function long_process.add (func, callback, ...)
	local args = { ... }
	local id = math.random (1000000)
	local thread


	local function thread_breaker ()
		coroutine.yield (thread)
	end


	local function thread_func ()
		return func (unpack (args))
	end


	local function thread_resume ()
		local results = { coroutine.resume (thread) }

		if coroutine.status (thread) == "dead" then
			if callback then
				callback (id, unpack (results))
			end

			long_process.remove (id)
		end
	end

	thread = coroutine.create (thread_func)

	if thread and coroutine.status (thread) == "suspended" then
		processes[#processes + 1] =
		{
			id = id,
			resume = thread_resume,
			breaker = thread_breaker,
			callback = callback,
			timer = os.clock ()
		}

		if not after_job then
			after_job = minetest.after (RUN_INTERVAL, run_processes)
		end

		return id
	end

	return nil
end



utils.long_process = long_process
