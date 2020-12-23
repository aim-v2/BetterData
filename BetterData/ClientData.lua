--> Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--> Contants
type Table = {_1: _2}

local Update = ReplicatedStorage.BetterData.Update

--> Priority
local ClientData = {
	Cache = {}
}


--> Private Methods
local function SetUpdate(Key, Value)
	ClientData:Set(Key, Value)
end

local function OnPlayerRemoving()
	ClientData.Cache = nil
end


--> Public Methods
function ClientData:Get(Key: string)
	return self.Cache[Key]
end

function ClientData:Set(Key: string, Information: Table)
	self.Cache[Key] = Information.Value
	self:Updating(Key)
end

function ClientData:WaitFor(Key: string)
	local KeyInCache = self.Cache[Key]
	local TimeOut = 180

	-- In case the key is already in the cache
	if KeyInCache then
		return KeyInCache
	end

	while not KeyInCache and TimeOut > 0 do
		TimeOut =- 1
		wait(0.01)
	end

	return self.Cache[Key]
end

function ClientData:Updating(Key: string, Callback)	
	
	--> In case theres no callbacked set or callback is passed as an argument
	if not self.Callback or Callback then
		self.Callback = Callback
		return
	end
		
	self.Callback(self:Get(Key))
end

--> Connections
Update.OnClientEvent:Connect(SetUpdate)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

--> Module
return ClientData
