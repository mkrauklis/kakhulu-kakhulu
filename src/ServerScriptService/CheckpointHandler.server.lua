--[[
	CheckpointHandler -- generic, decoupled from MapBuilder on purpose: it
	just reacts to any part tagged "Checkpoint" (via CollectionService),
	so it doesn't care how or where the map script built them.

	- Touching a checkpoint remembers that spot for that player.
	- Dying respawns you back at your last remembered checkpoint instead
	  of all the way back at spawn.
	- Also tracks the furthest stage a player has reached, as a
	  "FurthestStage" attribute on the Player, in case you want a
	  leaderboard/UI to read it later.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local lastCheckpointCFrame = {} -- [userId] = CFrame

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function onCheckpointTouched(checkpoint, hit)
	local player = getPlayerFromHit(hit)
	if not player then return end

	lastCheckpointCFrame[player.UserId] = checkpoint.CFrame + Vector3.new(0, 3, 0)

	local stageIndex = checkpoint:GetAttribute("StageIndex")
	if stageIndex then
		local furthest = player:GetAttribute("FurthestStage") or 0
		if stageIndex > furthest then
			player:SetAttribute("FurthestStage", stageIndex)
		end
	end
end

local function hookCheckpoint(part)
	part.Touched:Connect(function(hit)
		onCheckpointTouched(part, hit)
	end)
end

for _, part in ipairs(CollectionService:GetTagged("Checkpoint")) do
	hookCheckpoint(part)
end
CollectionService:GetInstanceAddedSignal("Checkpoint"):Connect(hookCheckpoint)

-- Roblox already respawns a dead character automatically after a short
-- delay (no need to call Player:LoadCharacter() ourselves -- doing that
-- too would race the engine's own automatic respawn and risk a double
-- spawn). All this needs to do is reposition each new character at the
-- player's last checkpoint once it exists.
local function onCharacterAdded(player, character)
	local saved = lastCheckpointCFrame[player.UserId]
	if saved then
		local hrp = character:WaitForChild("HumanoidRootPart")
		hrp.CFrame = saved
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end)
