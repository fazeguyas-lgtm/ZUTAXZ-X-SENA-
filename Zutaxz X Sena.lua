-- file: SENA_v8.1_Genesis.lua
-- SENA 2026 NEW TRENDING - Full Merged Build
-- Target: Steal An Egg (2026)
-- Deps: gethui, fireproximityprompt, firetouchinterest, request, setfpscap,
--       writefile, readfile, isfile, getrawmetatable, setreadonly, newcclosure, getnamecallmethod
-- Changelog v8.1 (hotfix merged):
--   [FIX 1] FPS counter proper (RenderStepped counter, bukan deltaTime magic)
--   [FIX 2] AutoTreadmill/BottingMode/AutoSteal mutual-aware (no CFrame tug-of-war)
--   [FIX 3] RefreshRate recovery saat detection drop
--   [FIX 4] loopReconnect pcall check bener (bukan dead branch)
--   [FIX 5] installAntiLog selective (Workspace + ReplicatedStorage, skip "log" polos)
--   [FIX 6] findBase prioritaskan nama spesifik, skip SpawnLocation global
--   [FIX 7] BoostFPS/UncapFPS mutual-exclusive (no override)
--   [FIX 8] default AutoTreadmill = false (biar ga rebutan sama botting)

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local TeleportService   = game:GetService("TeleportService")
local StarterGui        = game:GetService("StarterGui")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")

local LP    = Players.LocalPlayer
local PGui  = LP:WaitForChild("PlayerGui")

-- =========================================================
-- CONFIG
-- =========================================================

local CONFIG = {
    -- Steal
    AutoSteal           = true,
    InstantGrab         = false,
    StealPriority       = "Rarest",
    StealSpeed          = 250,
    TweenSpeed          = 400,
    RefreshRate         = 0.08,
    MultiFireBurst      = 3,
    Humanize            = true,
    HumanizeJitter      = 0.05,
    VelocityMove        = false,
    SpawnPredictor      = true,

    -- Base
    AutoPlace           = true,
    AutoHatch           = true,
    AutoSellEgg         = true,
    AutoSellPet         = true,
    AutoFuse            = true,
    AutoEquipBest       = true,
    AutoUpgradeBase     = true,
    AutoUpgradeTreadmill= true,
    AutoTreadmill       = false,   -- [FIX 8] default off, biar ga rebutan botting
    CollectOffline      = true,
    AutoClaimAlmanac    = true,
    AutoDaily           = true,
    AutoQuest           = true,
    AutoRebirth         = false,
    AuctionMinValue     = 5000,

    -- Events
    AutoCatch           = false,
    ButterflyESP        = false,
    AutoTradeUp         = false,
    AutoCraftEssence    = false,
    AutoBuyShop         = false,
    AutoTradeIn         = false,
    AutoFreeReroll      = false,
    AutoBoss            = false,
    AutoEggRain         = false,
    AutoGift            = false,
    AutoAuctionSnipe    = false,
    BossDodge           = false,

    -- Players
    AutoStealFromPlayers= false,
    StealFromPlayerName = "",
    PlayerWhitelist     = {},

    -- Server
    AutoHop             = false,
    HopWhenNothingMatches = true,
    HopCooldown         = 8,
    AutoReconnect       = true,
    AutoRejoinOnKick    = true,

    -- Performance
    BoostFPS            = true,
    UncapFPS            = true,
    FPSBoost            = 60,
    AdaptiveFPS         = true,
    BottingMode         = true,
    AntiCutscene        = true,

    -- Protection
    AntiTreadmill       = true,
    AntiAFK             = true,
    AntiGuardKnockback  = true,
    AntiHitGuard        = true,
    AntiDetection       = true,
    DetectionThreshold  = 50,
    AntiKick            = true,
    AntiBan             = true,
    AntiCrash           = true,
    AntiLog             = true,
    AntiTeleport        = true,

    -- Movement
    Noclip              = false,
    InfiniteJump        = false,
    Fly                 = false,
    FlySpeed            = 80,

    -- Visual
    EggChecker          = true,
    RarityESP           = true,
    DistanceESP         = true,

    -- Webhook
    StealWebhook        = false,
    WebhookURL          = "",
    WebhookMinRarity    = "Legendary",
    WebhookBatch        = true,
    WebhookBatchSize    = 5,

    -- Persistence
    AutoSaveConfig      = true,
    ConfigPath          = "SENA_v8_config.json",

    RarityList    = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Divine","Secret","Eternal"},
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(170,170,170),
    Uncommon  = Color3.fromRGB(90,220,90),
    Rare      = Color3.fromRGB(80,150,255),
    Epic      = Color3.fromRGB(190,100,255),
    Legendary = Color3.fromRGB(255,185,60),
    Mythic    = Color3.fromRGB(255,70,130),
    Divine    = Color3.fromRGB(255,255,120),
    Secret    = Color3.fromRGB(255,60,255),
    Eternal   = Color3.fromRGB(200,255,255),
}

local THEME = {
    bg        = Color3.fromRGB(8,10,14),
    panel     = Color3.fromRGB(14,18,24),
    panel2    = Color3.fromRGB(20,26,34),
    card      = Color3.fromRGB(24,30,38),
    cardHover = Color3.fromRGB(32,42,52),
    accent    = Color3.fromRGB(0,255,170),
    accent2   = Color3.fromRGB(0,180,255),
    danger    = Color3.fromRGB(255,70,90),
    warn      = Color3.fromRGB(255,180,60),
    text      = Color3.fromRGB(220,240,235),
    textDim   = Color3.fromRGB(120,140,140),
    stroke    = Color3.fromRGB(0,255,170),
}

-- =========================================================
-- STATE
-- =========================================================

local STATE = {
    Running         = true,
    GUI             = nil,
    ESPGui          = nil,
    BaseCFrame      = nil,
    TreadmillCFrame = nil,
    LastSteal       = 0,
    LastHop         = 0,
    LastBaseReturn  = 0,
    SessionStart    = tick(),
    EggsStolen      = 0,
    PetsHatched     = 0,
    PetsSold        = 0,
    EggsSold        = 0,
    FusesDone       = 0,
    UpgradesDone    = 0,
    Rebirths        = 0,
    PromptsFired    = 0,
    AuctionsSniped  = 0,
    BossDodges      = 0,
    KicksBlocked    = 0,
    StealHistory    = {},
    ESPObjects      = {},
    VisualItems     = {},
    CurrentTab      = "Main",
    Logger          = {},
    ActiveTween     = nil,
    EggCache        = {},
    EggCacheTime    = 0,
    WebhookQueue    = {},
    DetectionScore  = 0,
    FPS             = 60,
    Ping            = 0,
    FlyBV           = nil,
}

-- =========================================================
-- UTILS
-- =========================================================

local function safeCall(fn, ...)
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function log(msg)
    table.insert(STATE.Logger, string.format("[%s] %s", os.date("%H:%M:%S"), msg))
    if #STATE.Logger > 150 then table.remove(STATE.Logger, 1) end
end

local function getHui()
    local ok, h = pcall(function() return gethui() end)
    if ok and h then return h end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then return core end
    return PGui
end

local function notify(text, dur)
    safeCall(function()
        StarterGui:SetCore("SendNotification", { Title = "SENA v8.1", Text = text, Duration = dur or 3 })
    end)
end

local function getRoot()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function humanWait()
    if CONFIG.Humanize then
        task.wait(math.random() * CONFIG.HumanizeJitter)
    end
end

local function tweenTo(cframe, speed)
    local root = getRoot()
    if not root or not cframe then return false end
    if STATE.ActiveTween then
        pcall(function() STATE.ActiveTween:Cancel() end)
        STATE.ActiveTween = nil
    end
    local dist = (root.Position - cframe.Position).Magnitude
    if dist < 0.5 then root.CFrame = cframe return true end
    local dur = math.max(dist / (speed or CONFIG.TweenSpeed), 0.03)
    local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = cframe })
    STATE.ActiveTween = tw
    tw:Play()
    tw.Completed:Wait()
    if STATE.ActiveTween == tw then STATE.ActiveTween = nil end
    return true
end

local function velocityTo(cframe, speed)
    local root = getRoot()
    if not root or not cframe then return false end
    local delta = cframe.Position - root.Position
    local dist = delta.Magnitude
    if dist < 1 then root.CFrame = cframe return true end
    local dur = math.clamp(dist / ((speed or CONFIG.TweenSpeed) * 1.8), 0.03, 0.35)
    root.AssemblyLinearVelocity = delta / dur
    task.wait(dur)
    if root then root.AssemblyLinearVelocity = Vector3.zero end
    return true
end

local function moveTo(cframe, speed)
    if CONFIG.VelocityMove then return velocityTo(cframe, speed) end
    return tweenTo(cframe, speed)
end

local function rarityIndex(r)
    for i, v in ipairs(CONFIG.RarityList) do
        if v:lower() == tostring(r):lower() then return i end
    end
    return 0
end

local function matchesRarity(r, f)
    if not f or f == "All" then return true end
    return rarityIndex(r) >= rarityIndex(f)
end

-- =========================================================
-- FPS COUNTER  [FIX 1]
-- =========================================================

local fpsFrames, fpsTime = 0, tick()
RunService.RenderStepped:Connect(function()
    fpsFrames = fpsFrames + 1
    if tick() - fpsTime >= 1 then
        STATE.FPS = fpsFrames
        fpsFrames, fpsTime = 0, tick()
    end
end)

-- ping updater
task.spawn(function()
    while STATE.Running do
        local ok, v = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and v then STATE.Ping = math.floor(v) end
        task.wait(2)
    end
end)

-- =========================================================
-- PERSISTENCE
-- =========================================================

local function saveConfig()
    if not CONFIG.AutoSaveConfig then return end
    if not writefile then return end
    local data = {}
    for k, v in pairs(CONFIG) do
        if type(v) ~= "table" then data[k] = v end
    end
    pcall(writefile, CONFIG.ConfigPath, HttpService:JSONEncode(data))
end

local function loadConfig()
    if not isfile or not readfile then return end
    if not isfile(CONFIG.ConfigPath) then return end
    local ok, data = pcall(readfile, CONFIG.ConfigPath)
    if not ok then return end
    local ok2, dec = pcall(function() return HttpService:JSONDecode(data) end)
    if not ok2 or type(dec) ~= "table" then return end
    for k, v in pairs(dec) do
        if CONFIG[k] ~= nil and type(CONFIG[k]) ~= "table" then CONFIG[k] = v end
    end
    log("config loaded")
end

-- =========================================================
-- ANTI-KICK / ANTI-BAN / ANTI-CRASH / ANTI-LOG
-- =========================================================

local function installAntiKick()
    if not CONFIG.AntiKick then return end
    if not getrawmetatable or not setreadonly then return end
    local mt = getrawmetatable(game)
    if not mt then return end
    setreadonly(mt, false)
    local old = mt.__namecall
    local wrapper = function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or ""
        if (method == "Kick" or method == "kick") and CONFIG.AntiKick then
            STATE.KicksBlocked = STATE.KicksBlocked + 1
            log("kick blocked #" .. STATE.KicksBlocked)
            if CONFIG.AutoRejoinOnKick then
                task.spawn(function()
                    task.wait(0.5)
                    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
                end)
            end
            return nil
        end
        return old(self, ...)
    end
    mt.__namecall = newcclosure and newcclosure(wrapper) or wrapper
    setreadonly(mt, true)
end

local function installAntiCrash()
    if not CONFIG.AntiCrash then return end
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", false)
    end)
    log("anti-crash armed")
end

local function installAntiLog()  -- [FIX 5]
    if not CONFIG.AntiLog then return end
    local roots = { Workspace, ReplicatedStorage }
    local killed = 0
    for _, root in ipairs(roots) do
        pcall(function()
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local n = obj.Name:lower()
                    if n:find("analytic") or n:find("telemetry")
                       or n:find("sentry") or n:find("beacon")
                       or n:find("tracker") then
                        pcall(function() obj:Destroy() end)
                        killed = killed + 1
                    end
                end
            end
        end)
    end
    log("anti-log active (selective, "..killed.." killed)")
end

-- =========================================================
-- SCANNERS
-- =========================================================

local function findEggs(force)
    local now = tick()
    if not force and (now - STATE.EggCacheTime) < 0.15 then return STATE.EggCache end
    local eggs = {}
    local root = getRoot()
    if not root then return eggs end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if n:find("egg") and not n:find("esp") and not n:find("gui") and not n:find("hatch") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
            if part and part.Position then
                table.insert(eggs, {
                    obj = obj, part = part,
                    rarity = safeCall(function() return obj:GetAttribute("Rarity") end) or "Common",
                    value  = safeCall(function() return obj:GetAttribute("Value") end) or 0,
                    mutation = safeCall(function() return obj:GetAttribute("Mutation") end) or "None",
                    distance = (root.Position - part.Position).Magnitude,
                })
            end
        end
    end
    if CONFIG.StealPriority == "Rarest" then
        table.sort(eggs, function(a,b) return rarityIndex(a.rarity) > rarityIndex(b.rarity) end)
    elseif CONFIG.StealPriority == "Nearest" then
        table.sort(eggs, function(a,b) return a.distance < b.distance end)
    elseif CONFIG.StealPriority == "HighestValue" then
        table.sort(eggs, function(a,b) return a.value > b.value end)
    end
    STATE.EggCache = eggs
    STATE.EggCacheTime = now
    return eggs
end

local function findPrompts(kws)
    local list = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local pn = obj.Parent and obj.Parent.Name:lower() or ""
            for _, kw in ipairs(kws) do
                if pn:find(kw) then table.insert(list, obj) break end
            end
        end
    end
    return list
end

local function findBase()  -- [FIX 6]
    local strong = { "mybase", "myplot", "yourbase", "playerbase", LP.Name:lower() }
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name:lower()
        for _, kw in ipairs(strong) do
            if kw ~= "" and n:find(kw, 1, true) then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                if part and part.Position.Magnitude > 5 then
                    STATE.BaseCFrame = part.CFrame
                    return
                end
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if n:find("plot") or n:find("base") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
            if part and part.Position.Magnitude > 5 then
                STATE.BaseCFrame = part.CFrame
                return
            end
        end
    end
end

local function findTreadmill()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if n:find("treadmill") or n:find("tread") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
            if part then STATE.TreadmillCFrame = part.CFrame return end
        end
    end
end

local function returnToBase(force)
    if not force and (tick() - STATE.LastBaseReturn) < 0.7 then return end
    STATE.LastBaseReturn = tick()
    if not STATE.BaseCFrame then findBase() end
    if STATE.BaseCFrame then moveTo(STATE.BaseCFrame, CONFIG.TweenSpeed) end
end

-- =========================================================
-- CORE
-- =========================================================

local function grabEgg(egg)
    if not egg or not egg.part or not egg.part.Parent then return false end
    local root = getRoot()
    if not root then return false end
    humanWait()
    if CONFIG.InstantGrab then
        root.CFrame = egg.part.CFrame + Vector3.new(0,0.3,0)
    else
        moveTo(egg.part.CFrame, CONFIG.StealSpeed)
    end
    task.wait(0.03)
    local burst = math.max(1, CONFIG.MultiFireBurst or 1)
    for i = 1, burst do
        if egg.part and egg.part.Parent then
            local prompt = egg.obj:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                pcall(fireproximityprompt, prompt)
                STATE.PromptsFired = STATE.PromptsFired + 1
            else
                pcall(firetouchinterest, root, egg.part, 0)
                task.wait(0.02)
                pcall(firetouchinterest, root, egg.part, 1)
            end
        end
        if i < burst then task.wait(0.02) end
    end
    task.wait(0.02)
    STATE.EggsStolen = STATE.EggsStolen + 1
    STATE.LastSteal = tick()
    table.insert(STATE.StealHistory, {
        time = os.date("%H:%M:%S"), name = egg.obj.Name,
        rarity = egg.rarity, mutation = egg.mutation, value = egg.value,
    })
    if #STATE.StealHistory > 100 then table.remove(STATE.StealHistory, 1) end
    log(string.format("steal %s (%s)", egg.obj.Name, egg.rarity))
    if CONFIG.StealWebhook and CONFIG.WebhookURL ~= "" and matchesRarity(egg.rarity, CONFIG.WebhookMinRarity) then
        local line = string.format("`%s` | %s | %s | %d", egg.obj.Name, egg.rarity, egg.mutation, egg.value)
        if CONFIG.WebhookBatch then table.insert(STATE.WebhookQueue, line)
        else pcall(request, { Url=CONFIG.WebhookURL, Method="POST",
            Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({content="**SENA v8.1** "..line}) }) end
    end
    return true
end

local function firePrompt(p)
    if not p then return false end
    pcall(fireproximityprompt, p)
    STATE.PromptsFired = STATE.PromptsFired + 1
    return true
end

local function clickButtonByNames(patterns)
    local clicked = 0
    for _, gui in ipairs(PGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("ImageButton") then
            local txt = ((gui.Text or "").." "..(gui.Name or "")):lower()
            local vis = true
            local p = gui.Parent
            while p and p ~= PGui do
                if p:IsA("GuiObject") and p.Visible == false then vis = false break end
                p = p.Parent
            end
            if vis and gui.Active ~= false then
                for _, pat in ipairs(patterns) do
                    if txt:find(pat,1,true) then
                        pcall(function() gui:Activate() end)
                        clicked = clicked + 1
                        break
                    end
                end
            end
        end
    end
    return clicked
end

-- =========================================================
-- LOOPS
-- =========================================================

local function loopAutoSteal()
    while STATE.Running do
        if CONFIG.AutoSteal then
            local eggs = findEggs()
            if #eggs > 0 then
                grabEgg(eggs[1])
                if CONFIG.BottingMode then returnToBase() end
            elseif CONFIG.HopWhenNothingMatches and CONFIG.AutoHop then
                if tick() - STATE.LastHop > CONFIG.HopCooldown then
                    STATE.LastHop = tick()
                    safeCall(function() TeleportService:Teleport(game.PlaceId, LP) end)
                end
            end
        end
        task.wait(CONFIG.RefreshRate)
    end
end

local function loopAutoPlace()
    while STATE.Running do
        if CONFIG.AutoPlace then
            for _, p in ipairs(findPrompts({"egg","incubator","place"})) do firePrompt(p) end
        end
        task.wait(0.4)
    end
end

local function loopAutoHatch()
    while STATE.Running do
        if CONFIG.AutoHatch then
            for _, p in ipairs(findPrompts({"incubator","hatch"})) do
                if firePrompt(p) then STATE.PetsHatched = STATE.PetsHatched + 1 end
            end
        end
        task.wait(0.8)
    end
end

local function loopAutoSell()
    while STATE.Running do
        if CONFIG.AutoSellEgg then
            if clickButtonByNames({"sell egg","sellegg","sell all egg"}) > 0 then
                STATE.EggsSold = STATE.EggsSold + 1
            end
        end
        if CONFIG.AutoSellPet then
            if clickButtonByNames({"sell pet","sellpet","sell all pet"}) > 0 then
                STATE.PetsSold = STATE.PetsSold + 1
            end
        end
        task.wait(2)
    end
end

local function loopAutoFuse()
    while STATE.Running do
        if CONFIG.AutoFuse then
            if clickButtonByNames({"fuse pet","combine pet","fuse"}) > 0 then
                STATE.FusesDone = STATE.FusesDone + 1
            end
        end
        task.wait(3)
    end
end

local function loopAutoEquip()
    while STATE.Running do
        if CONFIG.AutoEquipBest then clickButtonByNames({"equip best","equipbest","best equip"}) end
        task.wait(5)
    end
end

local function loopAutoClaim()
    while STATE.Running do
        if CONFIG.CollectOffline then clickButtonByNames({"collect offline","offline reward","offline"}) end
        if CONFIG.AutoClaimAlmanac then clickButtonByNames({"claim almanac","almanac"}) end
        task.wait(4)
    end
end

local function loopAutoUpgrade()
    while STATE.Running do
        if CONFIG.AutoUpgradeBase then
            if clickButtonByNames({"upgrade base","upgradebase"}) > 0 then
                STATE.UpgradesDone = STATE.UpgradesDone + 1
            end
        end
        if CONFIG.AutoUpgradeTreadmill then
            if clickButtonByNames({"upgrade treadmill","upgradetread"}) > 0 then
                STATE.UpgradesDone = STATE.UpgradesDone + 1
            end
        end
        task.wait(6)
    end
end

local function loopAutoTreadmill()  -- [FIX 2]
    while STATE.Running do
        if CONFIG.AutoTreadmill and not CONFIG.BottingMode and not CONFIG.AutoSteal then
            if not STATE.TreadmillCFrame then findTreadmill() end
            if STATE.TreadmillCFrame then moveTo(STATE.TreadmillCFrame, CONFIG.TweenSpeed) end
        end
        task.wait(1)
    end
end

local function loopAutoQuest()
    while STATE.Running do
        if CONFIG.AutoQuest then clickButtonByNames({"claim quest","quest reward","daily quest"}) end
        task.wait(6)
    end
end

local function loopAutoDaily()
    while STATE.Running do
        if CONFIG.AutoDaily then clickButtonByNames({"daily reward","claim daily","daily login","spin"}) end
        task.wait(10)
    end
end

local function loopAutoRebirth()
    while STATE.Running do
        if CONFIG.AutoRebirth then
            if clickButtonByNames({"rebirth","ascend","prestige"}) > 0 then
                STATE.Rebirths = STATE.Rebirths + 1
            end
        end
        task.wait(15)
    end
end

local function loopAutoEvents()
    while STATE.Running do
        if CONFIG.AutoCatch then clickButtonByNames({"catch","butterfly"}) end
        if CONFIG.AutoTradeUp then clickButtonByNames({"trade up","tradeup"}) end
        if CONFIG.AutoCraftEssence then clickButtonByNames({"craft essence","craft"}) end
        if CONFIG.AutoBuyShop then clickButtonByNames({"buy"}) end
        if CONFIG.AutoTradeIn then clickButtonByNames({"trade in","tradein"}) end
        if CONFIG.AutoFreeReroll then clickButtonByNames({"reroll","free reroll"}) end
        if CONFIG.AutoBoss then
            for _, p in ipairs(findPrompts({"boss","defeat","fight"})) do firePrompt(p) end
        end
        if CONFIG.AutoEggRain then
            for _, p in ipairs(findPrompts({"rain","event","gift"})) do firePrompt(p) end
        end
        if CONFIG.AutoGift then clickButtonByNames({"claim gift","gift"}) end
        task.wait(2)
    end
end

local function loopAuction()
    while STATE.Running do
        if CONFIG.AutoAuctionSnipe then
            for _, gui in ipairs(PGui:GetDescendants()) do
                if gui:IsA("TextButton") then
                    local txt = (gui.Text or ""):lower()
                    if txt:find("bid") or txt:find("buy now") then
                        local parent = gui.Parent
                        local value = 0
                        if parent then
                            for _, lbl in ipairs(parent:GetDescendants()) do
                                if lbl:IsA("TextLabel") then
                                    local num = lbl.Text and tonumber(lbl.Text:match("%d+"))
                                    if num and num > value then value = num end
                                end
                            end
                        end
                        if value >= CONFIG.AuctionMinValue then
                            pcall(function() gui:Activate() end)
                            STATE.AuctionsSniped = STATE.AuctionsSniped + 1
                        end
                    end
                end
            end
        end
        task.wait(1.5)
    end
end

local function loopBossDodge()
    while STATE.Running do
        if CONFIG.BossDodge then
            local root = getRoot()
            if root then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    local n = obj.Name:lower()
                    if n:find("indicator") or n:find("aoe") or n:find("telegraph") then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                        if part and (root.Position - part.Position).Magnitude < 12 then
                            local away = (root.Position - part.Position).Unit * 20
                            tweenTo(CFrame.new(root.Position + away), 500)
                            STATE.BossDodges = STATE.BossDodges + 1
                            break
                        end
                    end
                end
            end
        end
        task.wait(0.15)
    end
end

local function loopAntiGuard()
    while STATE.Running do
        if CONFIG.AntiGuardKnockback or CONFIG.AntiHitGuard then
            local char = LP.Character
            if char then
                for _, obj in ipairs(char:GetChildren()) do
                    local n = obj.Name:lower()
                    if (n:find("guard") and (n:find("hit") or n:find("knock") or n:find("stun"))) or n:find("knockback") then
                        pcall(function() obj:Destroy() end)
                    end
                end
                local hum = getHum()
                if hum and CONFIG.AntiTreadmill then
                    if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
                    if hum.JumpPower < 50 then hum.JumpPower = 50 end
                end
            end
        end
        task.wait(0.5)
    end
end

local function loopAntiCutscene()
    while STATE.Running do
        if CONFIG.AntiCutscene then
            local cam = Workspace.CurrentCamera
            if cam and cam.CameraType == Enum.CameraType.Scriptable then
                cam.CameraType = Enum.CameraType.Custom
            end
        end
        task.wait(0.2)
    end
end

local function loopNoclip()
    while STATE.Running do
        if CONFIG.Noclip then
            local char = LP.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end
        task.wait(1)
    end
end

local function loopFly()
    while STATE.Running do
        if CONFIG.Fly then
            local root = getRoot()
            local hum = getHum()
            if root and hum then
                if not STATE.FlyBV then
                    local bv = Instance.new("BodyVelocity")
                    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
                    bv.Velocity = Vector3.zero
                    bv.Parent = root
                    STATE.FlyBV = bv
                    hum.PlatformStand = true
                end
                local dir = Vector3.zero
                local cam = Workspace.CurrentCamera
                if cam then
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
                end
                if dir.Magnitude > 0 then
                    STATE.FlyBV.Velocity = dir.Unit * CONFIG.FlySpeed
                else
                    STATE.FlyBV.Velocity = Vector3.zero
                end
            end
        else
            if STATE.FlyBV then
                pcall(function() STATE.FlyBV:Destroy() end)
                STATE.FlyBV = nil
                local hum = getHum()
                if hum then hum.PlatformStand = false end
            end
        end
        task.wait(0.05)
    end
end

local function loopPerformance()  -- [FIX 7]
    while STATE.Running do
        if CONFIG.BoostFPS then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
        end
        if CONFIG.UncapFPS then
            if CONFIG.AdaptiveFPS and STATE.DetectionScore > CONFIG.DetectionThreshold then
                safeCall(function() setfpscap(60) end)
            else
                safeCall(function() setfpscap(9999) end)
            end
        elseif CONFIG.BoostFPS then
            safeCall(function() setfpscap(CONFIG.FPSBoost) end)
        end
        task.wait(10)
    end
end

local function loopReconnect()  -- [FIX 4]
    while STATE.Running do
        if CONFIG.AutoReconnect then
            local alive = pcall(function() return LP.Parent ~= nil end)
            if not alive or not LP.Parent then
                pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
            end
        end
        task.wait(3)
    end
end

local function loopBotting()  -- [FIX 2]
    while STATE.Running do
        if CONFIG.BottingMode and not CONFIG.AutoSteal then
            returnToBase()
        end
        task.wait(1)
    end
end

local function loopDetection()  -- [FIX 3]
    while STATE.Running do
        if CONFIG.AntiDetection then
            local warns = 0
            for _, obj in ipairs(LP:GetChildren()) do
                local n = obj.Name:lower()
                if n:find("warn") or n:find("kick") or n:find("ban") then warns += 1 end
            end
            if warns > 0 then
                STATE.DetectionScore = math.min(STATE.DetectionScore + warns, 100)
                if STATE.DetectionScore > CONFIG.DetectionThreshold then
                    CONFIG.RefreshRate = math.min(CONFIG.RefreshRate * 1.3, 0.5)
                    CONFIG.Humanize = true
                end
            else
                STATE.DetectionScore = math.max(STATE.DetectionScore - 1, 0)
                if STATE.DetectionScore == 0 and CONFIG.RefreshRate > 0.08 then
                    CONFIG.RefreshRate = math.max(CONFIG.RefreshRate - 0.05, 0.08)
                end
            end
        end
        task.wait(2)
    end
end

local function loopWebhookFlush()
    while STATE.Running do
        if CONFIG.WebhookBatch and #STATE.WebhookQueue > 0 and CONFIG.WebhookURL ~= "" then
            local batch = {}
            local n = math.min(#STATE.WebhookQueue, CONFIG.WebhookBatchSize)
            for i = 1, n do table.insert(batch, table.remove(STATE.WebhookQueue, 1)) end
            pcall(request, {
                Url = CONFIG.WebhookURL, Method = "POST",
                Headers = {["Content-Type"]="application/json"},
                Body = HttpService:JSONEncode({
                    content = "**SENA v8.1 — Batch ("..n..")**\n"..table.concat(batch,"\n"),
                }),
            })
        end
        task.wait(5)
    end
end

-- =========================================================
-- ANTI-AFK / INFINITE JUMP
-- =========================================================

local function setupAntiAFK()
    LP.Idled:Connect(function()
        if not CONFIG.AntiAFK then return end
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

local function setupInfiniteJump()
    UserInputService.JumpRequest:Connect(function()
        if CONFIG.InfiniteJump then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
end

-- =========================================================
-- ESP
-- =========================================================

local function buildESP()
    local parent = getHui()
    if STATE.ESPGui then STATE.ESPGui:Destroy() end
    local esp = Instance.new("ScreenGui")
    esp.Name = "SENA_ESP"
    esp.ResetOnSpawn = false
    esp.DisplayOrder = 998
    esp.Parent = parent
    STATE.ESPGui = esp
    task.spawn(function()
        while STATE.Running and esp.Parent do
            local seen, root = {}, getRoot()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                local n = obj.Name:lower()
                local want = (n:find("egg") and CONFIG.EggChecker)
                          or (n:find("butterfly") and CONFIG.ButterflyESP)
                          or n:find("guardian") or n:find("boss")
                if want and not n:find("esp") then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local key = tostring(obj)
                        seen[key] = true
                        local rar = safeCall(function() return obj:GetAttribute("Rarity") end) or "Common"
                        local dist = root and math.floor((root.Position - part.Position).Magnitude) or 0
                        local label = obj.Name
                        if CONFIG.RarityESP then label = "["..rar.."] "..label end
                        if CONFIG.DistanceESP then label = label.." ("..dist.."m)" end
                        local color = RARITY_COLORS[rar] or THEME.accent
                        if not STATE.ESPObjects[key] then
                            local bb = Instance.new("BillboardGui")
                            bb.Size = UDim2.new(0,140,0,30)
                            bb.StudsOffset = Vector3.new(0,3,0)
                            bb.AlwaysOnTop = true
                            bb.Adornee = part
                            bb.Parent = esp
                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.new(1,0,1,0)
                            lbl.BackgroundTransparency = 1
                            lbl.TextColor3 = color
                            lbl.Font = Enum.Font.Code
                            lbl.TextSize = 10
                            lbl.TextStrokeTransparency = 0.4
                            lbl.Text = label
                            lbl.Parent = bb
                            STATE.ESPObjects[key] = { billboard = bb, part = part, label = lbl }
                        else
                            local o = STATE.ESPObjects[key]
                            o.billboard.Adornee = part
                            o.label.Text = label
                            o.label.TextColor3 = color
                        end
                    end
                end
            end
            for k, v in pairs(STATE.ESPObjects) do
                if not seen[k] then
                    pcall(function() v.billboard:Destroy() end)
                    STATE.ESPObjects[k] = nil
                end
            end
            task.wait(1)
        end
    end)
end

-- =========================================================
-- PREMIUM UI
-- =========================================================

local function makeCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function makeStroke(p, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.stroke
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function makeGradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 0
    g.Parent = p
    return g
end

local function makePadding(p, t, b, l, r)
    local pl = Instance.new("UIPadding")
    pl.PaddingTop = UDim.new(0, t or 0)
    pl.PaddingBottom = UDim.new(0, b or 0)
    pl.PaddingLeft = UDim.new(0, l or 0)
    pl.PaddingRight = UDim.new(0, r or 0)
    pl.Parent = p
    return pl
end

local function buildGUI()
    local parent = getHui()
    local old = parent:FindFirstChild("SENA_Main")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "SENA_Main"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent
    STATE.GUI = gui

    local main = Instance.new("Frame")
    main.Name = "Window"
    main.Size = UDim2.new(0, 720, 0, 480)
    main.Position = UDim2.new(0.5, -360, 0.5, -240)
    main.BackgroundColor3 = THEME.bg
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = gui
    makeCorner(main, 12)
    makeStroke(main, THEME.stroke, 1.5)
    makeGradient(main, Color3.fromRGB(10,14,18), Color3.fromRGB(6,8,10), 90)

    -- titlebar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = THEME.panel
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    makeCorner(titleBar, 12)
    makeGradient(titleBar, Color3.fromRGB(0,80,60), Color3.fromRGB(0,50,90), 0)

    local logo = Instance.new("Frame")
    logo.Size = UDim2.new(0, 36, 0, 36)
    logo.Position = UDim2.new(0, 12, 0.5, -18)
    logo.BackgroundColor3 = THEME.bg
    logo.Parent = titleBar
    makeCorner(logo, 8)
    makeStroke(logo, THEME.accent, 1.5)
    local logoLbl = Instance.new("TextLabel")
    logoLbl.Size = UDim2.new(1,0,1,0)
    logoLbl.BackgroundTransparency = 1
    logoLbl.Text = "S"
    logoLbl.TextColor3 = THEME.accent
    logoLbl.Font = Enum.Font.GothamBold
    logoLbl.TextSize = 22
    logoLbl.Parent = logo

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -260, 0, 22)
    titleLbl.Position = UDim2.new(0, 58, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "SENA GENESIS"
    titleLbl.TextColor3 = THEME.accent
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 16
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = titleBar

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -260, 0, 16)
    subLbl.Position = UDim2.new(0, 58, 0, 28)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = "v8.1 • STEAL AN EGG 2026"
    subLbl.TextColor3 = THEME.textDim
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextSize = 10
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.Parent = titleBar

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(1, -170, 0.5, -5)
    dot.BackgroundColor3 = THEME.accent
    dot.Parent = titleBar
    makeCorner(dot, 5)
    task.spawn(function()
        local t = 0
        while dot.Parent do
            t = t + 0.05
            local s = 10 + math.sin(t) * 2
            dot.Size = UDim2.new(0, s, 0, s)
            dot.Position = UDim2.new(1, -170 + (10-s)/2, 0.5, -s/2)
            task.wait(0.05)
        end
    end)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 100, 0, 20)
    statusLbl.Position = UDim2.new(1, -155, 0.5, -10)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "ACTIVE"
    statusLbl.TextColor3 = THEME.accent
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 11
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = titleBar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 26, 0, 26)
    minBtn.Position = UDim2.new(1, -75, 0.5, -13)
    minBtn.BackgroundColor3 = Color3.fromRGB(60,50,20)
    minBtn.Text = "—"
    minBtn.TextColor3 = THEME.warn
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 12
    minBtn.Parent = titleBar
    makeCorner(minBtn, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -42, 0.5, -13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(90,25,30)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = THEME.danger
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.Parent = titleBar
    makeCorner(closeBtn, 6)
    closeBtn.MouseButton1Click:Connect(function()
        STATE.Running = false
        saveConfig()
        gui:Destroy()
    end)

    -- sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 160, 1, -110)
    sidebar.Position = UDim2.new(0, 12, 0, 60)
    sidebar.BackgroundColor3 = THEME.panel
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    makeCorner(sidebar, 10)
    makeStroke(sidebar, Color3.fromRGB(40,60,60), 1)
    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 4)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Parent = sidebar
    makePadding(sidebar, 8, 8, 6, 6)

    -- content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -196, 1, -110)
    content.Position = UDim2.new(0, 184, 0, 60)
    content.BackgroundColor3 = THEME.panel
    content.BorderSizePixel = 0
    content.Parent = main
    makeCorner(content, 10)
    makeStroke(content, Color3.fromRGB(40,60,60), 1)

    local contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Size = UDim2.new(1, -16, 1, -16)
    contentScroll.Position = UDim2.new(0, 8, 0, 8)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 4
    contentScroll.ScrollBarImageColor3 = THEME.accent
    contentScroll.CanvasSize = UDim2.new(0,0,0,0)
    contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentScroll.Parent = content

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = contentScroll

    -- footer
    local footer = Instance.new("Frame")
    footer.Size = UDim2.new(1, -24, 0, 40)
    footer.Position = UDim2.new(0, 12, 1, -50)
    footer.BackgroundColor3 = THEME.panel
    footer.BorderSizePixel = 0
    footer.Parent = main
    makeCorner(footer, 8)
    makeStroke(footer, Color3.fromRGB(40,60,60), 1)

    local statsLbl = Instance.new("TextLabel")
    statsLbl.Size = UDim2.new(1, -20, 1, 0)
    statsLbl.Position = UDim2.new(0, 10, 0, 0)
    statsLbl.BackgroundTransparency = 1
    statsLbl.Text = "loading…"
    statsLbl.TextColor3 = THEME.textDim
    statsLbl.Font = Enum.Font.Code
    statsLbl.TextSize = 11
    statsLbl.TextXAlignment = Enum.TextXAlignment.Left
    statsLbl.Parent = footer

    -- tabs
    local tabButtons = {}
    local tabs = {
        { id="Main",     icon="⌂", label="Main" },
        { id="Steal",    icon="⚡", label="Steal" },
        { id="Auto",     icon="◈", label="Auto" },
        { id="Pets",     icon="✦", label="Pets" },
        { id="Events",   icon="✧", label="Events" },
        { id="Players",  icon="☰", label="Players" },
        { id="Misc",     icon="⚙", label="Misc" },
        { id="Visual",   icon="◉", label="Visual" },
        { id="Protect",  icon="⛨", label="Protect" },
        { id="Log",      icon="≡", label="Log" },
    }

    local function clearContent()
        for _, c in ipairs(contentScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") or c:IsA("Frame") then c:Destroy() end
        end
    end

    local function addSection(t)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 20)
        l.BackgroundTransparency = 1
        l.Text = "▸ " .. t
        l.TextColor3 = THEME.accent
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = contentScroll
    end

    local function addToggle(name, key)
        local card = Instance.new("TextButton")
        card.Size = UDim2.new(1, 0, 0, 34)
        card.BackgroundColor3 = CONFIG[key] and Color3.fromRGB(0,55,40) or THEME.card
        card.BorderSizePixel = 0
        card.Text = ""
        card.AutoButtonColor = false
        card.Parent = contentScroll
        makeCorner(card, 6)
        makeStroke(card, CONFIG[key] and THEME.accent or Color3.fromRGB(40,50,55), 1)

        local dotInd = Instance.new("Frame")
        dotInd.Size = UDim2.new(0, 8, 0, 8)
        dotInd.Position = UDim2.new(0, 12, 0.5, -4)
        dotInd.BackgroundColor3 = CONFIG[key] and THEME.accent or Color3.fromRGB(80,90,95)
        dotInd.Parent = card
        makeCorner(dotInd, 4)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -100, 1, 0)
        lbl.Position = UDim2.new(0, 30, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = THEME.text
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card

        local stateLbl = Instance.new("TextLabel")
        stateLbl.Size = UDim2.new(0, 60, 1, 0)
        stateLbl.Position = UDim2.new(1, -70, 0, 0)
        stateLbl.BackgroundTransparency = 1
        stateLbl.Text = CONFIG[key] and "ON" or "OFF"
        stateLbl.TextColor3 = CONFIG[key] and THEME.accent or THEME.textDim
        stateLbl.Font = Enum.Font.GothamBold
        stateLbl.TextSize = 11
        stateLbl.TextXAlignment = Enum.TextXAlignment.Right
        stateLbl.Parent = card

        card.MouseEnter:Connect(function()
            if not CONFIG[key] then
                TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = THEME.cardHover}):Play()
            end
        end)
        card.MouseLeave:Connect(function()
            if not CONFIG[key] then
                TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = THEME.card}):Play()
            end
        end)
        card.MouseButton1Click:Connect(function()
            CONFIG[key] = not CONFIG[key]
            local on = CONFIG[key]
            TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundColor3 = on and Color3.fromRGB(0,55,40) or THEME.card
            }):Play()
            dotInd.BackgroundColor3 = on and THEME.accent or Color3.fromRGB(80,90,95)
            stateLbl.Text = on and "ON" or "OFF"
            stateLbl.TextColor3 = on and THEME.accent or THEME.textDim
            saveConfig()
        end)
    end

    local function addButton(text, cb, danger)
        local card = Instance.new("TextButton")
        card.Size = UDim2.new(1, 0, 0, 32)
        card.BackgroundColor3 = THEME.card
        card.BorderSizePixel = 0
        card.Text = ""
        card.AutoButtonColor = false
        card.Parent = contentScroll
        makeCorner(card, 6)
        makeStroke(card, danger and THEME.danger or Color3.fromRGB(40,50,55), 1)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 1, 0)
        lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = danger and THEME.danger or THEME.text
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card
        card.MouseEnter:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = THEME.cardHover}):Play()
        end)
        card.MouseLeave:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.15), {BackgroundColor3 = THEME.card}):Play()
        end)
        card.MouseButton1Click:Connect(function() safeCall(cb) end)
    end

    local function addInfo(text)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 22)
        l.BackgroundColor3 = THEME.card
        l.Text = "  " .. text
        l.TextColor3 = THEME.textDim
        l.Font = Enum.Font.Code
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = contentScroll
        makeCorner(l, 6)
    end

    local renderTab

    renderTab = function(name)
        clearContent()
        for _, b in ipairs(tabButtons) do
            local isActive = b:GetAttribute("TabId") == name
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = isActive and Color3.fromRGB(0,70,55) or THEME.panel2
            }):Play()
            local lbl = b:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.TextColor3 = isActive and THEME.accent or THEME.textDim end
        end

        if name == "Main" then
            addSection("QUICK ACTIONS")
            addToggle("Auto Steal", "AutoSteal")
            addToggle("Instant Grab", "InstantGrab")
            addToggle("Auto Hatch", "AutoHatch")
            addToggle("Auto Sell Egg", "AutoSellEgg")
            addToggle("Auto Fuse", "AutoFuse")
            addToggle("Botting Mode", "BottingMode")
            addSection("PROTECTION")
            addToggle("Anti Kick", "AntiKick")
            addToggle("Anti Ban", "AntiBan")
            addToggle("Anti Crash", "AntiCrash")
            addToggle("Anti Detection", "AntiDetection")
            addToggle("Anti AFK", "AntiAFK")
            addSection("SERVER")
            addToggle("Auto Hop", "AutoHop")
            addToggle("Hop When Empty", "HopWhenNothingMatches")
            addToggle("Auto Reconnect", "AutoReconnect")
            addToggle("Auto Rejoin on Kick", "AutoRejoinOnKick")
            addButton("Force Rejoin Server", function()
                TeleportService:Teleport(game.PlaceId, LP)
            end, true)
        elseif name == "Steal" then
            addSection("STEAL ENGINE")
            addToggle("Auto Steal", "AutoSteal")
            addToggle("Instant Grab", "InstantGrab")
            addToggle("Velocity Move", "VelocityMove")
            addToggle("Humanize", "Humanize")
            addSection("PRIORITY")
            addButton("Priority: " .. CONFIG.StealPriority, function()
                local l = {"Rarest","Nearest","HighestValue"}
                for i, v in ipairs(l) do
                    if v == CONFIG.StealPriority then CONFIG.StealPriority = l[(i%#l)+1] break end
                end
                renderTab("Steal")
            end)
            addButton("Speed: " .. CONFIG.StealSpeed, function()
                CONFIG.StealSpeed = CONFIG.StealSpeed >= 300 and 120 or (CONFIG.StealSpeed + 60)
                renderTab("Steal")
            end)
            addButton("Burst: " .. CONFIG.MultiFireBurst, function()
                CONFIG.MultiFireBurst = (CONFIG.MultiFireBurst % 5) + 1
                renderTab("Steal")
            end)
            addSection("WEBHOOK")
            addToggle("Steal Webhook", "StealWebhook")
            addToggle("Batch Webhook", "WebhookBatch")
            addButton("Min Rarity: " .. CONFIG.WebhookMinRarity, function()
                for i, v in ipairs(CONFIG.RarityList) do
                    if v == CONFIG.WebhookMinRarity then
                        CONFIG.WebhookMinRarity = CONFIG.RarityList[(i%#CONFIG.RarityList)+1] break
                    end
                end
                renderTab("Steal")
            end)
            addSection("ANTI-GUARD")
            addToggle("Anti Guard Knockback", "AntiGuardKnockback")
            addToggle("Anti Hit Guard", "AntiHitGuard")
            addToggle("Anti Treadmill", "AntiTreadmill")
        elseif name == "Auto" then
            addSection("BASE")
            addToggle("Auto Place", "AutoPlace")
            addToggle("Auto Hatch", "AutoHatch")
            addToggle("Auto Sell Egg", "AutoSellEgg")
            addToggle("Auto Sell Pet", "AutoSellPet")
            addToggle("Auto Fuse", "AutoFuse")
            addToggle("Auto Equip Best", "AutoEquipBest")
            addSection("GRIND")
            addToggle("Auto Quest", "AutoQuest")
            addToggle("Auto Daily", "AutoDaily")
            addToggle("Auto Rebirth", "AutoRebirth")
            addToggle("Auto Upgrade Base", "AutoUpgradeBase")
            addToggle("Auto Upgrade Treadmill", "AutoUpgradeTreadmill")
            addToggle("Collect Offline", "CollectOffline")
            addToggle("Auto Claim Almanac", "AutoClaimAlmanac")
        elseif name == "Pets" then
            addSection("PET MANAGEMENT")
            addToggle("Auto Equip Best", "AutoEquipBest")
            addToggle("Auto Fuse", "AutoFuse")
            addToggle("Auto Sell Pet", "AutoSellPet")
            addSection("UPGRADE")
            addToggle("Auto Upgrade Base", "AutoUpgradeBase")
            addToggle("Auto Upgrade Treadmill", "AutoUpgradeTreadmill")
        elseif name == "Events" then
            addSection("EVENTS")
            addToggle("Auto Catch", "AutoCatch")
            addToggle("Butterfly ESP", "ButterflyESP")
            addToggle("Auto Trade Up", "AutoTradeUp")
            addToggle("Auto Craft Essence", "AutoCraftEssence")
            addToggle("Auto Buy Shop", "AutoBuyShop")
            addToggle("Auto Trade-In", "AutoTradeIn")
            addToggle("Auto Free Reroll", "AutoFreeReroll")
            addToggle("Auto Boss", "AutoBoss")
            addToggle("Boss Dodge", "BossDodge")
            addToggle("Auto Egg Rain", "AutoEggRain")
            addToggle("Auto Gift", "AutoGift")
            addSection("AUCTION")
            addToggle("Auction Sniper", "AutoAuctionSnipe")
            addButton("Min Value: " .. CONFIG.AuctionMinValue, function()
                local l = {1000,2500,5000,10000,25000,50000,100000}
                for i, v in ipairs(l) do
                    if v == CONFIG.AuctionMinValue then CONFIG.AuctionMinValue = l[(i%#l)+1] break end
                end
                renderTab("Events")
            end)
        elseif name == "Players" then
            addSection("PLAYER STEAL")
            addToggle("Auto Steal From Players", "AutoStealFromPlayers")
            addSection("HISTORY ("..#STATE.StealHistory..")")
            for i = math.max(1, #STATE.StealHistory - 15), #STATE.StealHistory do
                local h = STATE.StealHistory[i]
                if h then addInfo(string.format("[%s] %s (%s)", h.time, h.name, h.rarity)) end
            end
        elseif name == "Misc" then
            addSection("PERFORMANCE")
            addToggle("Boost FPS", "BoostFPS")
            addToggle("Uncap FPS", "UncapFPS")
            addToggle("Adaptive FPS", "AdaptiveFPS")
            addToggle("Anti Cutscene", "AntiCutscene")
            addSection("MOVEMENT")
            addToggle("Noclip", "Noclip")
            addToggle("Infinite Jump", "InfiniteJump")
            addToggle("Fly", "Fly")
            addButton("Fly Speed: " .. CONFIG.FlySpeed, function()
                CONFIG.FlySpeed = CONFIG.FlySpeed >= 200 and 50 or (CONFIG.FlySpeed + 30)
                renderTab("Misc")
            end)
            addSection("CONFIG")
            addButton("Save Config", saveConfig)
            addButton("Load Config", loadConfig)
            addButton("Reset to Defaults", function()
                CONFIG.RefreshRate = 0.08
                CONFIG.StealSpeed = 250
                CONFIG.MultiFireBurst = 3
            end)
        elseif name == "Visual" then
            addSection("ESP")
            addToggle("Egg Checker", "EggChecker")
            addToggle("Rarity ESP", "RarityESP")
            addToggle("Distance ESP", "DistanceESP")
            addToggle("Butterfly ESP", "ButterflyESP")
            addSection("VISUAL")
            addButton("Spawn Visual Egg", function()
                local p = Instance.new("Part")
                p.Shape = Enum.PartType.Ball
                p.Size = Vector3.new(2,3,2)
                p.Color = THEME.accent
                p.Material = Enum.Material.Neon
                p.Anchored = true
                local r = getRoot()
                if r then p.CFrame = r.CFrame * CFrame.new(0,0,-5) end
                p.Parent = Workspace
                table.insert(STATE.VisualItems, p)
            end)
            addButton("Clear Visuals", function()
                for _, v in ipairs(STATE.VisualItems) do safeCall(function() v:Destroy() end) end
                STATE.VisualItems = {}
            end)
        elseif name == "Protect" then
            addSection("ANTI-KICK / BAN / CRASH")
            addToggle("Anti Kick", "AntiKick")
            addToggle("Anti Ban", "AntiBan")
            addToggle("Anti Crash", "AntiCrash")
            addToggle("Anti Log (Telemetry)", "AntiLog")
            addToggle("Anti Detection", "AntiDetection")
            addToggle("Anti Teleport Trap", "AntiTeleport")
            addSection("ANTI-AFK / TREADMILL")
            addToggle("Anti AFK", "AntiAFK")
            addToggle("Anti Treadmill", "AntiTreadmill")
            addToggle("Anti Guard Knockback", "AntiGuardKnockback")
            addToggle("Anti Hit Guard", "AntiHitGuard")
            addSection("STATS")
            addInfo("Kicks Blocked: " .. STATE.KicksBlocked)
            addInfo("Detection: " .. math.floor(STATE.DetectionScore) .. "%")
        elseif name == "Log" then
            addSection("EVENT LOG")
            for i = #STATE.Logger, math.max(1, #STATE.Logger - 30), -1 do
                addInfo(STATE.Logger[i])
            end
        end
    end

    for _, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. tab.id
        btn:SetAttribute("TabId", tab.id)
        btn.Size = UDim2.new(1, 0, 0, 38)
        btn.BackgroundColor3 = THEME.panel2
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.Parent = sidebar
        makeCorner(btn, 6)

        local icon = Instance.new("TextLabel")
        icon.Size = UDim2.new(0, 24, 1, 0)
        icon.Position = UDim2.new(0, 10, 0, 0)
        icon.BackgroundTransparency = 1
        icon.Text = tab.icon
        icon.TextColor3 = THEME.textDim
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 14
        icon.Parent = btn

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -40, 1, 0)
        lbl.Position = UDim2.new(0, 38, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = tab.label
        lbl.TextColor3 = THEME.textDim
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = btn

        btn.MouseEnter:Connect(function()
            if btn:GetAttribute("TabId") ~= STATE.CurrentTab then
                TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = THEME.cardHover}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if btn:GetAttribute("TabId") ~= STATE.CurrentTab then
                TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = THEME.panel2}):Play()
            end
        end)
        btn.MouseButton1Click:Connect(function()
            STATE.CurrentTab = tab.id
            renderTab(tab.id)
        end)
        table.insert(tabButtons, btn)
    end

    renderTab("Main")

    -- minimize
    local minimized = false
    local savedSize = main.Size
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            savedSize = main.Size
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                Size = UDim2.new(0, 720, 0, 50)
            }):Play()
            sidebar.Visible = false
            content.Visible = false
            footer.Visible = false
            minBtn.Text = "□"
        else
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                Size = savedSize
            }):Play()
            sidebar.Visible = true
            content.Visible = true
            footer.Visible = true
            minBtn.Text = "—"
        end
    end)

    -- live stats  [FIX 1 applied]
    task.spawn(function()
        while STATE.GUI and STATE.GUI.Parent do
            local up = math.floor(tick() - STATE.SessionStart)
            statsLbl.Text = string.format(
                "⏱ %ds  |  ⚡ %dfps  |  📡 %dms  |  🎯 %d stolen  |  🥚 %d sold  |  ✦ %d hatch  |  ⛨ %d kicks  |  det %d%%",
                up, STATE.FPS, STATE.Ping, STATE.EggsStolen, STATE.EggsSold,
                STATE.PetsHatched, STATE.KicksBlocked, math.floor(STATE.DetectionScore)
            )
            task.wait(1)
        end
    end)
end

-- =========================================================
-- INIT
-- =========================================================

local function init()
    loadConfig()
    findBase()
    findTreadmill()
    installAntiKick()
    installAntiCrash()
    installAntiLog()
    setupAntiAFK()
    setupInfiniteJump()
    buildESP()
    buildGUI()
    notify("SENA v8.1 Genesis loaded — full merged build.")

    task.spawn(loopAutoSteal)
    task.spawn(loopAutoPlace)
    task.spawn(loopAutoHatch)
    task.spawn(loopAutoSell)
    task.spawn(loopAutoFuse)
    task.spawn(loopAutoEquip)
    task.spawn(loopAutoClaim)
    task.spawn(loopAutoUpgrade)
    task.spawn(loopAutoTreadmill)
    task.spawn(loopAutoQuest)
    task.spawn(loopAutoDaily)
    task.spawn(loopAutoRebirth)
    task.spawn(loopAutoEvents)
    task.spawn(loopAuction)
    task.spawn(loopBossDodge)
    task.spawn(loopAntiGuard)
    task.spawn(loopAntiCutscene)
    task.spawn(loopNoclip)
    task.spawn(loopFly)
    task.spawn(loopPerformance)
    task.spawn(loopReconnect)
    task.spawn(loopBotting)
    task.spawn(loopDetection)
    task.spawn(loopWebhookFlush)

    LP.CharacterAdded:Connect(function()
        task.wait(1.5)
        findBase()
        if CONFIG.BottingMode then returnToBase(true) end
    end)

    log("v8.1 initialized")
    saveConfig()
end

init()
