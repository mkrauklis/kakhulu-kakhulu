--[[
	SecretBadges -- awards a real Roblox Badge when a player touches a
	part tagged Secret1..Secret5 (see MapBuilder.server.lua for where
	those are placed).

	IMPORTANT -- this is the one piece no script can set up for you:
	Roblox Badges have to be created first on your game's own Creator
	Dashboard (roblox.com -> Creator Dashboard -> Experience -> Badges ->
	Create a Badge), one per secret. Create 5, then paste each one's real
	numeric BadgeId into SECRET_BADGE_IDS below. Until you do, touching a
	secret just prints a warning in the server log instead of silently
	pretending to award something that doesn't exist.

	Also: BadgeService calls only work in Studio if "Enable Studio Access
	to API Services" is turned on (Home tab -> Game Settings -> Security),
	and the badges need to belong to this same game.
]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local SECRET_BADGE_IDS = {
	[1] = 0, -- TODO: replace with the real BadgeId for Secret 1
	[2] = 0, -- TODO: replace with the real BadgeId for Secret 2
	[3] = 0, -- TODO: replace with the real BadgeId for Secret 3
	[4] = 0, -- TODO: replace with the real BadgeId for Secret 4
	[5] = 0, -- TODO: replace with the real BadgeId for Secret 5
}

local awardedThisSession = {} -- [userId] = { [secretIndex] = true }

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function awardSecret(player, secretIndex)
	local badgeId = SECRET_BADGE_IDS[secretIndex]
	if not badgeId or badgeId == 0 then
		warn(("Secret %d found by %s, but SECRET_BADGE_IDS[%d] is still 0 -- create the badge on your Creator Dashboard and paste its id into SecretBadges.server.lua."):format(secretIndex, player.Name, secretIndex))
		return
	end

	awardedThisSession[player.UserId] = awardedThisSession[player.UserId] or {}
	if awardedThisSession[player.UserId][secretIndex] then return end
	awardedThisSession[player.UserId][secretIndex] = true

	local ok, result = pcall(function()
		return BadgeService:AwardBadge(player.UserId, badgeId)
	end)
	if ok and result then
		print(("Awarded badge %d (secret %d) to %s"):format(badgeId, secretIndex, player.Name))
	else
		warn(("BadgeService:AwardBadge failed for secret %d: %s"):format(secretIndex, tostring(result)))
	end
end

-- Most secrets are plain Touched pickups, but one (the sky pixel) is a
-- ClickDetector instead -- it's non-collidable and far overhead, so
-- there's nothing to touch. Checking for a ClickDetector child lets this
-- stay generic instead of hardcoding "secret 1 is special" here.
local function hookSecret(part, secretIndex)
	local clickDetector = part:FindFirstChildOfClass("ClickDetector")
	if clickDetector then
		clickDetector.MouseClick:Connect(function(player)
			awardSecret(player, secretIndex)
		end)
	else
		part.Touched:Connect(function(hit)
			local player = getPlayerFromHit(hit)
			if player then
				awardSecret(player, secretIndex)
			end
		end)
	end
end

for secretIndex = 1, 5 do
	local tagName = "Secret" .. secretIndex
	for _, part in ipairs(CollectionService:GetTagged(tagName)) do
		hookSecret(part, secretIndex)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(function(part)
		hookSecret(part, secretIndex)
	end)
end
