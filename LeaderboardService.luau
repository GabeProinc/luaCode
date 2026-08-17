-- Discord: gabebomb | Roblox: VolkiGabe
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local leaderboards = Workspace:WaitForChild("LeaderBoards")

local maxEntries = 10
local refreshInterval = 60

local killsStore = DataStoreService:GetOrderedDataStore("CombatantsTopKillsV1")
local playtimeStore = DataStoreService:GetOrderedDataStore("CombatantsTopPlaytimeV1")
local winsStore = DataStoreService:GetOrderedDataStore("CombatantsTopWinsV1")

local nameCache = {}
local iconCache = {}

local function formatNumber(val)
	val = math.floor(val or 0)
	if val >= 1000000000 then
		return string.format("%.1fB", val / 1000000000)
	elseif val >= 1000000 then
		return string.format("%.1fM", val / 1000000)
	elseif val >= 1000 then
		return string.format("%.1fK", val / 1000)
	else
		return tostring(val)
	end
end

local function formatTime(sec)
	sec = math.floor(sec or 0)
	local hrs = math.floor(sec / 3600)
	local mins = math.floor((sec % 3600) / 60)
	
	if hrs >= 1000 then
		return formatNumber(hrs) .. "h"
	elseif hrs > 0 then
		return string.format("%dh %02dm", hrs, mins)
	elseif mins > 0 then
		return string.format("%dm", mins)
	else
		return tostring(sec) .. "s"
	end
end

local boardConfigs = {
	{
		partName = "MostKills",
		stat = "TotalKills",
		store = killsStore,
		format = formatNumber
	},
	{
		partName = "MostPlaytime",
		stat = "Playtime",
		store = playtimeStore,
		format = formatTime
	},
	{
		partName = "MostWins",
		stat = "TotalWins",
		store = winsStore,
		format = formatNumber
	}
}

local function getPlayerStat(player, statName)
	if _G.GetPlayerData then
		local data = _G.GetPlayerData(player)
		if data and data[statName] then
			return tonumber(data[statName]) or 0
		end
	end
	
	local folder = player:FindFirstChild("DataFolder") or player:FindFirstChild("leaderstats")
	if folder then
		local valObj = folder:FindFirstChild(statName)
		if valObj and valObj:IsA("ValueBase") then
			return tonumber(valObj.Value) or 0
		end
	end

	return 0
end

local function getUsername(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	
	local success, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	
	if success and name then
		nameCache[userId] = name
	else
		nameCache[userId] = "User " .. tostring(userId)
	end

	return nameCache[userId]
end

local function getHeadshot(userId)
	if iconCache[userId] then
		return iconCache[userId]
	end
	
	local success, img = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
	end)
	
	if success and img then
		iconCache[userId] = img
	else
		iconCache[userId] = ""
	end

	return iconCache[userId]
end

local function savePlayerData(player)
	for _, config in ipairs(boardConfigs) do
		local statValue = getPlayerStat(player, config.stat)
		
		local ok, err = pcall(function()
			config.store:SetAsync(tostring(player.UserId), math.floor(statValue))
		end)
		
		if not ok then
			warn("[Leaderboards] Save failed for " .. player.Name .. " (" .. config.stat .. "): " .. tostring(err))
		end
	end
end

local function clearFrameEntries(scrollFrame, template)
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end
end

local function updateBoard(config)
	local boardPart = leaderboards:FindFirstChild(config.partName)
	if not boardPart then
		return
	end
	
	local gui = boardPart:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return
	end

	local mainFrame = gui:FindFirstChild("Frame")
	if not mainFrame then
		return
	end

	local scrollFrame = mainFrame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then
		return
	end
	
	local template = scrollFrame:FindFirstChild("Template")
	if not template then
		return
	end
	
	template.Visible = false
	
	clearFrameEntries(scrollFrame, template)
	
	local success, pages = pcall(function()
		return config.store:GetSortedAsync(false, maxEntries)
	end)
	
	local entries = {}
	
	if success and pages then
		local currentPage = pages:GetCurrentPage()
		for _, data in ipairs(currentPage) do
			table.insert(entries, {
				userId = tonumber(data.key),
				value = tonumber(data.value) or 0
			})
		end
	end
	
	if #entries == 0 then
		for _, player in ipairs(Players:GetPlayers()) do
			table.insert(entries, {
				userId = player.UserId,
				value = getPlayerStat(player, config.stat)
			})
		end
		table.sort(entries, function(a, b)
			return a.value > b.value
		end)
	end

	for rank, entryData in ipairs(entries) do
		if rank > maxEntries then
			break
		end
		
		local entry = template:Clone()
		entry.Name = "Rank_" .. rank
		entry.LayoutOrder = rank
		entry.Visible = true
		
		local pfp = entry:FindFirstChild("Pfp")
		if pfp then
			pfp.Image = getHeadshot(entryData.userId)
			local rankTxt = pfp:FindFirstChild("Rank")
			if rankTxt then
				rankTxt.Text = "#" .. rank
			end
		end
		
		local nameLabel = entry:FindFirstChild("Name")
		if nameLabel then
			nameLabel.Text = "@" .. getUsername(entryData.userId)
		end
		
		local amountLabel = entry:FindFirstChild("Amount")
		if amountLabel then
			amountLabel.Text = config.format(entryData.value)
		end
		
		entry.Parent = scrollFrame
	end
end

local function refreshAllBoards()
	for _, config in ipairs(boardConfigs) do
		updateBoard(config)
	end
end

local function saveAllPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	savePlayerData(player)
	nameCache[player.UserId] = nil
	iconCache[player.UserId] = nil
end)

game:BindToClose(function()
	saveAllPlayers()
end)

task.spawn(function()
	task.wait(3)
	
	while true do
		saveAllPlayers()
		refreshAllBoards()
		task.wait(refreshInterval)
	end
end)
