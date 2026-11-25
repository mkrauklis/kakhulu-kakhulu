--[[
	MapBuilder -- builds the entire Kakhulu Kakhulu map from scratch every
	time the server starts: the grey baseplate, spawn, the 3x3 difficulty
	board, and all 9 obby stages (checkpoints + platforms + hazards).

	This is a Script (server-side), meant to live in ServerScriptService.
	It rebuilds workspace.KakhuluKakhuluMap from nothing on every run, so
	there's nothing to hand-place in Studio and re-running it (e.g. every
	Play-test) never leaves duplicate copies behind.
]]

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local workspace = workspace

-- Wipe and recreate the map folder so this script is safe to re-run.
local mapFolder = workspace:FindFirstChild("KakhuluKakhuluMap")
if mapFolder then mapFolder:Destroy() end
mapFolder = Instance.new("Folder")
mapFolder.Name = "KakhuluKakhuluMap"
mapFolder.Parent = workspace

local stagesFolder = Instance.new("Folder")
stagesFolder.Name = "Stages"
stagesFolder.Parent = mapFolder

local secretsFolder = Instance.new("Folder")
secretsFolder.Name = "Secrets"
secretsFolder.Parent = mapFolder

--============================== helpers ==============================--

local function createPart(size, cframe, color, material, anchored, canCollide, parent)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addBillboard(part, text, size, textColor)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(size or 8, 0, (size or 8) / 3, 0)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return gui
end

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

--========================== baseplate + spawn ==========================--

local BASEPLATE_SIZE = Vector3.new(400, 4, 400)
createPart(
	BASEPLATE_SIZE,
	CFrame.new(0, -2, 0),
	Color3.fromRGB(161, 161, 161),
	Enum.Material.Plastic,
	true, true, mapFolder
).Name = "Baseplate"

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.CFrame = CFrame.new(0, 0.5, 0)
spawnLocation.Color3 = Color3.fromRGB(80, 80, 80)
spawnLocation.Material = Enum.Material.SmoothPlastic
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Duration = 0
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.Parent = mapFolder

--========================= difficulty definitions =========================--

-- Colors follow the usual "chart obby" convention -- roughly green through
-- red through purple through black/white, with the joke top tier in
-- rainbow neon. Hazard strings are read by applyHazard() below.
local DIFFICULTIES = {
	{ name = "EASY", color = Color3.fromRGB(0, 200, 0), platformSize = 6, gap = 4, count = 6, hazard = "none" },
	{ name = "MEDIUM", color = Color3.fromRGB(230, 220, 0), platformSize = 5, gap = 5, count = 7, hazard = "none" },
	{ name = "HARD", color = Color3.fromRGB(255, 140, 0), platformSize = 4, gap = 6, count = 8, hazard = "slowMover" },
	{ name = "DIFFICULT", color = Color3.fromRGB(220, 0, 0), platformSize = 3.2, gap = 7, count = 9, hazard = "fastMover" },
	{ name = "WAY DIFICIL", color = Color3.fromRGB(40, 80, 230), platformSize = 2.6, gap = 7.5, count = 10, hazard = "disappear" },
	{ name = "EXTRA DIFFICULT", color = Color3.fromRGB(140, 0, 220), platformSize = 2.2, gap = 8, count = 11, hazard = "spinner" },
	{ name = "BRIDGE TO INSANITY", color = Color3.fromRGB(15, 15, 15), platformSize = 1.6, gap = 8.5, count = 12, hazard = "narrowBridge" },
	{ name = "MENTAL", color = Color3.fromRGB(245, 245, 245), platformSize = 1.2, gap = 9, count = 13, hazard = "strobe" },
	{ name = "YNNACNU", color = Color3.fromRGB(255, 0, 170), platformSize = 0.9, gap = 9.5, count = 15, hazard = "chaos" },
}

--============================ hazard behaviors ============================--
-- Each anchored platform can be animated by moving its .CFrame directly --
-- a player standing on an anchored part follows it when its CFrame moves,
-- same as any standard Roblox moving-platform setup.

local function makeMover(part, speed, distance)
	local axis = (math.random() < 0.5) and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	local info = TweenInfo.new(distance / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local goal = { CFrame = part.CFrame * CFrame.new(axis * distance) }
	local tween = TweenService:Create(part, info, goal)
	tween:Play()
end

local function makeDisappear(part, onTime, offTime)
	task.spawn(function()
		while part.Parent do
			part.Transparency = 0
			part.CanCollide = true
			task.wait(onTime)
			part.Transparency = 0.85
			part.CanCollide = false
			task.wait(offTime)
		end
	end)
end

local function makeSpinner(cframe, length, speed, parent)
	local bar = createPart(Vector3.new(length, 1, 1), cframe, Color3.fromRGB(90, 90, 90), Enum.Material.Metal, true, true, parent)
	bar.Name = "SpinnerHazard"
	task.spawn(function()
		while bar.Parent do
			bar.CFrame = bar.CFrame * CFrame.Angles(0, math.rad(speed), 0)
			task.wait()
		end
	end)
	return bar
end

local function applyHazard(part, hazard, parent)
	if hazard == "slowMover" then
		makeMover(part, 4, 6)
	elseif hazard == "fastMover" then
		makeMover(part, 8, 7)
	elseif hazard == "disappear" then
		makeDisappear(part, 2.0, 1.2)
	elseif hazard == "spinner" then
		makeSpinner(part.CFrame + Vector3.new(0, 3, 0), 10, 90, parent)
	elseif hazard == "narrowBridge" then
		if math.random() < 0.35 then makeSpinner(part.CFrame + Vector3.new(0, 3, 0), 8, 110, parent) end
	elseif hazard == "strobe" then
		if math.random() < 0.5 then makeDisappear(part, 1.1, 0.9) else makeMover(part, 9, 6) end
	elseif hazard == "chaos" then
		local roll = math.random()
		if roll < 0.34 then
			makeDisappear(part, 0.9, 0.7)
		elseif roll < 0.67 then
			makeMover(part, 11, 8)
		else
			makeSpinner(part.CFrame + Vector3.new(0, 3, 0), 9, 140, parent)
		end
	end
end

--============================ stage generator ============================--

local checkpointCFrames = {} -- [stageIndex] = CFrame, used by the board below

local function buildStage(stageIndex, def, startX, startY)
	local x, y, z = startX, startY, 0

	local checkpoint = createPart(Vector3.new(9, 1, 9), CFrame.new(x, y, z), def.color, Enum.Material.Neon, true, true, stagesFolder)
	checkpoint.Name = "Checkpoint_" .. stageIndex
	CollectionService:AddTag(checkpoint, "Checkpoint")
	checkpoint:SetAttribute("StageIndex", stageIndex)
	addBillboard(checkpoint, stageIndex .. ". " .. def.name, 14)
	checkpointCFrames[stageIndex] = checkpoint.CFrame

	-- A dim point light at every checkpoint on the darker top tiers, on
	-- theme with "MENTAL" / "YNNACNU" being meant to feel a little uncanny.
	if def.hazard == "strobe" or def.hazard == "chaos" then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 40, 40)
		light.Brightness = 1.5
		light.Range = 14
		light.Parent = checkpoint
	end

	x = x + def.gap
	for i = 1, def.count do
		local zJitter = (def.hazard == "none") and 0 or math.random(-2, 2)
		local yJitter = (def.hazard == "chaos" or def.hazard == "strobe") and math.random(-1, 1) or 0
		local length = (def.hazard == "narrowBridge") and (def.platformSize * 3) or def.platformSize
		local plat = createPart(
			Vector3.new(length, 1, def.platformSize),
			CFrame.new(x, y + yJitter, z + zJitter),
			def.color,
			Enum.Material.SmoothPlastic,
			true, true, stagesFolder
		)
		plat.Name = ("Stage%d_Plat%d"):format(stageIndex, i)
		applyHazard(plat, def.hazard, stagesFolder)
		x = x + def.gap
	end

	return x + 6 -- leaves a small landing gap before the next stage's checkpoint
end

local cursorX = 40
local cursorY = 8
for stageIndex, def in ipairs(DIFFICULTIES) do
	cursorX = buildStage(stageIndex, def, cursorX, cursorY)
	cursorY = cursorY + 2 -- the whole course climbs gently, stage to stage
end
local courseEndX = cursorX

-- A kill-void under the entire course -- fall off anything and you're sent
-- back to your last checkpoint (see CheckpointHandler.server.lua) rather
-- than stranded or falling forever.
local voidKill = createPart(
	Vector3.new(courseEndX + 60, 2, 200),
	CFrame.new((40 + courseEndX) / 2, -60, 0),
	Color3.fromRGB(10, 10, 10),
	Enum.Material.Neon,
	true, true, mapFolder
)
voidKill.Transparency = 1
voidKill.Name = "VoidKill"
voidKill.Touched:Connect(function(hit)
	local player = getPlayerFromHit(hit)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end)

--============================ difficulty board ============================--
-- A 3x3 grid of colored panels near spawn -- "the board with difficulties".
-- Touching a panel teleports you straight to that stage's checkpoint, so
-- the board doubles as both a difficulty chart and a stage-select menu.

local BOARD_CENTER = Vector3.new(0, 13, -25)
createPart(
	Vector3.new(26, 20, 1),
	CFrame.new(BOARD_CENTER.X, BOARD_CENTER.Y, BOARD_CENTER.Z - 0.6),
	Color3.fromRGB(40, 40, 40),
	Enum.Material.Slate,
	true, true, mapFolder
).Name = "BoardBackdrop"

local COLS, ROWS = 3, 3
local PANEL_SIZE = 7
local PANEL_GAP = 0.6
for i, def in ipairs(DIFFICULTIES) do
	local col = (i - 1) % COLS
	local row = math.floor((i - 1) / COLS)
	local px = BOARD_CENTER.X + (col - 1) * (PANEL_SIZE + PANEL_GAP)
	local py = BOARD_CENTER.Y + (1 - row) * (PANEL_SIZE + PANEL_GAP)
	local panel = createPart(
		Vector3.new(PANEL_SIZE, PANEL_SIZE, 0.5),
		CFrame.new(px, py, BOARD_CENTER.Z),
		def.color,
		Enum.Material.Neon,
		true, true, mapFolder
	)
	panel.Name = "BoardPanel_" .. i
	addBillboard(panel, i .. "\n" .. def.name, 7)
	CollectionService:AddTag(panel, "BoardPanel")
	panel:SetAttribute("StageIndex", i)

	panel.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		local character = player and player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local cframe = checkpointCFrames[i]
		if hrp and cframe then
			hrp.CFrame = cframe + Vector3.new(0, 4, 0)
		end
	end)
end

--================================ secrets ================================--
-- Five hidden badge pickups, tagged Secret1..Secret5 for
-- SecretBadges.server.lua to hook up. These spots are a starting point,
-- not a finished puzzle -- there's no way to verify "is this actually
-- hidden well" without eyes in Studio, so once you're in there, feel
-- free to relocate/bury them better (behind a wall, under a rock, etc.)
-- while keeping the Secret<N> tag and roughly this idea of "off the
-- direct, obvious path."

local function buildSecret(index, cframe)
	local secret = createPart(Vector3.new(2, 2, 2), cframe, Color3.fromRGB(255, 215, 0), Enum.Material.Neon, true, true, secretsFolder)
	secret.Name = "Secret_" .. index
	CollectionService:AddTag(secret, "Secret" .. index)
	addBillboard(secret, "Secret " .. index, 4, Color3.fromRGB(255, 230, 120))
	return secret
end

-- Secret 1: "PIXELATION", rated BRIDGE TO INSANITY -- not a part you walk
-- into like the other four. It's a single tiny black "pixel" floating
-- somewhere up in the sky, non-collidable, with no label (a billboard
-- would defeat the entire point of it being hidden) -- you have to
-- actually spot it against the sky and click it, which is why it uses a
-- ClickDetector instead of Touched (SecretBadges.server.lua checks for
-- that and hooks MouseClick instead). Colored to match BTI's own
-- near-black tier color on purpose.
local function buildSkyPixelSecret(index)
	local pixel = createPart(
		Vector3.new(0.4, 0.4, 0.4),
		CFrame.new(math.random(100, 450), math.random(500, 700), math.random(-150, 150)),
		Color3.fromRGB(0, 0, 0),
		Enum.Material.SmoothPlastic,
		true, false, secretsFolder
	)
	pixel.Name = "Secret_" .. index .. "_Pixelation"
	pixel.CastShadow = false
	CollectionService:AddTag(pixel, "Secret" .. index)
	pixel:SetAttribute("SecretName", "PIXELATION")
	pixel:SetAttribute("Difficulty", "BRIDGE TO INSANITY")

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 100000 -- it's hundreds of studs up; the default 32-stud range would make it unclickable from the ground
	detector.Parent = pixel

	return pixel
end

-- All of 2-5 sit at ground level or within an easy jump of somewhere the
-- player can actually already stand -- nothing requires clipping through
-- the solid baseplate or reaching an unsupported height with no path up.
buildSkyPixelSecret(1) -- "PIXELATION" (rated BRIDGE TO INSANITY) -- click the hidden black pixel in the sky
buildSecret(2, CFrame.new(60, 2, 14)) -- a short detour off to the side of EASY, down on the open ground
buildSecret(3, CFrame.new(140, 2, 30)) -- off to the side and back down at ground level, below where the course has climbed by then
buildSecret(4, CFrame.new(400, 2, -20)) -- another ground-level detour, out past the course's harder middle stretch
buildSecret(5, CFrame.new(courseEndX - 8, (cursorY - 2) + 3, 8)) -- a small jump sideways off the last stage, right near the end

print("Kakhulu Kakhulu: map built, " .. #DIFFICULTIES .. " stages, course ends around x=" .. courseEndX)
