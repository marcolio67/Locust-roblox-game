-- ============================================================
-- MapVoteHandler (Script, i Workspace.MapVote) - KRASCH-SÄKRAD
-- ============================================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local votingStatus = Workspace:FindFirstChild("VotingStatus", true)

-- INSTÄLLNINGAR (Ändrad till 1 så du kan testa ensam och se att det startar!)
local MIN_PLAYERS_TO_START = 1  
local VOTE_COUNTDOWN = 5
local VOTE_TIME = 20            
local LOCUST_HOLD_TIME = 15     
local SURVIVAL_PHASE_TIME = 180 
local ESCAPE_PHASE_TIME = 60    

local LOCUST_SPEED = 24
local SURVIVOR_SPEED = 16
local LOCUST_SCALE = 1.35 

local GLOBAL_HOLD_BOX_NAME = "LocustHoldBox"
local RELEASE_POINT_BASE_NAME = "LocustReleasePoint"

local canVote = false
local roundMaps = { "Carnival", "Neighborhood" } 
local lastLocust = nil 

local escapedPlayers = {}
local escapesAreOpen = false
local votes = { Map1 = {}, Map2 = {} }
local survivorStates = {} -- Player -> "alive" | "dead" | "escaped"

Players.CharacterAutoLoads = false

local function countActiveSurvivors()
	local count = 0
	for _, state in pairs(survivorStates) do
		if state == "alive" then count += 1 end
	end
	return count
end

local function countTotalSurvivors()
	local count = 0
	for _ in pairs(survivorStates) do count += 1 end
	return count
end

local function setEscapesOpen(value)
	escapesAreOpen = value
	Workspace:SetAttribute("EscapesOpen", value) -- låter DoorManager låsa upp escape-dörrarna
end

-- ---------- Hjälpfunktioner ----------

local function updateBoardsText(carnivalVotes, neighborhoodVotes)
	for _, board in ipairs(Workspace:GetDescendants()) do
		if board:IsA("BasePart") then
			if board.Name == "Map1" then
				local label = board:FindFirstChildWhichIsA("TextLabel", true)
				if label then label.Text = "Carnival\nVotes: " .. carnivalVotes end
			elseif board.Name == "Map2" then
				local label = board:FindFirstChildWhichIsA("TextLabel", true)
				if label then label.Text = "Neighborhood\nVotes: " .. neighborhoodVotes end
			end
		end
	end
end

local function updateStatusText(text)
	if votingStatus then
		local label = votingStatus:FindFirstChildWhichIsA("TextLabel", true)
		if label then label.Text = text end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			local roundGui = playerGui:FindFirstChild("RoundGui")
			if roundGui then
				local timerLabel = roundGui:FindFirstChild("TimerText", true)
				if timerLabel then
					timerLabel.Text = text
				end
			end
		end
	end
end

local function teleportTo(player, part)
	if not player or not part then return end
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		task.wait(0.1)
		hrp.CFrame = part.CFrame + Vector3.new(0, 4, 0)
	end
end

local function findPartDirect(mapName, partBaseName)
	local targetName = partBaseName .. mapName
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == targetName then
			return part
		end
	end
	return nil
end

local function resetBoardsAndPads()
	votes.Map1 = {}
	votes.Map2 = {}
	updateBoardsText(0, 0)
end

local function chooseKiller()
	local players = Players:GetPlayers()
	if #players == 0 then return nil end
	if #players == 1 then return players[1] end

	local candidates = {}
	for _, player in ipairs(players) do
		if player ~= lastLocust then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then candidates = players end

	return candidates[math.random(#candidates)]
end

local function spawnSurvivorsDirect(mapName, locust)
	local survivors = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= locust then
			table.insert(survivors, player)
		end
	end
	if #survivors == 0 then return end -- Om man testar själv finns inga survivors, skippa bara

	local spawnPoints = {}
	local targetSpawnName = "PlayerSpawn" .. mapName
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and string.find(part.Name, targetSpawnName) then
			table.insert(spawnPoints, part)
		end
	end

	if #spawnPoints == 0 then
		updateStatusText("ERROR: Missing " .. targetSpawnName)
		task.wait(3)
		return
	end

	for i = #spawnPoints, 2, -1 do
		local j = math.random(i)
		spawnPoints[i], spawnPoints[j] = spawnPoints[j], spawnPoints[i]
	end

	for i, player in ipairs(survivors) do
		local spawnPart = spawnPoints[((i - 1) % #spawnPoints) + 1]
		teleportTo(player, spawnPart)
	end
end

local function morphToLocust(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	local bodyHeight = humanoid:FindFirstChild("BodyHeightScale")
	local bodyWidth = humanoid:FindFirstChild("BodyWidthScale")
	local bodyDepth = humanoid:FindFirstChild("BodyDepthScale")
	local headScale = humanoid:FindFirstChild("HeadScale")

	if bodyHeight then bodyHeight.Value = LOCUST_SCALE end
	if bodyWidth then bodyWidth.Value = LOCUST_SCALE end
	if bodyDepth then bodyDepth.Value = LOCUST_SCALE end
	if headScale then headScale.Value = LOCUST_SCALE end

	local template = ServerStorage:FindFirstChild("LocustMorph")
	if template then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("CharacterMesh") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Accessory") then
				item:Destroy()
			end
		end
		for _, item in ipairs(template:GetChildren()) do
			if item:IsA("CharacterMesh") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("Accessory") then
				item:Clone().Parent = character
			end
		end
	else
		-- Ingen egen LocustMorph uppsatt än – färga karaktären mörk/neon som en enkel fallback
		for _, desc in ipairs(character:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Color = Color3.new(0.1, 0.1, 0.2)
				desc.Material = Enum.Material.Neon
			end
		end

		local head = character:FindFirstChild("Head")
		if head then
			head.Color = Color3.new(0.9, 0, 0)
			head.Material = Enum.Material.Neon

			for side = -1, 1, 2 do
				local eye = Instance.new("Part")
				eye.Name = (side == -1 and "Left" or "Right") .. "Eye"
				eye.Size = Vector3.new(0.3, 0.3, 0.3)
				eye.Color = Color3.new(1, 0, 0)
				eye.Material = Enum.Material.Neon
				eye.CanCollide = false
				eye.CFrame = head.CFrame * CFrame.new(0, 0, side * 0.4)
				eye.Parent = head

				local weld = Instance.new("Weld")
				weld.Part0 = head
				weld.Part1 = eye
				weld.C0 = CFrame.new(0, 0, side * 0.4)
				weld.Parent = head
			end
		end
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local light = Instance.new("PointLight")
		light.Name = "LocustRedLight"
		light.Color = Color3.fromRGB(255, 0, 0)
		light.Range = 20
		light.Brightness = 5
		light.Parent = hrp
	end

	local gun = ServerStorage:FindFirstChild("HyperlaserGun")
	if gun then
		gun:Clone().Parent = player.Backpack
	end
end

local function teleportAllToCabins()
	local cabinSpawns = {}
	for cabinIndex = 1, 12 do
		local spawnName = (cabinIndex == 1) and "Spawn" or ("Spawn" .. cabinIndex)
		local spawnPart = Workspace:FindFirstChild(spawnName) or Workspace:FindFirstChild(spawnName, true)
		if spawnPart and spawnPart:IsA("BasePart") then
			cabinSpawns[cabinIndex] = spawnPart
		end
	end

	for idx, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("IsLocust", nil)
		player:LoadCharacter() 

		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart", 5)

		local targetCabin = cabinSpawns[idx]
		if targetCabin then
			teleportTo(player, targetCabin)
		else
			teleportTo(player, cabinSpawns[1])
		end
	end
end

-- ---------- Röstdetektor ----------

local function registerVote(player, padName)
	if not canVote then return end
	for mapKey, playerList in pairs(votes) do
		for i = #playerList, 1, -1 do
			if playerList[i] == player then table.remove(playerList, i) end
		end
	end
	if padName == "MapVote1" then table.insert(votes.Map1, player)
	elseif padName == "MapVote2" then table.insert(votes.Map2, player) end
	updateBoardsText(#votes.Map1, #votes.Map2)
end

task.spawn(function()
	while true do
		for _, part in ipairs(Workspace:GetDescendants()) do
			if part:IsA("BasePart") and (part.Name == "MapVote1" or part.Name == "MapVote2") and not part:GetAttribute("Connected") then
				part:SetAttribute("Connected", true)
				part.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then registerVote(player, part.Name) end
				end)
			end
		end
		task.wait(2)
	end
end)

-- ---------- Escape-utgångar ----------
-- Sätt namnet "EscapeExit" (eller "EscapeExitCarnival"/"EscapeExitNeighborhood")
-- på en MODEL (t.ex. en hel port/arkstruktur) vid varje karta där overlevare kan fly ut.
-- Kopplar Touched på ALLA delar inuti utgångs-modellen.

task.spawn(function()
	while true do
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("Model") and string.find(obj.Name, "EscapeExit") and not obj:GetAttribute("EscapeConnected") then
				obj:SetAttribute("EscapeConnected", true)

				for _, part in ipairs(obj:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Touched:Connect(function(hit)
							if not escapesAreOpen then return end
							local player = Players:GetPlayerFromCharacter(hit.Parent)
							if not player then return end
							if survivorStates[player] == "alive" then
								survivorStates[player] = "escaped"
								table.insert(escapedPlayers, player)
								updateStatusText(player.Name .. " escaped!")

								local character = player.Character
								local hrp = character and character:FindFirstChild("HumanoidRootPart")
								if hrp then hrp.Anchored = true end -- fryser dem säkert tills rundan är slut
							end
						end)
					end
				end
			end
		end
		task.wait(2)
	end
end)

-- ---------- Spelare joinar / lämnar ----------

Players.PlayerAdded:Connect(function(player)
	-- OBS: teleportar INTE hit själv längre – det finns redan ett cabin-system
	-- (ForceCabinSpawn) som placerar spelaren i rätt cabin/spawn.
	-- Vi behöver bara se till att karaktären överhuvudtaget skapas, eftersom
	-- CharacterAutoLoads är avstängt.
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	-- om en overlevare lämnar mitt i rundan ska de inte räknas som "alive" för evigt,
	-- annars kan rundan aldrig ta slut
	if survivorStates[player] == "alive" then
		survivorStates[player] = "dead"
	end
end)

-- ---------- Huvudloop ----------

while true do
	canVote = false
	setEscapesOpen(false)
	escapedPlayers = {}
	resetBoardsAndPads()

	-- Kräver nu bara 1 spelare så loopen garanterat bryts direkt när du klickar på Play!
	while #Players:GetPlayers() < MIN_PLAYERS_TO_START do
		updateStatusText("Waiting for players...")
		task.wait(1)
	end

	for i = VOTE_COUNTDOWN, 0, -1 do
		updateStatusText("Voting will begin in " .. i .. " seconds")
		task.wait(1)
	end

	updateBoardsText(0, 0)
	updateStatusText("Vote for the map")

	canVote = true
	task.wait(VOTE_TIME)
	canVote = false

	local winningMapName = "Carnival"
	if #votes.Map2 > #votes.Map1 then winningMapName = "Neighborhood"
	elseif #votes.Map1 == #votes.Map2 then winningMapName = roundMaps[math.random(1, 2)] end

	updateStatusText(winningMapName .. " has been voted")
	task.wait(3)

	local locust = chooseKiller()
	if locust then
		lastLocust = locust

		survivorStates = {}

		for _, player in ipairs(Players:GetPlayers()) do
			local isLocust = (player == locust)
			player:SetAttribute("IsLocust", isLocust)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.WalkSpeed = isLocust and LOCUST_SPEED or SURVIVOR_SPEED end

			if not isLocust then
				survivorStates[player] = "alive"
				if humanoid then
					humanoid.Died:Connect(function()
						if survivorStates[player] == "alive" then
							survivorStates[player] = "dead"
						end
					end)
				end
			end
		end

		morphToLocust(locust)
		spawnSurvivorsDirect(winningMapName, locust)

		local holdBox = Workspace:FindFirstChild(GLOBAL_HOLD_BOX_NAME, true)
		if holdBox then
			teleportTo(locust, holdBox)
		else
			updateStatusText("ERROR: Missing LocustHoldBox!")
			task.wait(4)
		end

		for i = LOCUST_HOLD_TIME, 1, -1 do
			updateStatusText(i .. " seconds before locust release")
			task.wait(1)
		end

		updateStatusText("Locust Released!")
		task.wait(1)

		local releasePoint = findPartDirect(winningMapName, RELEASE_POINT_BASE_NAME)
		if releasePoint then
			teleportTo(locust, releasePoint)
		else
			updateStatusText("ERROR: Missing LocustReleasePoint" .. winningMapName)
			task.wait(4)
		end

		for i = SURVIVAL_PHASE_TIME, 1, -1 do
			if countTotalSurvivors() > 0 and countActiveSurvivors() == 0 then break end
			local minutes = math.floor(i / 60)
			local seconds = i % 60
			updateStatusText(string.format("Survive! Doors open in: %d:%02d", minutes, seconds))
			task.wait(1)
		end

		setEscapesOpen(true)
		updateStatusText("THE ESCAPES ARE OPEN!")
		task.wait(2)

		for i = ESCAPE_PHASE_TIME, 1, -1 do
			if countTotalSurvivors() > 0 and countActiveSurvivors() == 0 then break end
			updateStatusText(string.format("ESCAPE NOW! Time left: %02d seconds", i))
			task.wait(1)
		end

		setEscapesOpen(false)

		local escapedCount, deadCount = 0, 0
		for _, state in pairs(survivorStates) do
			if state == "escaped" then escapedCount += 1
			elseif state == "dead" then deadCount += 1 end
		end

		if countTotalSurvivors() > 0 and escapedCount == 0 and countActiveSurvivors() == 0 then
			updateStatusText("The Locust wins! No one escaped.")
		else
			updateStatusText(escapedCount .. " escaped, " .. deadCount .. " died.")
		end
		task.wait(4)

		teleportAllToCabins()
		task.wait(2)
	else
		updateStatusText("Error choosing killer")
		task.wait(5)
	end
end
