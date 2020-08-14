--[[

QueueSettings:

maxPlayers -- The maximum amount of players allowed in the queue

minStart -- The minimum amount of players that can be in the queue before countdown

countTime -- The amount of time until the queue is initiated once minStart is initiated

placeId -- The place that the players will be teleported to

]]

--Private--

local teleportService = game:GetService("TeleportService")

local function teleportQueue(queue,placeId)
	local server = teleportService:ReserveServer(placeId)
	local success = pcall(function()
		teleportService:TeleportToPrivateServer(placeId,server,queue)
	end)
	if success then
		return true
	else
		return false
	end
end

--Public--


local methods = {}

methods.AddPlayer = function(self,player)
	local queued = self.queued
	if player then
		if not table.find(queued,player) and #queued < self.max and not self.finished then
			table.insert(queued,player)
			self.r_playerAdded:Fire(player)
		end
	else
		warn("Attempt to 'AddPlayer' but player was nil")
	end
end

methods.RemovePlayer = function(self,player)
	local queued = self.queued
	if player then
		local plrIndex = table.find(queued,player)
		if plrIndex and not self.finished then
			table.remove(queued,plrIndex)
			self.r_playerRemoved:Fire(player)
		end
	else
		warn("Attempt to 'RemovePlayer' but player was nil")
	end
end

methods.BindToCount = function(self,bindName,func)
	if func then
		self.tickConnections[bindName] = self.CountTick:Connect(func)
	else
		warn("Could not bind, invalid function")
	end
end

methods.UnbindFromCount = function(self,bindName)
	local connection = self.tickConnections[bindName]
	if connection then
		connection:Disconnect()
	end
end

methods.Teleport = function(self)
	teleportQueue(self.queued,self.placeId)
end

methods.Cancel = function(self)
	self.cancelled = true
end

methods.Start = function(self)
	coroutine.resume(self.coro)
end

local QueueService = {}

QueueService.Create = function(self,maxPlayers,minStart,countTime,placeId)
	
	local PlayerAdded = Instance.new("BindableEvent")
	local PlayerRemoved = Instance.new("BindableEvent")
	local Initiated = Instance.new("BindableEvent")
	local CountTick = Instance.new("BindableEvent")
	local TickStarted = Instance.new("BindableEvent")
	local TickStopped = Instance.new("BindableEvent")
	
	--Vars--
	local canDestroy = {false,false}
	local ticking = false
	local complete = false
	
	local object = {
		--Event Objects--
		r_playerAdded = PlayerAdded,
		r_playerRemoved = PlayerRemoved,
		r_initiated = Initiated,
		r_countTick = CountTick,
		r_tickStarted = TickStarted,
		r_tickStopped = TickStopped,
		
		--Events--
		PlayerAdded = PlayerAdded.Event,
		PlayerRemoved = PlayerRemoved.Event,
		Initiated = Initiated.Event,
		CountTick = CountTick.Event,
		TickStarted = TickStarted.Event,
		TickStopped = TickStopped.Event,
		
		
		max = maxPlayers,
		tickConnections = {},
		cancelled = false,
		finished = false,
		queued = {},
	}
	
	spawn(function()
		while true do
			if ticking then
				for i = 1,countTime do
					wait(1)
					if not ticking or object.cancelled then
						ticking = false
						break
					end
					CountTick:Fire(i)
				end
				if not ticking then
					TickStopped:Fire()
					if object.cancelled then
						canDestroy[2] = true
						break
					end
				else
					Initiated:Fire()
					object.finished = true
					if placeId then
						teleportQueue(object.queued,placeId)
					end
					canDestroy[2] = true
					break
				end
			else
				wait()
			end
		end
	end)
	
	object.coro = coroutine.create(function()
		while true do
			if #object.queued >= minStart and not ticking then
				TickStarted:Fire()
				ticking = true
			elseif ticking and #object.queued < minStart then
				ticking = false
			elseif object.finished or object.cancelled then
				canDestroy[1] = true
				break
			end
			wait()
		end
		coroutine.yield()
	end)
	
	setmetatable(canDestroy,{
		__index = function()
			if rawget(canDestroy,1) == true and rawget(canDestroy,2) == true then
				object = nil
			end
		end
	})
	
	return setmetatable(object,{
		__index = methods
	})
	
end

return QueueService