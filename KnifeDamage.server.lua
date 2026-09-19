-- ============================================================
-- KnifeDamage (Script, inside ServerStorage.Knife)
--
-- Melee weapon for the Locust. Kept for reference - the live
-- weapon in the current build is the HyperlaserGun instead, but
-- this still works if you switch back to a melee knife.
-- ============================================================

local Players = game:GetService("Players")

local tool = script.Parent
local COOLDOWN = 1
local RANGE = 6

local lastUse = 0

local function tryHit(player)
	local now = os.clock()
	if now - lastUse < COOLDOWN then return end
	lastUse = now

	local character = tool.Parent
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and not otherPlayer:GetAttribute("IsLocust") then
			local otherChar = otherPlayer.Character
			local otherHrp = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
			local humanoid = otherChar and otherChar:FindFirstChildOfClass("Humanoid")

			if otherHrp and humanoid and humanoid.Health > 0 then
				local offset = otherHrp.Position - hrp.Position
				local distance = offset.Magnitude

				if distance <= RANGE then
					local direction = offset.Unit
					local facing = hrp.CFrame.LookVector
					-- kräver att offret ligger ungefär framför Locust, inte rakt bakom
					if direction:Dot(facing) > 0.3 then
						humanoid.Health = 0
					end
				end
			end
		end
	end
end

tool.Activated:Connect(function()
	local character = tool.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end
	if not player:GetAttribute("IsLocust") then return end

	tryHit(player)
end)
