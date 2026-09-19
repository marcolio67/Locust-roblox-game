-- ============================================================
-- DoorManager (Script, ServerScriptService)
--
-- Riktiga svängande dörrar via ProximityPrompt, istället för att
-- bara göra dem osynliga/genomskinliga.
--
-- Hanterar bara lösa "Door"-Parts (en enda mesh/del). "Door"-Models
-- (t.ex. en dörr som är hopsatt av en separat Frame + Door-blad +
-- handtag) rörs INTE av det här skriptet - att rotera en hel sådan
-- Model flyttar med dörrkarmen och allt annat, vilket ser trasigt ut.
-- De dörrarna sköter sig antingen redan själva (kolla om de har ett
-- eget Script/ClickDetector) eller behöver fixas individuellt.
--
-- Antagande: dörrens bredd ligger längs dess egen lokala X-axel.
-- Det stämmer för de flesta dörr-assets, men om en specifik dörr
-- svänger åt fel håll (in i väggen) går det att fixa genom att
-- vända tecknet i "hingeLocalOffset", eller rotera dörr-delen 180
-- grader i Studio.
--
-- NOTE: EscapeExit-lås-logiken nedan (isEscapeDoor) matchar bara
-- BasePart-delar som heter "EscapeExit...". I det här projektet är
-- de faktiska escape-utgångarna Models (arkstrukturer med flera
-- delar), så den hanteras istället direkt av MapVoteHandler - den
-- här grenen är kvar här som stöd om ni någon gång bygger en
-- escape-utgång som är en enda enkel Part istället.
-- ============================================================

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local OPEN_ANGLE = math.rad(100)
local OPEN_TIME = 0.4
local AUTO_CLOSE = 4
local PROMPT_DISTANCE = 8

local function animate(setCFrame, hinge, localOffset, fromAngle, toAngle, duration)
	local startTime = os.clock()
	while true do
		local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
		local angle = fromAngle + (toAngle - fromAngle) * alpha
		setCFrame(hinge * CFrame.Angles(0, angle, 0) * CFrame.new(localOffset))
		if alpha >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end

local function setupDoor(host)
	if host:GetAttribute("DoorRigged") then return end
	if not host:IsA("BasePart") then return end

	local isEscapeDoor = string.find(host.Name, "EscapeExit") ~= nil

	host.Anchored = true
	host.CanCollide = false
	host:SetAttribute("DoorRigged", true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DoorPrompt"
	prompt.ActionText = "Open"
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = host

	-- gångjärnet sitter längs dörrens egna lokala X-axel (kanten)
	local hingeLocalOffset = Vector3.new(-host.Size.X / 2, 0, 0)
	local hinge = host.CFrame * CFrame.new(hingeLocalOffset)
	local localOffset = -hingeLocalOffset

	local function setCFrame(cf)
		host.CFrame = cf
	end

	local isOpen = false
	local busy = false

	local function toggleDoor()
		if busy then return end
		busy = true
		prompt.Enabled = false

		animate(setCFrame, hinge, localOffset, isOpen and OPEN_ANGLE or 0, isOpen and 0 or OPEN_ANGLE, OPEN_TIME)
		isOpen = not isOpen
		prompt.ActionText = isOpen and "Close" or "Open"
		prompt.Enabled = true
		busy = false

		if isOpen then
			task.delay(AUTO_CLOSE, function()
				if isOpen and not busy then
					busy = true
					animate(setCFrame, hinge, localOffset, OPEN_ANGLE, 0, OPEN_TIME)
					isOpen = false
					prompt.ActionText = "Open"
					busy = false
				end
			end)
		end
	end

	prompt.Triggered:Connect(toggleDoor)

	if isEscapeDoor then
		local function refreshLock()
			local open = Workspace:GetAttribute("EscapesOpen") == true
			if not busy then
				prompt.Enabled = open
			end
			prompt.ActionText = open and (isOpen and "Close" or "Open") or "Locked"
		end
		refreshLock()
		Workspace:GetAttributeChangedSignal("EscapesOpen"):Connect(refreshLock)
	end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
	if obj:IsA("BasePart") and (obj.Name == "Door" or string.find(obj.Name, "EscapeExit")) then
		setupDoor(obj)
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") and (obj.Name == "Door" or string.find(obj.Name, "EscapeExit")) then
		task.wait(0.5)
		setupDoor(obj)
	end
end)
