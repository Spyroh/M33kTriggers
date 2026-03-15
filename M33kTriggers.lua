--╔════════════════════════════════════╗
--║ ┏┳┓┏━┓┏━┓╻┏ ╺┳╸┏━┓╻┏━╸┏━╸┏━╸┏━┓┏━┓ ║
--║ ┃┃┃╺━┫╺━┫┣┻┓ ┃ ┣┳┛┃┃╺┓┃╺┓┣╸ ┣┳┛┗━┓ ║
--║ ╹ ╹┗━┛┗━┛╹ ╹ ╹ ╹┗╸╹┗━┛┗━┛┗━╸╹┗╸┗━┛ ║
--╠════════════════════════════════════╣
--║       By Spyro [Sanguino EU]       ║
--╚════════════════════════════════════╝

-- Upvalues
local C_Spell, RunNextFrame, UnitExists, UnitCanAttack, UnitIsDead, UnitIsDeadOrGhost, UnitHealthPercent, BuffIconCooldownViewer, BuffBarCooldownViewer
    = C_Spell, RunNextFrame, UnitExists, UnitCanAttack, UnitIsDead, UnitIsDeadOrGhost, UnitHealthPercent, BuffIconCooldownViewer, BuffBarCooldownViewer

M33kTriggers = {} -- Global table to expose the functions
local LoadedAuras = {} -- Table with the managed auras to always show them when the panel opens
local Panel -- Will store a reference to the M33kAurasOptions panel when it's created

-- Curve for the ShowOnCdReady trigger
-- Spells with less that 0.5sec CD left will be considered ready (will be made visible). This allows to use a less aggresive ticker (0.3sec)
-- checking the state of the CD (which is needed coz SPELL_UPDATE_COOLDOWN is not totally reliable) and helps the user with reaction time
local CdAlphaCurve = C_CurveUtil.CreateCurve()
CdAlphaCurve:SetType(Enum.LuaCurveType.Step)
CdAlphaCurve:AddPoint(0, 1) -- Visible alpha for available (off CD)
CdAlphaCurve:AddPoint(0.5, 0) -- Invisible alpha for unavailable (CD >= 0.5sec)

-- Curve for the ShowOnAllChargesReady trigger
-- Spells with charges don't need a ticker coz SPELL_UPDATE_CHARGES is 100% reliable
local ChargesAlphaCurve = C_CurveUtil.CreateCurve()
ChargesAlphaCurve:SetType(Enum.LuaCurveType.Step)
ChargesAlphaCurve:AddPoint(0, 1) -- Visible alpha for available (off CD)
ChargesAlphaCurve:AddPoint(0.001, 0) -- Invisible alpha for unavailable (CD higher than 0)

-- Hooks to show the modded auras when the M33kAuras panel opens
hooksecurefunc("CreateFrame", function(_, Name)
  if Name ~= "M33kAurasOptions" then return end
  Panel = M33kAurasOptions

  Panel:HookScript("OnShow", function()
    for M33kAura in pairs(LoadedAuras) do
      M33kAura:Show()
      M33kAura:SetAlpha(1)
      if M33kAura.text then M33kAura.text:SetText("2") end -- Example text for stacks
    end
  end)

  RunNextFrame(function() -- Needed cuz the OnHide script gets overwritten in the current frame
    Panel:HookScript("OnHide", function()
      for M33kAura in pairs(LoadedAuras) do -- Auras back to normal when the panel closes
        if M33kAura.text then M33kAura.text:SetText("") end
        M33kAura.UpdateFunc()
      end
    end)
  end)
end)

-- IsPanelShown()
-- Returns if the M33kAurasOptions panel is shown.
local function IsPanelShown()
  return Panel and Panel:IsShown()
end

-- ShowOnCdReady()
-- Shows a M33kAura when a spell is off CD.
function M33kTriggers.ShowOnCdReady(aura_env, SpellIdentifier)
  local Frame = aura_env.region

  -- Function that shows the frame if the CD is available
  Frame.ShowIfCdReady = function()
    if C_Spell.GetSpellCooldown(SpellIdentifier).isOnGCD or IsPanelShown() then -- CD ready but on GCD
      Frame:SetAlpha(1)
    else -- Not on GCD, make visible if ready
      Frame:SetAlpha(C_Spell.GetSpellCooldownDuration(SpellIdentifier):EvaluateRemainingDuration(CdAlphaCurve))
    end
  end

  Frame.UpdateFunc = Frame.ShowIfCdReady -- Used by the M33kAurasOptions OnHide hook
  Frame.ShowIfCdReady()
  Frame:Show()

  -- Spells with charges
  if C_Spell.GetSpellCharges(SpellIdentifier) then
    Frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    Frame:SetScript("OnEvent", function(_, Event)
      if Event == "SPELL_UPDATE_CHARGES" then Frame.ShowIfCdReady() end
    end)

    -- Function to unload the trigger
    Frame.UnLoad = function()
      Frame:UnregisterAllEvents()
      Frame:SetScript("OnEvent", nil)
      Frame:Hide()
      Frame:SetAlpha(1)
      LoadedAuras[Frame] = nil
    end

  -- Spells without charges
  else
    Frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    Frame:SetScript("OnEvent", function(_, Event) -- We have to check the event in case more events are registered later from ShowOnExecute()
      if Event == "SPELL_UPDATE_COOLDOWN" then Frame.ShowIfCdReady() end
    end)
    FrameUtil.RegisterUpdateFunction(Frame, 0.3, Frame.ShowIfCdReady) -- Needed coz the event is not totally reliable

    -- Function to unload the trigger
    Frame.UnLoad = function()
      FrameUtil.UnregisterUpdateFunction(Frame)
      Frame:UnregisterAllEvents()
      Frame:SetScript("OnEvent", nil)
      Frame:Hide()
      Frame:SetAlpha(1)
      LoadedAuras[Frame] = nil
    end
  end

  aura_env.UnLoad = Frame.UnLoad -- Easier reference for the user for the custom unload editbox
  LoadedAuras[Frame] = Frame
end

-- ShowOnAllChargesReady()
-- Shows a M33kAura when all the charges of a spell are available.
function M33kTriggers.ShowOnAllChargesReady(aura_env, SpellIdentifier)
  local Frame = aura_env.region

  -- Function that shows the frame when all charges are available
  Frame.ShowIfAllChargesReady = function()
    if IsPanelShown() then Frame:SetAlpha(1) -- Always show when the M33kAuras panel is open
    else Frame:SetAlpha(C_Spell.GetSpellChargeDuration(SpellIdentifier):EvaluateRemainingDuration(ChargesAlphaCurve)) end
  end
  Frame.UpdateFunc = Frame.ShowIfAllChargesReady -- Used by the M33kAurasOptions OnHide hook

  -- Event
  Frame:RegisterEvent("SPELL_UPDATE_CHARGES")
  Frame:SetScript("OnEvent", Frame.ShowIfAllChargesReady)
  Frame.ShowIfAllChargesReady()
  Frame:Show()

  -- Function to unload the trigger
  aura_env.UnLoad = function()
    Frame:UnregisterAllEvents()
    Frame:SetScript("OnEvent", nil)
    Frame:Hide()
    Frame:SetAlpha(1)
    LoadedAuras[Frame] = nil
  end

  LoadedAuras[Frame] = Frame
end

-- ShowOnSpellUsable()
-- Shows a M33kAura when a spell is usable. For spells that have requirements for their activation like Rampage or Shadow Word: Madness.
function M33kTriggers.ShowOnSpellUsable(aura_env, SpellIdentifier)
  local Frame = aura_env.region

  -- Function that shows the frame if the spell is usable
  Frame.ShowIfSpellUsable = function()
    if IsPanelShown() then -- Always show when the M33kAuras panel is open
      Frame:SetAlpha(1)
    else
      local IsUsable = C_Spell.IsSpellUsable(SpellIdentifier)
      Frame:SetAlphaFromBoolean(IsUsable)
    end
  end
  Frame.UpdateFunc = Frame.ShowIfSpellUsable -- Used by the M33kAurasOptions OnHide hook

  -- Event
  Frame:RegisterEvent("SPELL_UPDATE_USABLE")
  Frame:SetScript("OnEvent", Frame.ShowIfSpellUsable)
  Frame.ShowIfSpellUsable()
  Frame:Show()

  -- Function to unload the trigger
  aura_env.UnLoad = function()
    Frame:UnregisterAllEvents()
    Frame:SetScript("OnEvent", nil)
    Frame:Hide()
    Frame:SetAlpha(1)
    LoadedAuras[Frame] = nil
  end

  LoadedAuras[Frame] = Frame
end

-- ShowOnExecute()
-- Shows a M33kAura when an execute-type spell should be used (is off CD and the target's health is under a certain percentage).
function M33kTriggers.ShowOnExecute(aura_env, SpellIdentifier, BelowHpPercent)
  local Frame = aura_env.region
  local Region = Frame.text or (Frame.texture and Frame.texture.texture)
  if not Region then return end

  -- The parent frame will only be visible when the execute spell is off CD
  M33kTriggers.ShowOnCdReady(aura_env, SpellIdentifier)

  -- Curve that generates a visible alpha in execute range
  Region.ExecuteCurve = Region.ExecuteCurve or C_CurveUtil.CreateCurve()
  Region.ExecuteCurve:SetType(Enum.LuaCurveType.Step)
  Region.ExecuteCurve:ClearPoints()
  Region.ExecuteCurve:AddPoint(0, 1) -- Visible (start of the execute range)
  Region.ExecuteCurve:AddPoint(BelowHpPercent * 0.01, 0) -- Invisible (end of the execute range)

  -- Function that shows the region when the target's health is under a certain percentage
  Region.ShowIfShouldUseExecute = function()
    if IsPanelShown() then Region:SetAlpha(1) -- Always show when the M33kAuras panel is open
    elseif not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDeadOrGhost("target") then Region:SetAlpha(0)
    else Region:SetAlpha(UnitHealthPercent("target", true, Region.ExecuteCurve)) end
  end
  Region.UpdateFunc = Region.ShowIfShouldUseExecute -- Used by the M33kAurasOptions OnHide hook

  -- Events
  Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
  Frame:RegisterUnitEvent("UNIT_HEALTH", "target")
  Frame:HookScript("OnEvent", function(_, Event) 
    if Event == "PLAYER_TARGET_CHANGED" or Event == "UNIT_HEALTH" then
      Region.ShowIfShouldUseExecute()
    end
  end)
  Region.ShowIfShouldUseExecute()

  -- Function to unload both triggers (CD ready & target %HP)
  aura_env.UnLoad = function()
    Frame.UnLoad() -- This will unregister all events
    Region:SetAlpha(1)
    LoadedAuras[Region] = nil
  end

  LoadedAuras[Region] = Region
end

-- ShowOnPowerPercent()
-- Shows a M33kAura when the player's power is higher than or equal to a certain percentage.
function M33kTriggers.ShowOnPowerPercent(aura_env, Percent)
  local Frame = aura_env.region

  -- Curve that generates a visible alpha in execute range
  Frame.Curve = Frame.Curve or C_CurveUtil.CreateCurve()
  Frame.Curve:SetType(Enum.LuaCurveType.Step)
  Frame.Curve:ClearPoints()
  Frame.Curve:AddPoint(0, 0) -- Invisible
  Frame.Curve:AddPoint(Percent * 0.01, 1) -- Visible

  -- Function that shows the frame if we have enough power %
  Frame.ShowIfEnoughPower = function()
    Frame:SetAlpha(UnitPowerPercent("player", UnitPowerType("player"), true, Frame.Curve))
  end
  Frame.UpdateFunc = Frame.ShowIfEnoughPower -- Used by the M33kAurasOptions OnHide hook

  -- Event
  Frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
  Frame:SetScript("OnEvent", Frame.ShowIfEnoughPower)
  Frame.ShowIfEnoughPower()
  Frame:Show()

  -- Function to unload the trigger
  aura_env.UnLoad = function()
    Frame:UnregisterAllEvents()
    Frame:SetScript("OnEvent", nil)
    Frame:Hide()
    Frame:SetAlpha(1)
    LoadedAuras[Frame] = nil
  end

  LoadedAuras[Frame] = Frame
end

-- ShowOnPetHpUnderPercent()
-- Shows a M33kAura when the health of your pet is under a certain percentage.
function M33kTriggers.ShowOnPetHpUnderPercent(aura_env, BelowHpPercent)
  local Frame = aura_env.region

  -- Curve that generates a visible alpha when the pet's health is under a certain percentage
  Frame.PetHpCurve = Frame.PetHpCurve or C_CurveUtil.CreateCurve()
  Frame.PetHpCurve:SetType(Enum.LuaCurveType.Step)
  Frame.PetHpCurve:ClearPoints()
  Frame.PetHpCurve:AddPoint(0, 1) -- Visible (start of the range)
  Frame.PetHpCurve:AddPoint(BelowHpPercent * 0.01, 0) -- Invisible (end of the range)

  -- Function that shows the frame when the pet's health is under a certain percentage
  Frame.ShowIfPetHpUnderPercent = function()
    if IsPanelShown() then Frame:SetAlpha(1) -- Always show when the M33kAuras panel is open
    elseif not UnitExists("pet") or UnitIsDead("pet") then Frame:SetAlpha(0)
    else Frame:SetAlpha(UnitHealthPercent("pet", true, Frame.PetHpCurve)) end
  end
  Frame.UpdateFunc = Frame.ShowIfPetHpUnderPercent -- Used by the M33kAurasOptions OnHide hook

  -- Events
  Frame:RegisterUnitEvent("UNIT_HEALTH", "pet")
  Frame:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
  Frame:RegisterUnitEvent("UNIT_PET", "player")
  Frame:SetScript("OnEvent", Frame.ShowIfPetHpUnderPercent)
  Frame.ShowIfPetHpUnderPercent()

  -- Function to unload the triggers
  aura_env.UnLoad = function()
    Frame:UnregisterAllEvents()
    Frame:SetScript("OnEvent", nil)
    Frame:Hide()
    Frame:SetAlpha(1)
    LoadedAuras[Frame] = nil
  end

  LoadedAuras[Frame] = Frame
end

-- ShowOnProc()
-- Shows a M33kAura when a proc in available. Requires having the proc added in the CDM.
function M33kTriggers.ShowOnProc(aura_env, SpellID)
  local Frame = aura_env.region

  -- Function that shows the frame if the proc is present
  Frame.CheckProcPresence = function()
    if IsPanelShown() then return end -- Don't process if the M33kAuras panel is open
    Frame:Hide() -- This will hide the frame if the proc is not added to the CDM

    -- Buff icons
    for BuffIcon in BuffIconCooldownViewer.itemFramePool:EnumerateActive() do
      if BuffIcon:GetBaseSpellID() == SpellID then
        Frame:SetShown(BuffIcon.Cooldown:IsShown())
        return
      end
    end

    -- Buff bars
    for BuffBar in BuffBarCooldownViewer.itemFramePool:EnumerateActive() do
      if BuffBar:GetBaseSpellID() == SpellID then
        Frame:SetShown(BuffBar:IsShown())
        return
      end
    end
  end

  -- Event
  Frame:RegisterUnitEvent("UNIT_AURA", "player")
  Frame:SetScript("OnEvent", function() RunNextFrame(Frame.CheckProcPresence) end)
  Frame.UpdateFunc = Frame.CheckProcPresence -- Used by the M33kAurasOptions OnHide hook
  RunNextFrame(Frame.CheckProcPresence)

  -- Function to unload the trigger
  aura_env.UnLoad = function()
    Frame:UnregisterAllEvents()
    Frame:SetScript("OnEvent", nil)
    Frame:Hide()
    LoadedAuras[Frame] = nil
  end

  LoadedAuras[Frame] = Frame
end

-- ShowProcStacks()
-- Shows the stacks of a proc in an Text Aura when they are over 1. Requires having the proc added in the CDM Tracked Buffs.
function M33kTriggers.ShowProcStacks(aura_env, SpellID)
  local Frame = aura_env.region
  local Stacks = Frame.text
  if not Stacks then return end

  -- Function that sets the stacks number
  Frame.ShowProcStacks = function()
    if IsPanelShown() then return end -- Don't process if the M33kAuras panel is open
    Stacks:SetText("") -- This will empty the string if the proc is not added to the CDM

    for BuffIcon in BuffIconCooldownViewer.itemFramePool:EnumerateActive() do
      if BuffIcon:GetBaseSpellID() == SpellID then
        Stacks:SetText(BuffIcon.Applications.Applications:GetText())
        return
      end
    end
  end

  -- Event
  Frame:Show()
  Frame:RegisterUnitEvent("UNIT_AURA", "player")
  Frame:SetScript("OnEvent", function() RunNextFrame(Frame.ShowProcStacks) end)
  Frame.UpdateFunc = Frame.ShowProcStacks -- Used by the M33kAurasOptions OnHide hook
  RunNextFrame(Frame.ShowProcStacks)

  -- Function to unload the trigger
  aura_env.UnLoad = function()
    Frame:UnregisterAllEvents()
    Frame:SetScript("OnEvent", nil)
    Stacks:SetText("")
    LoadedAuras[Frame] = nil
  end

  LoadedAuras[Frame] = Frame
end