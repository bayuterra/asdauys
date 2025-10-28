-- 🎣 AutoFishing v9 (Manual Tap Button)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local VirtualUser = game:GetService("VirtualUser")
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

---------------------------------------------------------------------------------------------------
-- === Remote references ===
local net = ReplicatedStorage
	:WaitForChild("Packages")
	:WaitForChild("_Index")
	:WaitForChild("sleitnick_net@0.2.0")
	:WaitForChild("net")

local RE_Stop					= net:WaitForChild("RE/FishingStopped")
local RF_Manual					= net:WaitForChild("RF/UpdateAutoFishingState")
local RF_Cancel					= net:WaitForChild("RF/CancelFishingInputs")
local RF_Charge					= net:WaitForChild("RF/ChargeFishingRod")
local RF_Request				= net:WaitForChild("RF/RequestFishingMinigameStarted")
local RE_TextFX					= net:WaitForChild("RE/ReplicateTextEffect")
local RE_Complete				= net:WaitForChild("RE/FishingCompleted")
local RE_FishCaught				= net:WaitForChild("RE/FishCaught")
local RF_PurchaseWeatherEvent	= net:WaitForChild("RF/PurchaseWeatherEvent")
local RF_SellAllItems			= net:WaitForChild("RF/SellAllItems")
local RE_ishNotification		= net:WaitForChild("RE/ObtainedNewFishNotification")
local RE_BaitSpawned			= net:WaitForChild("RE/BaitSpawned")


---------------------------------------------------------------------------------------------------

-- === Config === 
local DelayBait = 1.7
local DelayReel = 0.5
local DelayInstan = 2
local lastCast = 0
local isCasting = false
local ActiveBait = 0
local MaxBait = 3
---------------------------------------------------------------------------------------------------


-- === State ===
local NotificationBlocker = false
local notificationConnection = nil
local AutoWeather = false
local AutoWeatherLoop = nil
local AutoSell = false
local ManualMode = false
local AutoClick = false
local AutoClickThread = nil
local InstanMode = false
local InstanStatus = false
local FastReel = false
local IsCasting = false
---------------------------------------------------------------------------------------------------

-- === Core Function
local function getRandomRequestArgs()
	local baseX, baseY = -0.9879989624023438, 0.5
	local randomX = baseX + (math.random(-500, 500) / 10000000)
	local time = workspace:GetServerTimeNow()
	return { randomX, baseY, time }
end

function RequestMinigame()
	task.spawn(function()
		local ok, result = pcall(function()
			return RF_Request:InvokeServer(unpack(getRandomRequestArgs()))
		end)

		if ok and result ~= true then
			if InstanMode then
				task.spawn(function()
					LemparUmpan()
				end)
			end
			if FastReel then
				ActiveBait -= 1
				LemparUmpan()
			end
		end
	end)
end

function LemparUmpan()
	if InstanMode then
		RF_Cancel:InvokeServer()
		RF_Charge:InvokeServer()
		task.wait(0.2)
		RequestMinigame()
	end
	if not FastReel then return end
	local now = tick()

	-- kalau masih nunggu delay, jangan lempar lagi
	if isCasting then
		print("⏱️ masih dalam delay, tunggu dulu...")
		return
	end

	-- kalau sudah mencapai limit umpan aktif, tahan dulu
	if ActiveBait >= MaxBait then
		print("🎣 slot penuh (" .. ActiveBait .. "/" .. MaxBait .. ")")
		return
	end

	isCasting = true
	lastCast = now
	ActiveBait += 1

	print(string.format("🎣 Lempar Umpan ke-%d (total aktif %d)", ActiveBait, ActiveBait))

	task.spawn(function()
		-- lempar logic server
		pcall(function()
			RF_Cancel:InvokeServer()
			RF_Charge:InvokeServer()
			task.wait(0.2)
			RequestMinigame()
		end)

		-- tunggu sesuai DelayBait sebelum boleh lempar lagi
		local totalDelay = DelayBait
		while tick() - lastCast < totalDelay do
			task.wait(0.05)
		end

		isCasting = false
		print(string.format("✅ Delay %.2fs selesai, boleh lempar lagi", totalDelay))
	end)
end

function NarikIkan()
	if InstanMode then
		local ok, result = pcall(function()
			return RE_Complete:FireServer()
		end)
	end
	--Fast Reel--
	if FastReel then
		local ok, result = pcall(function()
			return RE_Complete:FireServer()
		end)
	end
	-------------------
end
---------------------------------------------------------------------------------------------------


-- === INFO BAIT MUNCUL===
RE_BaitSpawned.OnClientEvent:Connect(function(data)
	local player = data
	if player ~= LocalPlayer then return end
	--Fast Reel--
	if FastReel then
		-- TotalBait = TotalBait + 1
		-- ActiveBait += 1
		-- if ActiveBait >= MaxBait then return end
		-- task.wait(DelayBait)
		-- LemparUmpan()
		-- FishStat = true
	end
	-------------------
end)
---------------------------------------------------------------------------------------------------

-- === TANDA SERU (EXCLAIM) ===
local lastExclaim = 0
local isWaiting = false
    
RE_TextFX.OnClientEvent:Connect(function(data)
	if data and data.TextData and data.TextData.EffectType == "Exclaim" then
		local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
		if head and data.Container == head then
			--Fast Reel--
			if FastReel then
				lastExclaim = tick()
				local totalDelay = DelayReel + 0.5
				if not isWaiting then
					isWaiting = true
					task.spawn(function()
						while tick() - lastExclaim < totalDelay do
							task.wait(0.05) -- cek tiap 0.05 detik
						end
						isWaiting = false
						print(string.format("⏱️ Delay %.2fs selesai, angkat ikan!", DelayReel))
						NarikIkan()
					end)
				else
					print("🔁 Reset delay karena tanda seru muncul lagi.")
				end
			end
			-------------------

			--Instan Mode--
			if InstanMode then
				task.spawn(function()
					task.wait(DelayInstan)
					NarikIkan()
				end)
			end
			-------------------

			--Manual Mode--
			if ManualMode then 
				StartAutoClicker()
			end
			-------------------
		end
	end
end)
---------------------------------------------------------------------------------------------------




-- === INFO FISHING STOP===
RE_Stop.OnClientEvent:Connect(function(data)
	print("FISHING STOP")
	--Fast Reel--
	if FastReel then
		ActiveBait = 0
		if not isCasting and ActiveBait < MaxBait then
				LemparUmpan()
		end
	end
	-------------------
	--Instan Mode--
	if InstanMode then
		LemparUmpan()
	end
	-------------------
	--Manual Mode--
	if AutoClick then
		StopAutoClicker()
	end
	-------------------
end)
---------------------------------------------------------------------------------------------------

-- === INFO IKAN NAIK===
RE_ishNotification.OnClientEvent:Connect(function(data)
	--Fast Reel--
	if FastReel then
		ActiveBait = 0
		if not isCasting and ActiveBait < MaxBait then
				LemparUmpan()
		end
	end
	-------------------
	--Instan Mode--
	if InstanMode then
		LemparUmpan()
	end
	-------------------
	--Manual Mode--
	if AutoClick then
		StopAutoClicker()
	end
	-------------------
end)
---------------------------------------------------------------------------------------------------

-- === IKAN NAIK (FishCaught) ===
RE_FishCaught.OnClientEvent:Connect(function(data)
	if FastReel then
		-- ActiveBait -= 1
		-- FishStat = false
	end
end)
---------------------------------------------------------------------------------------------------

-- ===  Animations Listening ===
local function ListenAnimations()
	animator.AnimationPlayed:Connect(function(track)
		if track.Name == "FishCaught" then
			-- if not FishStat then
			-- 	LemparUmpan()
			-- 	FishStat = true
			-- end
		end
		print("🎞️ Playing:", track.Name, track.Animation.AnimationId)
	end)
end
---------------------------------------------------------------------------------------------------


-- === Fast Reel ===
function fastReeler()
	-- if FastReel then
	-- 	LemparUmpan()
	-- end
		-- while FastReel do
		-- 	if ActiveBait < MaxBait then
		-- 		LemparUmpan()
		-- 	end
		-- 	task.wait(DelayBait) -- jeda antar lempar, tetap stabil
		-- end
		task.spawn(function()
		while FastReel do
			if not isCasting and ActiveBait < MaxBait then
				LemparUmpan()
			end
			task.wait(0.1)
		end
	end)
end
---------------------------------------------------------------------------------------------------

-- === Instan Mode ===
function instanFish()
	if InstanMode then 
		LemparUmpan()
	end
end
---------------------------------------------------------------------------------------------------

-- === Manual Mode ===
function StartAutoClicker()
	if AutoClick then return end
	AutoClick = true
	print("⚙️ AutoClicker START")

	AutoClickThread = task.spawn(function()
		while AutoClick do
			game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, nil, 0)
			game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, nil, 0)
			task.wait(0.01)
		end
	end)
end

function StopAutoClicker()
	if not AutoClick then return end
	AutoClick = false
	print("🛑 AutoClicker STOP")
end

local function ManualFishing()
	local args = { ManualMode }

	local ok, result = pcall(function()
		return RF_Manual:InvokeServer(unpack(args))
	end)
end
---------------------------------------------------------------------------------------------------

-- === Notification Ikan === 
local function removeNewFrame(parent)
	local display = parent:FindFirstChild("Display")
	if display then
		local newFrame = display:FindFirstChild("NewFrame")
		if newFrame then
			newFrame:Destroy()
			print("🗑️ SmallNotification > Display > NewFrame removed.")
		end
	end
end

local function enableNotificationBlock()
	if NotificationBlocker then return end
	NotificationBlocker = true
	print("🚫 Notification blocker ON")

	-- hapus semua existing
	for _, gui in pairs(PlayerGui:GetChildren()) do
		if gui.Name == "Small Notification" then
			removeNewFrame(gui)
		end
	end

	-- pasang listener
	notificationConnection = PlayerGui.ChildAdded:Connect(function(child)
		if not NotificationBlocker then return end
		if child.Name == "Small Notification" then
			task.wait(0.1)
			removeNewFrame(child)
		end
	end)
end
---------------------------------------------------------------------------------------------------


-- === Buy Weather
local WeatherList = {"Wind", "Cloudy", "Storm"}

local function AutoBuyWeather()
	if AutoWeatherLoop then return end -- biar gak double loop
	AutoWeather = true
	AutoWeatherLoop = task.spawn(function()
		local index = 1
		print("🌤️ AutoBuyWeather loop dimulai...")

		while AutoWeather do
			for i, name in ipairs(WeatherList) do
				RF_PurchaseWeatherEvent:InvokeServer(name)
				task.wait(1)
			end
			task.wait(30) -- biar gak ke-spam server
		end
		AutoWeatherLoop = nil
	end)
end
---------------------------------------------------------------------------------------------------


--- === Auto Sell ===
local function AutoSellLoop()
	task.spawn(function()
		while AutoSell do
			pcall(function()
				RF_SellAllItems:InvokeServer()
			end)
			task.wait(10)
		end
	end)
end
---------------------------------------------------------------------------------------------------



-- === Performance ===
local PerformanceModeActive = false

local LightingConnection = nil

local function ApplyPermanentLighting()
    if LightingConnection then LightingConnection:Disconnect() end
    
    LightingConnection = RunService.Heartbeat:Connect(function()
        Lighting.Brightness = 1
        Lighting.ClockTime = 20
    end)
end

local function RemoveFog()
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("Atmosphere") then
            effect.Density = 0
        end
    end
    
    RunService.Heartbeat:Connect(function()
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    end)
end

local function Enable8Bit()
    task.spawn(function()
        print("[8-Bit Mode] Enabling super smooth rendering...")
        
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
                obj.TopSurface = Enum.SurfaceType.Smooth
                obj.BottomSurface = Enum.SurfaceType.Smooth
            end
            if obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.TextureID = ""
                obj.CastShadow = false
                obj.RenderFidelity = Enum.RenderFidelity.Performance
            end
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
            if obj:IsA("SpecialMesh") then
                obj.TextureId = ""
            end
        end
        
        for _, effect in pairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then
                effect.Enabled = false
            end
        end
        
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        
        Workspace.DescendantAdded:Connect(function(obj)
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
                obj.TopSurface = Enum.SurfaceType.Smooth
                obj.BottomSurface = Enum.SurfaceType.Smooth
            end
            if obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.TextureID = ""
                obj.RenderFidelity = Enum.RenderFidelity.Performance
            end
            if obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            end
        end)

    end)
end

local function RemoveParticles()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
            obj:Destroy()
        end
    end
    
    Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
            obj:Destroy()
        end
    end)
end

local function RemoveSeaweed()
    for _, obj in pairs(Workspace:GetDescendants()) do
        local name = obj.Name:lower()
        if name:find("seaweed") or name:find("kelp") or name:find("coral") or name:find("plant") or name:find("weed") then
            pcall(function()
                if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                    obj:Destroy()
                end
            end)
        end
    end
    
    Workspace.DescendantAdded:Connect(function(obj)
        local name = obj.Name:lower()
        if name:find("seaweed") or name:find("kelp") or name:find("coral") or name:find("plant") or name:find("weed") then
            pcall(function()
                if obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart") then
                    task.wait(0.1)
                    obj:Destroy()
                end
            end)
        end
    end)
end

local function OptimizeWater()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Terrain") then
            obj.WaterReflectance = 0
            obj.WaterTransparency = 1
            obj.WaterWaveSize = 0
            obj.WaterWaveSpeed = 0
        end
        
        if obj:IsA("Part") or obj:IsA("MeshPart") then
            if obj.Material == Enum.Material.Water then
                obj.Reflectance = 0
                obj.Transparency = 0.8
            end
        end
    end
    
    RunService.Heartbeat:Connect(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Terrain") then
                obj.WaterReflectance = 0
                obj.WaterTransparency = 1
                obj.WaterWaveSize = 0
                obj.WaterWaveSpeed = 0
            end
        end
    end)
end

local function PerformanceMode()
    if PerformanceModeActive then return end
    
    PerformanceModeActive = true
    print("[PERFORMANCE MODE] Activating ultra performance...")
    
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    Lighting.Brightness = 1
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        end
        
        if obj:IsA("Terrain") then
            obj.WaterReflectance = 0
            obj.WaterTransparency = 0.9
            obj.WaterWaveSize = 0
            obj.WaterWaveSpeed = 0
        end
        
        if obj:IsA("Part") or obj:IsA("MeshPart") then
            if obj.Material == Enum.Material.Water then
                obj.Transparency = 0.9
                obj.Reflectance = 0
            end
            
            obj.Material = Enum.Material.SmoothPlastic
            obj.Reflectance = 0
            obj.CastShadow = false
        end
        
        if obj:IsA("Atmosphere") or obj:IsA("PostEffect") then
            obj:Destroy()
        end
    end
    
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    
    RunService.Heartbeat:Connect(function()
        if PerformanceModeActive then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end
    end)
    
    Workspace.DescendantAdded:Connect(function(obj)
        if PerformanceModeActive then
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
            
            if obj:IsA("Part") or obj:IsA("MeshPart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
            end
        end
    end)

	Enable8Bit()
	ApplyPermanentLighting()
	RemoveFog()
	RemoveParticles()
	RemoveSeaweed()
	OptimizeWater()
end
---------------------------------------------------------------------------------------------------





ListenAnimations()



print("✅ Final layout fix — tinggi aman, jarak pas, teks ada padding & toggle full in-frame.")


----------------------------------------------------------
-- 🎣 AutoFishing Tools UI + Floating X & Draggable Show/Hide
----------------------------------------------------------
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local gui = Instance.new("ScreenGui")
gui.Name = "FishingToolsUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

-- Responsive scale
local scale = Instance.new("UIScale", gui)
local function updateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	scale.Scale = (viewport.X < 360 and 0.3) or (viewport.X < 720 and 0.4) or(viewport.X < 1000 and 0.6) or (viewport.X < 1400 and 0.7) or 1
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

----------------------------------------------------------
-- FRAME UTAMA
----------------------------------------------------------
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0.32, 0, 0, 600)
frame.Position = UDim2.new(0.5, 0, 0.5, 0)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local layout = Instance.new("UIListLayout", frame)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)

local padding = Instance.new("UIPadding", frame)
padding.PaddingTop = UDim.new(0, 14)
padding.PaddingBottom = UDim.new(0, 14)
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)

----------------------------------------------------------
-- ❌ CLOSE BUTTON (offset keluar kanan atas)
----------------------------------------------------------
local closeBtn = Instance.new("TextButton")
closeBtn.Parent = gui
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(0.5, frame.AbsoluteSize.X / 2 + 10, 0.5, -frame.AbsoluteSize.Y / 2 - 10)
closeBtn.AnchorPoint = Vector2.new(0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
closeBtn.Text = "✖"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke", closeBtn)
stroke.Color = Color3.fromRGB(80, 80, 85)
stroke.Thickness = 1

closeBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
	closeBtn.Visible = false
end)

-- reposition tombol close otomatis kalau viewport berubah
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	closeBtn.Position = UDim2.new(0.5, frame.AbsoluteSize.X / 2 + 10, 0.5, -frame.AbsoluteSize.Y / 2 - 10)
end)

----------------------------------------------------------
-- TITLE
----------------------------------------------------------
local title = Instance.new("TextLabel")
title.Parent = frame
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "🎣 AutoFishing Tools"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.LayoutOrder = 1

----------------------------------------------------------
-- (semua fungsi & toggle dari kode lu tetap sama)
-- createCard(), createInput(), createToggle(), dan semua createToggle() di bawah sini
----------------------------------------------------------
-- (paste dari kode lu tanpa ubah)
----------------------------------------------------------
-- HELPER: Card Container
----------------------------------------------------------
local function createCard()
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 50) -- ⬅️ tinggi card sedikit lebih besar
	card.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Color3.fromRGB(65, 65, 70)
	stroke.Thickness = 1

	-- padding dalam card
	local innerPad = Instance.new("UIPadding")
	innerPad.Parent = card
	innerPad.PaddingLeft = UDim.new(0, 10)
	innerPad.PaddingRight = UDim.new(0, 10)

	return card
end

----------------------------------------------------------
-- INPUT FIELD
----------------------------------------------------------
local function createInput(labelText, defaultValue, layoutOrder, callback)
	local card = createCard()
	card.Parent = frame
	card.LayoutOrder = layoutOrder

	local lbl = Instance.new("TextLabel")
	lbl.Parent = card
	lbl.Text = labelText
	lbl.Size = UDim2.new(0.55, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	local box = Instance.new("TextBox")
	box.Parent = card
	box.Size = UDim2.new(0.35, 0, 0.75, 0)
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(0.95, 0, 0.5, 0)
	box.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.Text = tostring(defaultValue or "")
	box.Font = Enum.Font.GothamBold
	box.TextScaled = true
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local val = tonumber(box.Text)
		if val and val >= 0 then callback(val) end
	end)
end

createInput("🎣 Delay Bait", DelayBait, 2, function(val) DelayBait = val end)
createInput("🧵 Delay Reel", DelayReel, 3, function(val) DelayReel = val end)

----------------------------------------------------------
-- TOGGLE SWITCH (Clickable Card)
----------------------------------------------------------
local function createToggle(labelText, layoutOrder, defaultState, callback, oneWay)
	local card = createCard()
	card.Parent = frame
	card.LayoutOrder = layoutOrder

	-- Button overlay agar seluruh card bisa diklik
	local btnOverlay = Instance.new("TextButton")
	btnOverlay.Parent = card
	btnOverlay.BackgroundTransparency = 1
	btnOverlay.Size = UDim2.new(1, 0, 1, 0)
	btnOverlay.Text = ""

	local lbl = Instance.new("TextLabel")
	lbl.Parent = card
	lbl.Size = UDim2.new(0.75, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextScaled = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	local toggleBtn = Instance.new("Frame")
	toggleBtn.Parent = card
	toggleBtn.Size = UDim2.new(0, 50, 0, 28)
	toggleBtn.AnchorPoint = Vector2.new(1, 0.5)
	toggleBtn.Position = UDim2.new(0.95, 0, 0.5, 0)
	toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Parent = toggleBtn
	knob.Size = UDim2.new(0, 22, 0, 22)
	knob.Position = UDim2.new(0, 3, 0.5, 0)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = defaultState
	if state then
		toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
		knob.Position = UDim2.new(1, -25, 0.5, 0)
	end

	local toggling = false

	local function toggleState()
		if toggling then return end
		if oneWay and state then return end
		toggling = true

		state = not state

		-- jalanin animasi toggle dulu
		local goalPos = UDim2.new(state and 1 or 0, state and -25 or 3, 0.5, 0)
		local goalColor = state and Color3.fromRGB(0,180,80) or Color3.fromRGB(80,80,80)

		TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = goalPos}):Play()
		TweenService:Create(toggleBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = goalColor}):Play()

		-- kasih waktu sedikit buat tween kelihatan smooth
		task.wait(0.05)

		-- jalankan logic callback di thread terpisah supaya gak nge-block animasi
		task.spawn(function()
			local ok, err = pcall(function()
				callback(state)
			end)
			if not ok then warn("Toggle error:", err) end
		end)

		task.wait(0.1)
		toggling = false
	end

	-- 🟩 semua area bisa diklik
	btnOverlay.MouseButton1Click:Connect(toggleState)
	lbl.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then toggleState() end
	end)
	toggleBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then toggleState() end
	end)
end

----------------------------------------------------------
-- TOGGLES
----------------------------------------------------------
createToggle("⚡ Fast Reel", 4, false, function(s)
	FastReel = s
	if s then fastReeler() else RF_Cancel:InvokeServer() ActiveBait = 0 end
end)

-- HR Garis pembatas
local hr = Instance.new("Frame")
hr.Parent = frame
hr.Size = UDim2.new(1, 0, 0, 1)
hr.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
hr.BackgroundTransparency = 0.5
hr.LayoutOrder = 5

createToggle("⚡ Instan Mode", 6, false, function(s)
	InstanMode = s
	if s then instanFish() else RF_Cancel:InvokeServer() end
end)

createToggle("🎯 Manual Mode", 7, false, function(s)
	ManualMode = s
	ManualFishing()
end)

-- 🟩 one-way toggle ON only
createToggle("🐟 Fish Notification", 8, false, function(s)
	if s then enableNotificationBlock() end
end, true)

createToggle("🚀 Performance", 9, false, function(s)
	if s then PerformanceMode() end
end, true)

createToggle("🌦️ Auto Weather", 10, false, function(s)
	AutoWeather = s
	if s then AutoBuyWeather() end
end)

createToggle("💰 Auto Sell", 11, false, function(s)
	AutoSell = s
	if s then AutoSellLoop() end
end)
----------------------------------------------------------
-- 🎛️ FLOATING SHOW/HIDE BUTTON (fully draggable)
----------------------------------------------------------
local dragBtn = Instance.new("TextButton")
dragBtn.Parent = gui
dragBtn.Size = UDim2.new(0, 55, 0, 55)
dragBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
dragBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
dragBtn.Text = "🎣"
dragBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dragBtn.Font = Enum.Font.GothamBold
dragBtn.TextScaled = true
Instance.new("UICorner", dragBtn).CornerRadius = UDim.new(1, 0)
local dragStroke = Instance.new("UIStroke", dragBtn)
dragStroke.Color = Color3.fromRGB(70, 70, 75)
dragStroke.Thickness = 1

-- draggable logic
local dragging, dragInput, dragStart, startPos

local function update(input)
	local delta = input.Position - dragStart
	local newX = startPos.X.Offset + delta.X
	local newY = startPos.Y.Offset + delta.Y
	dragBtn.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
end

dragBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = dragBtn.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

dragBtn.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		update(input)
	end
end)

-- klik untuk show/hide
dragBtn.MouseButton1Click:Connect(function()
	local newState = not frame.Visible
	frame.Visible = newState
	closeBtn.Visible = newState
end)
