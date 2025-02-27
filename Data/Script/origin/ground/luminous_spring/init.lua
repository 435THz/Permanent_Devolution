require 'origin.common'
require 'origin.menu.team.AssemblySelectMenu'
require 'devolution.devolve'

local luminous_spring = {}

--------------------------------------------------
-- Map Callbacks
--------------------------------------------------
function luminous_spring.Init(map)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    PrintInfo("=>> Init_luminous_spring")

    COMMON.RespawnAllies()

end

function luminous_spring.Enter(map)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine

    SV.luminous_spring.Returning = false
    GAME:FadeIn(20)
end

function luminous_spring.Update(map, time)
    if SV.secret.Time == false then
        local cur_date = os.date("%Y-%m-%d %H:%M:S")
        if cur_date < "2005-11-17 00:00:00" then
            luminous_spring.SpecialEvent(cur_date)
        end
    end
end

--------------------------------------------------
-- Map Begin Functions
--------------------------------------------------

--------------------------------------------------
-- Objects Callbacks
--------------------------------------------------

function luminous_spring.South_Exit_Touch(obj, activator)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    GAME:FadeOut(false, 20)
    GAME:EnterGroundMap("base_camp_2", "entrance_north")
end

function luminous_spring.Spring_Touch(obj, activator)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    UI:ResetSpeaker()

    local state = 0
    local repeated = false
    local member = nil
    local evo = nil
    local devo = nil
    local refunds = {}
    local player = CH('PLAYER')

    GAME:CutsceneMode(true)
    GAME:MoveCamera(300, 152, 90, false)
    GROUND:TeleportTo(player, 292, 312, Direction.Down)

    if not SV.luminous_spring.Returning then
        UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Intro_1']))
        UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Intro_2']))
    end
    SV.luminous_spring.Returning = true
    while state > -1 do
        if state == 0 then
            local evo_choices = {STRINGS:Format(STRINGS.MapStrings['Evo_Option_Evolve']),
                                 "Devolve",
                                 STRINGS:FormatKey("MENU_INFO"),
                                 STRINGS:FormatKey("MENU_EXIT")}
            UI:BeginChoiceMenu(STRINGS:Format(STRINGS.MapStrings['Evo_Ask']), evo_choices, 1, 4)
            UI:WaitForChoice()
            local result = UI:ChoiceResult()
            repeated = true
            if result == 1 then
                state = 1
            elseif result == 2 then
                state = 4
            elseif result == 3 then
                UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Info_001']))
                UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Info_002']))
                UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Info_003']))
                UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Info_004']))
                UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Info_005']))
                UI:WaitShowDialogue("Devolution is possible,[pause=10] but it can only happen in this very location.")
            else
                UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_End']))
                state = -1
            end
        elseif state == 1 then
            UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Ask_Who']))
            member = AssemblySelectMenu.run()
            if member then
                state = 2
            else
                state = 0
            end
        elseif state == 2 then
            if not GAME:CanPromote(member) then
                UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_None'], member:GetDisplayName(true)))
                state = 1
            else
                local branches = GAME:GetAvailablePromotions(member, "evo_harmony_scarf")
                if #branches == 0 then
                    UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_None_Now'], member:GetDisplayName(true)))
                    state = 1
                elseif #branches == 1 then
                    local branch = branches[1]
                    local evo_item = ""
                    for detail_idx = 0, branch.Details.Count  - 1 do
                        local detail = branch.Details[detail_idx]
                        evo_item = detail:GetReqItem(member)
                        if evo_item ~= "" then
                            break
                        end
                    end
                    -- harmony scarf hack-in
                    if member.EquippedItem.ID == "evo_harmony_scarf" then
                        evo_item = "evo_harmony_scarf"
                    end
                    local mon = _DATA:GetMonster(branch.Result)
                    if evo_item ~= "" then
                        local item = _DATA:GetItem(evo_item)
                        UI:ChoiceMenuYesNo(STRINGS:Format(STRINGS.MapStrings['Evo_Confirm_Item'], member:GetDisplayName(true), item:GetIconName(), mon:GetColoredName()), false)
                    else
                        UI:ChoiceMenuYesNo(STRINGS:Format(STRINGS.MapStrings['Evo_Confirm'], member:GetDisplayName(true), mon:GetColoredName()), false)
                    end
                    UI:WaitForChoice()
                    local result = UI:ChoiceResult()
                    if result then
                        evo = branch
                        state = 3
                    else
                        state = 1
                    end
                else
                    local evo_names = {}
                    for branch_idx = 1, #branches do
                        local mon = _DATA:GetMonster(branches[branch_idx].Result)
                        table.insert(evo_names, mon:GetColoredName())
                    end
                    table.insert(evo_names, STRINGS:FormatKey("MENU_CANCEL"))
                    UI:BeginChoiceMenu(STRINGS:Format(STRINGS.MapStrings['Evo_Choice'], member:GetDisplayName(true)), evo_names, 1, #evo_names)
                    UI:WaitForChoice()
                    local result = UI:ChoiceResult()
                    if result < #evo_names then
                        evo = branches[result]
                        state = 3
                    else
                        state = 1
                    end
                end
            end
        elseif state == 3 then
            --execute evolution
            local mon = _DATA:GetMonster(evo.Result)

            GROUND:SpawnerSetSpawn("EVO_SUBJECT",member)
            local subject = GROUND:SpawnerDoSpawn("EVO_SUBJECT")

            GROUND:MoveInDirection(subject, Direction.Up, 60, false, 2)
            GROUND:EntTurn(subject, Direction.Down)

            UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Begin']))

            SOUND:PlayBattleSE("EVT_Evolution_Start")
            GAME:FadeOut(true, 20)

            local pastName = member:GetDisplayName(true)
            GAME:PromoteCharacter(member, evo, "evo_harmony_scarf")
            COMMON.RespawnAllies()
            GROUND:RemoveCharacter("EvoSubject")
            --GROUND:SpawnerSetSpawn("EVO_SUBJECT",member)
            subject = GROUND:SpawnerDoSpawn("EVO_SUBJECT")
            GROUND:TeleportTo(subject, 292, 192, Direction.Down)

            GAME:WaitFrames(30)

            SOUND:PlayBattleSE("EVT_Title_Intro")
            GAME:FadeIn(20)
            SOUND:PlayFanfare("Fanfare/Promotion")


            UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Evo_Complete'], pastName, mon:GetColoredName()))
            GAME:CheckLevelSkills(member, 0)
            if member.Level > 1 then
                GAME:CheckLevelSkills(member, member.Level-1)
            end

            GROUND:MoveInDirection(subject, Direction.Down, 60, false, 2)

            GROUND:RemoveCharacter("EvoSubject")

            state = 0
        elseif state == 4 then
            --request devolution
            UI:WaitShowDialogue("Which Pokémon seeks devolution?")
            member = AssemblySelectMenu.run()
            if member then
                state = 5
            else
                state = 0
            end
        elseif state == 5 then
            local species, form, items, impossible = DEVOLUTION_MOD.calcDevolve(member)
            if impossible or species == "" then
                UI:WaitShowDialogue(STRINGS:Format("...[pause=0]{0} cannot devolve any further.", member:GetDisplayName(true))) --nonexistent devolution
                state = 4
            else
                local cost = RogueEssence.Dungeon.InvItem("loot_heart_scale", false, 5)
                local mon = _DATA:GetMonster(species)
                if #items > 0 then
                    UI:ChoiceMenuYesNo(STRINGS:Format("{0} shall give {2},[pause=10] and devolve into {1}.[pause=0] Is that OK?", member:GetDisplayName(true), mon:GetColoredName(), cost:GetDisplayName()), false)
                else
                    UI:ChoiceMenuYesNo(STRINGS:Format("{0} shall devolve into {1}.[pause=0] Is that OK?", member:GetDisplayName(true), mon:GetColoredName()), false)
                end
                UI:WaitForChoice()
                local result = UI:ChoiceResult()
                if result then
                    if #items > 0 and COMMON.GetPlayerItemCount("loot_heart_scale", false) < 5 then
                        UI:WaitShowDialogue(STRINGS:Format("You do not have the necessary items to devolve {0}.", member:GetDisplayName(true)))
                        refunds = {}
                        devo = nil
                        state = 4
                    else
                        if #items > 0 then
                            for _=1, 5, 1 do
                                local item_slot = GAME:FindPlayerItem("loot_heart_scale", true, true)
                                if not item_slot:IsValid() then
                                    --do nothing
                                elseif item_slot.IsEquipped then
                                    GAME:TakePlayerEquippedItem(item_slot.Slot)
                                else
                                    GAME:TakePlayerBagItem(item_slot.Slot)
                                end
                            end
                        end
                        refunds = items
                        devo = RogueEssence.Dungeon.MonsterID(species, form, member.BaseForm.Skin, member.BaseForm.Gender)
                        state = 6
                    end
                else
                    refunds = {}
                    devo = nil
                    state = 4
                end
            end
        elseif state == 6 then
            --execute devolution
            local mon = _DATA:GetMonster(devo.Species)

            GROUND:SpawnerSetSpawn("EVO_SUBJECT", member)
            local subject = GROUND:SpawnerDoSpawn("EVO_SUBJECT")

            GROUND:MoveInDirection(subject, Direction.Up, 60, false, 2)
            GROUND:EntTurn(subject, Direction.Down)

            UI:WaitShowDialogue("Ye who seek rebirth,[pause=0] let us begin.")

            SOUND:PlayBattleSE("EVT_Evolution_Start")
            GAME:FadeOut(true, 20)

            local pastName = member:GetDisplayName(true)
            DEVOLUTION_MOD.DevolveCharacter(member, devo)
            COMMON.RespawnAllies()
            GROUND:RemoveCharacter("EvoSubject")
            --GROUND:SpawnerSetSpawn("EVO_SUBJECT",member)
            subject = GROUND:SpawnerDoSpawn("EVO_SUBJECT")
            GROUND:TeleportTo(subject, 292, 192, Direction.Down)

            GAME:WaitFrames(30)

            SOUND:PlayBattleSE("EVT_Title_Intro")
            GAME:FadeIn(20)
            SOUND:PlayFanfare("Fanfare/Promotion")

            UI:WaitShowDialogue(STRINGS:Format("{0} devolved back into {1}!", pastName, mon:GetColoredName()))
            DEVOLUTION_MOD.ReplaceInvalidSkills(member)
            for _, item in ipairs(refunds) do
                local give
                if _DATA:GetItem(item).MaxStack<1 then
                    give = RogueEssence.Dungeon.InvItem(item)
                else
                    give = RogueEssence.Dungeon.InvItem(item, false, 1)
                end
                COMMON.GiftItem(player, give)
            end

            GROUND:MoveInDirection(subject, Direction.Down, 60, false, 2)

            GROUND:RemoveCharacter("EvoSubject")

            state = 0
        end
    end

    GAME:MoveCamera(0, 0, 90, true)
    GAME:CutsceneMode(false)
end

function luminous_spring.Assembly_Action(obj, activator)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    UI:ResetSpeaker()
    COMMON.ShowTeamAssemblyMenu(obj, COMMON.RespawnAllies)
end

function luminous_spring.Storage_Action(obj, activator)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    COMMON:ShowTeamStorageMenu()
end


function luminous_spring.Teammate1_Action(chara, activator)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    COMMON.GroundInteract(activator, chara)
end

function luminous_spring.Teammate2_Action(chara, activator)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    COMMON.GroundInteract(activator, chara)
end

function luminous_spring.Teammate3_Action(chara, activator)
    DEBUG.EnableDbgCoro() --Enable debugging this coroutine
    COMMON.GroundInteract(activator, chara)
end

function luminous_spring.SpecialEvent(cur_date)
    local player = CH('PLAYER')
    local current_ground = GAME:GetCurrentGround()
    GAME:FadeOut(true, 20)
    GAME:CutsceneMode(true)
    local base_form = RogueEssence.Dungeon.MonsterID("celebi", 0, "normal", Gender.Genderless)
    local temp_char = RogueEssence.Ground.GroundChar(base_form, RogueElements.Loc(292,416), Direction.Down, "Special")
    current_ground:AddTempChar(temp_char)
    GROUND:TeleportTo(player, temp_char.MapLoc.X, temp_char.MapLoc.Y + 48, Direction.Up)
    GAME:WaitFrames(20)
    GAME:FadeIn(60)

    SOUND:PlayBattleSE("EVT_Emote_Exclaim_2")
    GROUND:CharSetEmote(player, "exclaim", 1)
    GROUND:CharSetEmote(temp_char, "exclaim", 1)

    GAME:WaitFrames(20)

    UI:SetSpeaker(temp_char)
    UI:SetSpeakerEmotion("Surprised")
    UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Special_Event_001']))
    UI:SetSpeakerEmotion("Normal")
    if cur_date < "1996-02-27 00:00:00" then
        UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Special_Event_002']))
    end
    UI:WaitShowDialogue(STRINGS:Format(STRINGS.MapStrings['Special_Event_003']))

    local recruit = _DATA.Save.ActiveTeam:CreatePlayer(_DATA.Save.Rand, base_form, 10, "", 0)
    local talk_evt = RogueEssence.Dungeon.BattleScriptEvent("AllyInteract")
    recruit.ActionEvents:Add(talk_evt)
    COMMON.JoinTeamWithFanfare(recruit, false)

    GAME:FadeOut(false, 30)
    current_ground:RemoveTempChar(temp_char)
    GAME:CutsceneMode(false)
    GAME:FadeIn(30)

    SV.secret.Time = true
end

return luminous_spring