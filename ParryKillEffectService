local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = Shared:WaitForChild("Network"):WaitForChild("Remotes")
local ParryRequest = Remotes
	:WaitForChild("Parry")
	:WaitForChild("ParryRequest")
local ShopRemotes = Remotes:WaitForChild("Shop")
local OpenCrateUI = ShopRemotes:WaitForChild("OpenCrateUI")

local KillEffectConfig = require(
	Shared:WaitForChild("Configs"):WaitForChild("KillEffectConfig")
)

local Systems = script.Parent.Parent
local StateService = require(
	Systems:WaitForChild("Combat")
		:WaitForChild("Services")
		:WaitForChild("StateService")
)
local EffectVFX = require(script.Parent:WaitForChild("EffectVFX"))
local PhysicalKillEffects = require(
	script.Parent:WaitForChild("PhysicalKillEffects")
)
local ParryService = require(
	Systems:WaitForChild("Combat")
		:WaitForChild("Services")
		:WaitForChild("ParryService")
)

local PARRY_COOLDOWN = 6
local PARRY_FALLBACK_DURATION = 1.05
local PARRY_MIN_DURATION = 0.35
local PARRY_MAX_DURATION = 3
local PARRY_WALK_SPEED = 7
local parryUse = setmetatable({}, { __mode = "k" })

local function isInArena(player)
	local value = player:FindFirstChild("InArena")
	return value and value:IsA("BoolValue") and value.Value == true
end

local function getCharacterParts(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	return character, humanoid, root
end

local function playParrySound(root)
	local sfx = SoundService:FindFirstChild("SFX")
	local effectSounds = sfx and sfx:FindFirstChild("Effects")
	local template = effectSounds and effectSounds:FindFirstChild("Parry")
	if not template or not template:IsA("Sound") then
		return
	end

	local sound = template:Clone()
	sound.Parent = root
	sound:Play()
	Debris:AddItem(sound, 5)
end

local function getParryDuration(payload)
	local requested = typeof(payload) == "table"
		and tonumber(payload.Duration)
		or nil
	return math.clamp(
		requested or PARRY_FALLBACK_DURATION,
		PARRY_MIN_DURATION,
		PARRY_MAX_DURATION
	)
end

local function activateParry(player)
	if not isInArena(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	ParryService:Activate(character, {
		Duration = PARRY_FALLBACK_DURATION,
	})
end

ParryRequest.OnServerEvent:Connect(function(player)
	activateParry(player)
end)

local function effectCFrame(config, victimCharacter)
	local root = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	if config.Id == "GroundInferno" then
		return root.CFrame * CFrame.new(0, -2.6, 0)
	end
	return root.CFrame
end

_G.PlayKillEffect = function(killer, victimCharacter)
	if not killer or not victimCharacter then
		return false
	end

	local data = _G.GetPlayerData and _G.GetPlayerData(killer)
	local effectId = data and data.EquippedKillEffect
	local config = effectId and KillEffectConfig.Get(effectId)
	if not config then
		return false
	end

	if config.Physical == true
		and PhysicalKillEffects.Has(config.Id) then
		return PhysicalKillEffects.Play(
			config.Id,
			victimCharacter
		)
	end

	local targetCFrame = effectCFrame(config, victimCharacter)
	if not targetCFrame then
		return false
	end

	EffectVFX:Burst(config.Template, targetCFrame, {
		ActiveTime = config.Id == "GroundInferno" and 0.5 or 0.28,
		Lifetime = 3.5,
		Scale = config.Scale or 1,
		Color = config.Color,
		PartTransparency = 1,
		EmitAll = true,
		EmitScale = 1.15,
		MaxBrightness = 1.5,
		MaxLightEmission = 0.7,
		MaxLightBrightness = 2,
	})
	return true
end

local function setupCratePrompt()
	local map = workspace:FindFirstChild("Map")
	local lobby = map and map:FindFirstChild("Lobby")
	local gameplay = workspace:FindFirstChild("Gameplay")
	local interactives = gameplay and gameplay:FindFirstChild("Interactives")
	local crate = (lobby and lobby:FindFirstChild("KillEffectCrate", true))
		or (interactives and interactives:FindFirstChild("KillEffectCrate"))
	if not crate then
		return
	end

	local proximityPart = crate:FindFirstChild("Proximity", true)
	if not proximityPart then
		return
	end
	if not proximityPart:IsA("BasePart") then
		warn("[KillEffectService] KillEffectCrate.Proximity must be a BasePart.")
		return
	end

	proximityPart.Transparency = 1
	proximityPart.CanCollide = false
	proximityPart.CanTouch = false
	proximityPart.CanQuery = false

	local prompt = proximityPart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = proximityPart
	end

	prompt.Name = "KillEffectCratePrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Kill Effect Crate"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E

	prompt.Triggered:Connect(function(player)
		OpenCrateUI:FireClient(player)
	end)
end

task.spawn(setupCratePrompt)

Players.PlayerRemoving:Connect(function(player)
	parryUse[player] = nil
end)
