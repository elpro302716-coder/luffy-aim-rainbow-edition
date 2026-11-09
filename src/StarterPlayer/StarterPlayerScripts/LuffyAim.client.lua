-- Compact rainbow UI and local flight controller. All game-economy and scoring changes are server-side.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Config = require(ReplicatedStorage:WaitForChild("LuffyAim"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("LuffyAimRemotes")
local Request, State, Notice = remotes:WaitForChild("Request"), remotes:WaitForChild("State"), remotes:WaitForChild("Notice")

local state = { WalkSpeed = 16, FlyEnabled = false, HitboxEnabled = false, HitboxScale = 1, AutoCollect = false, Coins = 0, Score = 0, Rainbow = true, UiScale = 1 }
local connections, targetBoxes = {}, {}
local flight = { enabled = false, velocity = nil, attachment = nil }
local screen = Instance.new("ScreenGui")
screen.Name = "LuffyAimRainbow"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = playerGui

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local function make(className, props, parent)
    local o = Instance.new(className)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(obj, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, obj)
end
local function rainbowStroke(obj, thickness)
    local stroke = make("UIStroke", { Thickness = thickness or 2, Color = Color3.new(1,1,1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, obj)
    local grad = make("UIGradient", { Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,50,140)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255,190,40)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(50,255,190)),
        ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70,130,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(220,70,255)),
    }) }, stroke)
    task.spawn(function()
        while obj.Parent do
            TweenService:Create(grad, TweenInfo.new(3, Enum.EasingStyle.Linear), { Rotation = 360 }):Play()
            task.wait(3)
            grad.Rotation = 0
        end
    end)
end
local function button(parent, text, size, pos)
    local b = make("TextButton", { Size=size, Position=pos, BackgroundColor3=Color3.fromRGB(23,25,42), Text=text, TextColor3=Color3.new(1,1,1), TextSize=14, Font=Enum.Font.GothamBold, AutoButtonColor=true }, parent)
    corner(b, 9); rainbowStroke(b, 1.2)
    return b
end

local panel = make("Frame", { Name="Panel", Size=UDim2.fromOffset(330,390), Position=UDim2.new(0.04,0,0.18,0), BackgroundColor3=Color3.fromRGB(11,14,30), BackgroundTransparency=0.08, BorderSizePixel=0 }, screen)
panel.ClipsDescendants = true
corner(panel, 16); rainbowStroke(panel, 2)
make("UIGradient", { Rotation=35, Color=ColorSequence.new(Color3.fromRGB(17,18,42), Color3.fromRGB(33,12,48)) }, panel)
local bg = make("ImageLabel", { Name="Backdrop", Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Image=Config.BackgroundImage or "", ImageTransparency=0.76, ScaleType=Enum.ScaleType.Crop, ZIndex=0 }, panel)
local header = make("Frame", { Size=UDim2.new(1,0,0,48), BackgroundTransparency=1, Active=true }, panel)
local title = make("TextLabel", { Size=UDim2.new(1,-58,1,0), Position=UDim2.fromOffset(13,0), BackgroundTransparency=1, Text="LUFFY AIM  ✦  RAINBOW", TextColor3=Color3.new(1,1,1), TextSize=17, Font=Enum.Font.GothamBlack, TextXAlignment=Enum.TextXAlignment.Left }, header)
local close = button(header, "×", UDim2.fromOffset(34,32), UDim2.new(1,-42,0,8))
local tabs = make("Frame", { Size=UDim2.new(1,-16,0,34), Position=UDim2.fromOffset(8,50), BackgroundTransparency=1 }, panel)
local content = make("Frame", { Size=UDim2.new(1,-20,1,-132), Position=UDim2.fromOffset(10,90), BackgroundTransparency=1 }, panel)
local footer = make("TextLabel", { Size=UDim2.new(1,-20,0,28), Position=UDim2.new(0,10,1,-31), BackgroundTransparency=1, Text="Coins: 0    •    Aim score: 0", TextColor3=Color3.fromRGB(225,220,255), TextSize=12, Font=Enum.Font.GothamMedium }, panel)
local toast = make("TextLabel", { Size=UDim2.new(1,-20,0,22), Position=UDim2.new(0,10,1,-54), BackgroundTransparency=1, Text="", TextColor3=Color3.fromRGB(255,225,120), TextSize=12, Font=Enum.Font.GothamBold }, panel)

local floating = button(screen, "L", UDim2.fromOffset(58,58), UDim2.new(0.86,0,0.72,0))
floating.Name = "LuffyFloatingButton"
floating.TextSize = 23
floating.Font = Enum.Font.GothamBlack
corner(floating, 29)
local floatingLabel = make("TextLabel", { Size=UDim2.fromOffset(80,18), Position=UDim2.new(0.5,-40,1,0), BackgroundTransparency=1, Text="LUFFY", TextColor3=Color3.new(1,1,1), TextSize=11, Font=Enum.Font.GothamBlack }, floating)

local function clearContent()
    for _, child in ipairs(content:GetChildren()) do child:Destroy() end
end
local function row(text, y)
    return make("TextLabel", { Size=UDim2.new(1,-8,0,24), Position=UDim2.fromOffset(4,y), BackgroundTransparency=1, Text=text, TextColor3=Color3.fromRGB(245,242,255), TextSize=13, Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left }, content)
end
local function renderCombat()
    clearContent()
    row("Movement speed: " .. math.floor(state.WalkSpeed), 2)
    local minus = button(content,"−",UDim2.fromOffset(50,34),UDim2.fromOffset(5,30))
    local plus = button(content,"+",UDim2.fromOffset(50,34),UDim2.fromOffset(61,30))
    local normal = button(content,"NORMAL",UDim2.new(1,-122,0,34),UDim2.fromOffset(117,30))
    connect(minus.Activated,function() Request:FireServer("Speed",{Value=state.WalkSpeed-2}) end)
    connect(plus.Activated,function() Request:FireServer("Speed",{Value=state.WalkSpeed+2}) end)
    connect(normal.Activated,function() Request:FireServer("Speed",{Value=Config.DefaultWalkSpeed}) end)
    local fly = button(content,"FLY: "..(state.FlyEnabled and "ON" or "OFF"),UDim2.new(1,-8,0,36),UDim2.fromOffset(4,75))
    connect(fly.Activated,function() Request:FireServer("Fly",{Enabled=not state.FlyEnabled}) end)
    local hit = button(content,"TARGET OUTLINES: "..(state.HitboxEnabled and "ON" or "OFF"),UDim2.new(1,-8,0,36),UDim2.fromOffset(4,118))
    connect(hit.Activated,function() state.HitboxEnabled=not state.HitboxEnabled; updateTargetBoxes(); renderCombat() end)
    local size = button(content,"Outline size: "..string.format("%.1fx",state.HitboxScale),UDim2.new(1,-8,0,34),UDim2.fromOffset(4,161))
    connect(size.Activated,function() state.HitboxScale=state.HitboxScale%Config.MaxOutlineScale+0.5; if state.HitboxScale>Config.MaxOutlineScale then state.HitboxScale=1 end; updateTargetBoxes(); renderCombat() end)
    row("Outlines are visual only; gameplay hitboxes are unchanged.",205)
end
local function renderAim()
    clearContent()
    row("Click a glowing training target to score a practice hit.",3)
    row("Server validates target, distance, and request rate.",28)
    local resetInfo = button(content,"PRACTICE AREA",UDim2.new(1,-8,0,40),UDim2.fromOffset(4,68))
    connect(resetInfo.Activated,function() toast.Text="Targets are around the center of the test area." end)
end
local function renderFarm()
    clearContent()
    row("Test coins: "..state.Coins,4)
    local spawn = button(content,"SPAWN TEST COIN",UDim2.new(1,-8,0,38),UDim2.fromOffset(4,35))
    connect(spawn.Activated,function() Request:FireServer("SpawnCoin",{}) end)
    local auto = button(content,"AUTO-COLLECT: "..(state.AutoCollect and "ON" or "OFF"),UDim2.new(1,-8,0,38),UDim2.fromOffset(4,82))
    connect(auto.Activated,function() Request:FireServer("AutoCollect",{Enabled=not state.AutoCollect}) end)
    row("Only server-spawned test coins are collectible.",132)
end
local function renderTrade()
    clearContent()
    row("Sandbox inventory only — no real items are traded.",3)
    for i, info in ipairs({{"ICE TRADE","ICE_TRADE"},{"HOT TRADE","HOT_TRADE"},{"DUPLICATE (DEMO)","DUPLICATE"}}) do
        local b = button(content,info[1],UDim2.new(1,-8,0,38),UDim2.fromOffset(4,34+(i-1)*48))
        connect(b.Activated,function() Request:FireServer("Trade",{Kind=info[2]}) end)
    end
end
local function renderSettings()
    clearContent()
    local rainbow = button(content,"RAINBOW: "..(state.Rainbow and "ON" or "OFF"),UDim2.new(1,-8,0,38),UDim2.fromOffset(4,14))
    connect(rainbow.Activated,function() state.Rainbow=not state.Rainbow; Request:FireServer("Prefs",{Rainbow=state.Rainbow,UiScale=state.UiScale}); applyRainbow(); renderSettings() end)
    local scale = button(content,"UI SCALE: "..string.format("%.2f",state.UiScale),UDim2.new(1,-8,0,38),UDim2.fromOffset(4,62))
    connect(scale.Activated,function() state.UiScale=state.UiScale>=1.15 and 0.85 or state.UiScale+0.1; panel.Size=UDim2.fromOffset(330*state.UiScale,390*state.UiScale); Request:FireServer("Prefs",{Rainbow=state.Rainbow,UiScale=state.UiScale}); renderSettings() end)
    local save = button(content,"SAVE PREFERENCES",UDim2.new(1,-8,0,38),UDim2.fromOffset(4,110))
    connect(save.Activated,function() Request:FireServer("SavePrefs",{}) end)
    row("FPS cap/stretch are intentionally not forced; Roblox/device controls display scaling.",160)
end
local renderers = { COMBAT=renderCombat, AIM=renderAim, FARM=renderFarm, TRADE=renderTrade, SETTINGS=renderSettings }
local selected = "COMBAT"
local function selectTab(name)
    selected=name
    for _, c in ipairs(content:GetChildren()) do c:Destroy() end
    renderers[name]()
end
for i,name in ipairs({"COMBAT","AIM","FARM","TRADE","SETTINGS"}) do
    local tab=button(tabs,name,UDim2.new(0.2,-3,1,0),UDim2.new((i-1)*0.2,0,0,0))
    tab.TextSize=10
    connect(tab.Activated,function() selectTab(name) end)
end

function applyRainbow()
    local stroke=panel:FindFirstChildOfClass("UIStroke")
    if stroke then stroke.Enabled=state.Rainbow end
    title.TextColor3=state.Rainbow and Color3.new(1,1,1) or Color3.fromRGB(200,200,215)
end
local function updateTargetBoxes()
    local folder=workspace:FindFirstChild("LuffyAimWorld") and workspace.LuffyAimWorld:FindFirstChild("Targets")
    if not folder then return end
    for _, target in ipairs(folder:GetChildren()) do
        if target:IsA("BasePart") then
            local box=targetBoxes[target]
            if state.HitboxEnabled then
                if not box then box=Instance.new("SelectionBox"); box.Name="LuffyAimVisualOutline"; box.Adornee=target; box.Parent=target; targetBoxes[target]=box end
                box.LineThickness=0.04*state.HitboxScale
                box.Color3=Color3.fromHSV((os.clock()%4)/4,1,1)
                box.Visible=true
            elseif box then box:Destroy(); targetBoxes[target]=nil end
        end
    end
end
connect(RunService.RenderStepped,function()
    if state.HitboxEnabled then updateTargetBoxes() end
    for target, box in pairs(targetBoxes) do if not target.Parent then targetBoxes[target]=nil elseif box.Parent then box.Color3=Color3.fromHSV((os.clock()%4)/4,1,1) end end
end)

local function cleanupFlight()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if flight.velocity then flight.velocity:Destroy(); flight.velocity=nil end
    if flight.attachment then flight.attachment:Destroy(); flight.attachment=nil end
    if humanoid then humanoid.PlatformStand=false; humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
    if root then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z) end
    flight.enabled=false
end
local function setupFlight(enabled)
    if not enabled then cleanupFlight(); return end
    cleanupFlight()
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    flight.enabled=true
    humanoid.PlatformStand=false
    local att=Instance.new("Attachment"); att.Name="LuffyAimFlightAttachment"; att.Parent=root; flight.attachment=att
    local lv=Instance.new("LinearVelocity"); lv.Name="LuffyAimFlightVelocity"; lv.Attachment0=att; lv.RelativeTo=Enum.ActuatorRelativeTo.World; lv.MaxForce=1e6; lv.VectorVelocity=Vector3.zero; lv.Parent=root; flight.velocity=lv
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
end
connect(RunService.RenderStepped,function()
    if not flight.enabled or not flight.velocity then return end
    local camera=workspace.CurrentCamera
    local move=Vector3.zero
    local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then move=humanoid.MoveDirection end
    local vertical=0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA) then vertical+=1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonB) then vertical-=1 end
    if camera then
        local planar=Vector3.new(move.X,0,move.Z)
        flight.velocity.VectorVelocity=planar*Config.DefaultFlySpeed+Vector3.new(0,vertical*Config.DefaultFlySpeed,0)
    end
end)

local function hitTest(input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    if not panel.Visible or selected~="AIM" then return end
    local camera=workspace.CurrentCamera
    if not camera then return end
    local ray=camera:ViewportPointToRay(input.Position.X,input.Position.Y)
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include
    local folder=workspace:FindFirstChild("LuffyAimWorld") and workspace.LuffyAimWorld:FindFirstChild("Targets")
    if not folder then return end
    params.FilterDescendantsInstances={folder}
    local result=workspace:Raycast(ray.Origin,ray.Direction*500,params)
    if result and result.Instance then Request:FireServer("HitTarget",{TargetName=result.Instance.Name}) end
end
connect(UserInputService.InputBegan,hitTest)

-- Header and floating-button dragging supports mouse and touch.
local function makeDraggable(gui, handle)
    local dragging, inputObject, startPos, origin=false,nil,nil,nil
    connect(handle.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; inputObject=input; startPos=input.Position; origin=gui.Position
        end
    end)
    connect(handle.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    connect(UserInputService.InputChanged,function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-startPos
            gui.Position=UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,origin.Y.Scale,origin.Y.Offset+delta.Y)
        end
    end)
end
makeDraggable(panel,header)
makeDraggable(floating,floating)
connect(close.Activated,function() panel.Visible=false; floating.Visible=true end)
connect(floating.Activated,function() panel.Visible=true; floating.Visible=false end)
floating.Visible=false
connect(Notice.OnClientEvent,function(message) toast.Text=tostring(message); task.delay(2.5,function() if toast.Parent then toast.Text="" end end) end)
connect(State.OnClientEvent,function(serverState)
    for k,v in pairs(serverState) do if state[k]~=nil then state[k]=v end end
    footer.Text="Coins: "..state.Coins.."    •    Aim score: "..state.Score
    applyRainbow()
    selectTab(selected)
    setupFlight(state.FlyEnabled)
end)
connect(player.CharacterAdded,function() cleanupFlight(); if state.FlyEnabled then Request:FireServer("Fly",{Enabled=false}) end end)
connect(screen.Destroying,function() cleanupFlight(); for _,c in ipairs(connections) do c:Disconnect() end end)
selectTab(selected)
applyRainbow()
Request:FireServer("Init",{})
