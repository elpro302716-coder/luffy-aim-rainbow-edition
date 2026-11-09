-- Server-authoritative practice systems for the owner's own experience.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local package = ReplicatedStorage:WaitForChild("LuffyAim")
local Config = require(package:WaitForChild("Config"))

local remotes = ReplicatedStorage:FindFirstChild("LuffyAimRemotes") or Instance.new("Folder")
remotes.Name = "LuffyAimRemotes"
remotes.Parent = ReplicatedStorage

local function remote(name)
    local obj = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
    obj.Name = name
    obj.Parent = remotes
    return obj
end

local Request = remote("Request")
local State = remote("State")
local Notice = remote("Notice")

local world = workspace:FindFirstChild("LuffyAimWorld") or Instance.new("Folder")
world.Name = "LuffyAimWorld"
world.Parent = workspace
local targets = world:FindFirstChild("Targets") or Instance.new("Folder")
targets.Name = "Targets"
targets.Parent = world
local pickups = world:FindFirstChild("TestPickups") or Instance.new("Folder")
pickups.Name = "TestPickups"
pickups.Parent = world

local store
if Config.EnableDataStore then
    store = DataStoreService:GetDataStore(Config.DataStoreName)
end

local data = {}
local lastAction = {}
local aimTimes = {}
local pickupLoopElapsed = 0

local function validPlayer(player)
    return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

local function characterParts(player)
    local character = player.Character
    if not character then return nil, nil end
    return character, character:FindFirstChild("HumanoidRootPart")
end

local function getData(player)
    if not data[player] then
        local inventory = {}
        for _, name in ipairs(Config.DemoInventory) do inventory[name] = 1 end
        data[player] = {
            walkSpeed = Config.Defaults.WalkSpeed,
            fly = false,
            autoCollect = false,
            coins = 0,
            score = 0,
            inventory = inventory,
            prefs = { Rainbow = true, UiScale = 1 },
            lastPickup = 0,
        }
    end
    return data[player]
end

local function sendState(player)
    local d = getData(player)
    State:FireClient(player, {
        WalkSpeed = d.walkSpeed, FlyEnabled = d.fly,
        AutoCollect = d.autoCollect, Coins = d.coins, Score = d.score,
        Rainbow = d.prefs.Rainbow, UiScale = d.prefs.UiScale,
    })
end

local function setSpeed(player, speed)
    local d = getData(player)
    speed = math.clamp(speed, Config.MinWalkSpeed, Config.MaxWalkSpeed)
    d.walkSpeed = speed
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.WalkSpeed = speed end
    sendState(player)
end

local function createTargets()
    if #targets:GetChildren() > 0 then return end
    for i = 1, Config.TargetCount do
        local angle = (i - 1) * (math.pi * 2 / Config.TargetCount)
        local part = Instance.new("Part")
        part.Name = "PracticeTarget_" .. i
        part.Shape = Enum.PartType.Ball
        part.Size = Vector3.new(3, 3, 3)
        part.Position = Vector3.new(math.cos(angle) * 18, 7 + (i % 2) * 3, math.sin(angle) * 18)
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromHSV(i / Config.TargetCount, 0.8, 1)
        part:SetAttribute("PracticeTarget", true)
        part.Parent = targets
    end
end
createTargets()

local function notify(player, message)
    Notice:FireClient(player, tostring(message))
end

local function rateLimit(player, action, delaySeconds)
    local now = os.clock()
    lastAction[player] = lastAction[player] or {}
    local previous = lastAction[player][action] or 0
    if now - previous < delaySeconds then return false end
    lastAction[player][action] = now
    return true
end

local function spawnPickup(player)
    local _, root = characterParts(player)
    if not root then return end
    local coin = Instance.new("Part")
    coin.Name = "TestCoin"
    coin.Shape = Enum.PartType.Ball
    coin.Size = Vector3.new(1.2, 1.2, 1.2)
    coin.Material = Enum.Material.Neon
    coin.Color = Color3.fromRGB(255, 220, 40)
    coin.Anchored = true
    coin.CanCollide = false
    coin.Position = root.Position + Config.PickupSpawnOffset
    coin:SetAttribute("TestPickup", true)
    coin.Parent = pickups
end

local function collectPickup(player, coin)
    local d = getData(player)
    local _, root = characterParts(player)
    if not root or not coin or not coin:IsDescendantOf(pickups) or coin:GetAttribute("TestPickup") ~= true then return false end
    if (root.Position - coin.Position).Magnitude > 12 then return false end
    if os.clock() - d.lastPickup < 0.2 then return false end
    d.lastPickup = os.clock()
    d.coins += Config.PickupValue
    coin:Destroy()
    sendState(player)
    notify(player, "+" .. Config.PickupValue .. " test coins")
    return true
end

local function savePrefs(player)
    if not store then return end
    local d = getData(player)
    local payload = { Rainbow = d.prefs.Rainbow, UiScale = d.prefs.UiScale }
    task.spawn(function()
        pcall(function() store:SetAsync(tostring(player.UserId), payload) end)
    end)
end

local function loadPrefs(player)
    if not store then return end
    local ok, saved = pcall(function() return store:GetAsync(tostring(player.UserId)) end)
    if ok and type(saved) == "table" then
        local d = getData(player)
        d.prefs.Rainbow = saved.Rainbow ~= false
        d.prefs.UiScale = math.clamp(tonumber(saved.UiScale) or 1, 0.85, 1.15)
    end
end

local function handle(player, action, payload)
    if not validPlayer(player) or type(action) ~= "string" then return end
    payload = type(payload) == "table" and payload or {}
    local d = getData(player)

    if action == "Init" then
        sendState(player)
    elseif action == "Speed" then
        if not rateLimit(player, action, 0.08) then return end
        local value = tonumber(payload.Value)
        if not value or value ~= value then return end
        setSpeed(player, value)
    elseif action == "Fly" then
        d.fly = payload.Enabled == true
        player:SetAttribute("LuffyAimFlyEnabled", d.fly)
        sendState(player)
    elseif action == "AutoCollect" then
        d.autoCollect = payload.Enabled == true
        sendState(player)
    elseif action == "SpawnCoin" then
        if not rateLimit(player, action, 0.5) then return end
        spawnPickup(player)
        notify(player, "Test coin spawned nearby")
    elseif action == "HitTarget" then
        local now = os.clock()
        if now - (aimTimes[player] or 0) < Config.AimRequestInterval then return end
        aimTimes[player] = now
        local target = targets:FindFirstChild(tostring(payload.TargetName or ""))
        local _, root = characterParts(player)
        if not root or not target or not target:IsA("BasePart") or target:GetAttribute("PracticeTarget") ~= true then return end
        if (root.Position - target.Position).Magnitude > Config.MaxPracticeDistance then return end
        d.score += 1
        sendState(player)
        notify(player, "Practice hit! Score: " .. d.score)
    elseif action == "Trade" then
        if not rateLimit(player, action, 1) then return end
        local kind = payload.Kind
        if kind == "ICE_TRADE" or kind == "HOT_TRADE" then
            local item = kind == "ICE_TRADE" and "Ice Fruit (Demo)" or "Hot Fruit (Demo)"
            if (d.inventory[item] or 0) < 1 then
                notify(player, "Trade refused: demo item is not in the sandbox inventory")
                return
            end
            d.inventory[item] -= 1
            notify(player, kind .. " demo validated; one demo item consumed")
        elseif kind == "DUPLICATE" then
            -- Intentionally does not copy or mutate inventory; this is only a demo outcome.
            notify(player, "DUPLICATE is a simulation only; inventory was not changed")
        else
            return
        end
        sendState(player)
    elseif action == "Prefs" then
        if type(payload.Rainbow) == "boolean" then d.prefs.Rainbow = payload.Rainbow end
        local scale = tonumber(payload.UiScale)
        if scale then d.prefs.UiScale = math.clamp(scale, 0.85, 1.15) end
        savePrefs(player)
        sendState(player)
    elseif action == "SavePrefs" then
        savePrefs(player)
        notify(player, store and "Preferences saved" or "Enable DataStore in Config to persist preferences")
    end
end
Request.OnServerEvent:Connect(handle)

Players.PlayerAdded:Connect(function(player)
    getData(player)
    loadPrefs(player)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.WalkSpeed = getData(player).walkSpeed
            humanoid.PlatformStand = false
        end
        player:SetAttribute("LuffyAimFlyEnabled", false)
        getData(player).fly = false
        task.delay(0.5, function() if player.Parent == Players then sendState(player) end end)
    end)
    task.defer(function() if player.Parent == Players then sendState(player) end end)
end)

Players.PlayerRemoving:Connect(function(player)
    savePrefs(player)
    data[player], lastAction[player], aimTimes[player] = nil, nil, nil
end)

RunService.Heartbeat:Connect(function(dt)
    pickupLoopElapsed += dt
    if pickupLoopElapsed < 0.2 then return end
    pickupLoopElapsed = 0
    for _, player in ipairs(Players:GetPlayers()) do
        local d = getData(player)
        if d.autoCollect then
            local _, root = characterParts(player)
            if root then
                for _, coin in ipairs(pickups:GetChildren()) do
                    if coin:IsA("BasePart") and (root.Position - coin.Position).Magnitude <= 10 then
                        collectPickup(player, coin)
                        break
                    end
                end
            end
        end
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    getData(player)
    task.defer(function() sendState(player) end)
end
