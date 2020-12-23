-- Made by CaioAlpaca (aaaimmmm#0069)
-- Services
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Libraries
local Configuration = require(script.Configuration)
local FirebaseREST = require(script.FirebaseREST)

-- Constants
local Options = Configuration.Options

local SaveInStudio = Options.SaveInStudio
local IsStudio = RunService:IsStudio()
local Interval = Configuration.INTERVAL -- AutoSave INTERVAL

local Update = script.Update

local CLASS_CACHE = {}
local CACHE = {}

-- Priority
type Dictionary = {[string]: any}

local BetterData = {}
BetterData.__index = BetterData


-- Private Methods
local function RET_Get(Data: GlobalDataStore, Key: string) --> Any?, Boolean?
	for Attempt = 1, Configuration.Retries do
		local Success, KeyValue = pcall(Data.GetAsync, Data, Key)
		
		-- If success is false, lets retry
		if not Success then
			continue
		end
		
		return KeyValue
	end
end

local function RET_Set(Data: GlobalDataStore, Key: string, Value: any) --> Boolean?
	for Attempt = 1, Configuration.Retries do
		local Success = pcall(Data.SetAsync, Data, Key, Value)
		
		-- If success is false then lets retry
		if not Success then
			continue
		end

	end
end


-- Public Methods
function BetterData.Load(Player: Player, Dictionary: Dictionary) --> Class
	-- We use the key "__table" to save the given dictionary.
	-- We use the name __table to avoid data overriding 
	local UserId = Player.UserId
	
	local PlayerData = DataStoreService:GetDataStore("better-ds", UserId) -- Gets the player scope in data
	local Table = RET_Get(PlayerData, "__table")  
	    
	CACHE[UserId] = {} -- This is the reason why this method should always be the first data method to be called
    CLASS_CACHE[UserId] = {}
    
    
	--> If theres no data for __table
	if not Table then
		RET_Set(PlayerData, "__table", Dictionary)
	end
	
	return BetterData.Acquire(Player, {Key = "__table", Value = Dictionary})
end


--[[
	This system basically loops through the Player used Keys, (those keys
	were used to save some piece of data) and updates them with
	the  value of it.
]]
function BetterData.Save(Player: Player) --> Nil
	local PlayerData = DataStoreService:GetDataStore("better-ds", Player.UserId)
	local UsedKeys = CACHE[Player.UserId] or {} --> These keys were used to save some piece of data
	
	local FailedToSave = {}
	
    local function Update(Key, Data)
		PlayerData:UpdateAsync(Key, function()
			return Data.Value
		end)
	end

	for DataKey, Data in pairs(UsedKeys) do
		for Attempt = 1, Configuration.Retries do
			local Success = pcall(Update, DataKey, Data)
			
			--> In case all the retries fail.
			if Options.ExternalDatabase and not Success and Attempt == Configuration.Retries then 
				FailedToSave[DataKey] = Data		
				return
			end
			
			
			if not Success then
				continue
			end
				
			return
		end
	end
	
	FirebaseREST.PatchAsync(Player.UserId, FailedToSave)
end

--[[
	Cleans the given key data. This is method does not 
	use a retry system as it should only be called for live games.
]]
function BetterData.Clean(Player: Player, Key: string) --> Boolean
	local Data = DataStoreService:GetDataStore("better-ds", Player.UserId)
	
	--> TODO (WRAP THIS IN A PCALL)
	
	Data:RemoveAsync(Key)
	Player:Kick("[BetterData] -> Resetting Data")
end


-- Class Methods
function BetterData.Acquire(Player: Player, DataTable: Dictionary) --> Class
    --> This method does a lot of things that could somehow lower performance if called 
    --> several times, so i did something to prevent that, take a look:

	--> This first part checks if theres a class_cache for the player, if there isn't one then it creates one.
	
	local PlayerId = Player.UserId
	
	local PlayerClasses = CLASS_CACHE[PlayerId]
    local Key = DataTable.Key

    if not PlayerClasses then
        CLASS_CACHE[Player.UserId] = {}
    end

	PlayerClasses = CLASS_CACHE[PlayerId]
	local OnCache = PlayerClasses[Key]

    --> After that, it checks if the the Data.Key (the data name) has a class already, if it does then we just return it. 
	if OnCache then 
		return OnCache  
	end
	
    --> Below this comment, is all the code that creates the class.

	local PlayerData = DataStoreService:GetDataStore("better-ds", PlayerId) -- Player MainKey
    local PlayerCache = CACHE[Player.UserId]
 
    local HasDataInKey = RET_Get(PlayerData, Key)
    local DataValue = HasDataInKey or DataTable.Value

	
    --> If the method Load was not called then the player wont have a cache.
    --> So lets make sure he does have a cache

    --> If he does, lets make sure that the given data 
    if not PlayerCache then		
		CACHE[PlayerId] = { 
			[Key] = {Value = DataValue}
		}
		
		PlayerCache = CACHE[PlayerId]
	end
	

	local ExternalData = FirebaseREST.GetAsync(Player.UserId)
	local Data = ExternalData and ExternalData[Key]
	
	--> Lets check if the player has any data in the external database
	if Data then
		PlayerCache[Key] = Data
		FirebaseREST.RemoveAsync(PlayerId) -- Freeing space	
		
	elseif not PlayerCache[Key] then
        PlayerCache[Key] = {Value = DataValue} 
    end
    

    --> If theres no data registered to this key then
    --> This is the only time we call datastores directly 
    if not HasDataInKey then
        RET_Set(PlayerData, Key, DataTable.Value)
    end
	
		
    --> These are our public class fields.
    local Fields = {
		_Player = Player, 

		_Data = CACHE[PlayerId][Key], -- The data in the cache
        _Key = Key
	}
	
	-- Client replicator
	Update:FireClient(Player, Key, {Value = DataValue})
	
	local Class = setmetatable(Fields, BetterData)
	PlayerClasses[Key] = Class -- Adding it to the class_cache
	
    return Class
end

function BetterData:Set(Value: any)
	self._Data.Value = Value 
	self:Updating()
end

function BetterData:Increase(Value: number)
	self._Data.Value += Value 	
	self:Updating()
end

function BetterData:Decrease(Value: number)
	self:Increase(-Value)
end

function BetterData:Get()
	return self._Data.Value
end


-- Called after any method that modifies the Cached data (:Increase, :Set, :Decrease)
function BetterData:Updating(Callback)	
	Update:FireClient(self._Player, self._Key, self._Data)
	
	if not self._Callback or Callback then
		self._Callback = Callback
		return
	end

	self._Callback(self:Get())
end


-- Events functions
local function ClosingServer()
	if IsStudio and not SaveInStudio then
		return warn("[BetterData] -> BindToClose was not called because SaveInStudio is false")
    end
    
	for _, Player in ipairs(Players:GetPlayers()) do
		BetterData.Save(Player)
	end
end

local function OnPlayerRemoving(Player)
	BetterData.Save(Player)
	
    CACHE[Player.UserId] = nil
	CLASS_CACHE[Player.UserId] = nil
end

if Options.AutoSave and not IsStudio then
	local function Thread()	
		while wait(Interval) do
			
			for _, Player in ipairs(Players:GetPlayers()) do		
				BetterData.Save(Player)
			end
			
		end	
	end
	
	coroutine.wrap(Thread)()
end

-- Connections
game:BindToClose(ClosingServer)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Module
return BetterData
