-- Made by CaioAlpaca (aaaimmmm#0069)
-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Constants
type Dictionary = {_1: _2}

local Configuration = require(script.Parent.Configuration)

local Options = Configuration.ExternalDatabase
local Retries = Options.Retries
local Token = Options.Token..".json"

local LogErrors = false

-- Priority
local REQUESTS = {
	GET = {Url = Token},
	
	PATCH = {
		Url = Token, 
		Method = "PATCH",

		Headers = {
			["Content-Type"] = "application/json"
		},

		Body = nil
	},
	
	DELETE = {
		Url = Token,
		Method = "DELETE",
		
		Headers = {
			["Content-Type"] = "application/json"
		}	
	}
}

local CACHE = {} -- UserId : DataKey : Value : Value
local REST = {}

-- Private Methods
local function REQUEST(Method: string, Dictionary: Dictionary)
	local RequestTable = REQUESTS[Method]
	
	--> In case the method is patch we need a body to send.
	RequestTable.Body = Dictionary and HttpService:JSONEncode(Dictionary) or nil
	
	--> In case the method is delete we need to change the url
	RequestTable.Url = Dictionary and Dictionary.Url or Token
	
	for Attempt = 1, Retries do
		local Success, Result = pcall(HttpService.RequestAsync, HttpService, RequestTable)
		
		if not Success then
			continue
		end
		
		return Success, Result
	end
end

-- Public Methods

---> Gets the external database and checks if the player has data in it.
function REST.GetAsync(UserId: number)
	
	----> This system uses a cache system so we dont make requests for no reason 	
	local PlayerCache = CACHE[UserId]		
	if PlayerCache then return PlayerCache end
	
	
	local Success, Dictionary = REQUEST("GET")
	
	--> In case success is false
	if not Success and LogErrors then
		return warn("Something went wrong -> ".. Dictionary.StatusMessage)
	end
	
	
	--> JSON is our Body result decoded to be a luau hash
	local JSON = HttpService:JSONDecode(Dictionary.Body) 
	local Data = JSON and JSON[tostring(UserId)]
	
	--> If theres no player data in the external database
	if not Data then
		return nil
	end
	
	CACHE[UserId] = Data
	
	return Data
end


---> Removes the player from the external database
function REST.RemoveAsync(UserId: number)
	local DataInExternal = Options.Token.. UserId ..".json"
	local Success = REQUEST("DELETE", {Url = DataInExternal})
	
	--> In case the get method was not called.
	if not CACHE[UserId] then
		CACHE[UserId] = nil
	end
	
	if not Success and LogErrors then
		return warn("RemoveAsync -> Something went wrong")
	end
end


---> Adds the player data to the external database
function REST.PatchAsync(UserId: number, Data: Dictionary)
	local Success = REQUEST("PATCH", { [UserId] = Data })
	
	if not Success and LogErrors then
		return warn("PatchAsync -> Something went wrong")
	end
end


-- Connections Functions
local function OnPlayerRemoving(Player)
	local UserId = Player.UserId
	
	if CACHE[UserId] then
		CACHE[UserId] = nil
	end
end

-- Connections
Players.PlayerRemoving:Connect(OnPlayerRemoving)

return REST