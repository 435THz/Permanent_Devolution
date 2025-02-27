
DEVOLUTION_MOD = {}
DEVOLUTION_MOD.EvoItem = luanet.import_type("PMDC.Data.EvoItem")
DEVOLUTION_MOD.EvoShed = luanet.import_type("PMDC.Data.EvoShed")
DEVOLUTION_MOD.EvoForm  = luanet.import_type("PMDC.Data.EvoForm")
DEVOLUTION_MOD.EvoSetForm = luanet.import_type("PMDC.Data.EvoSetForm")
DEVOLUTION_MOD.EvoFormDusk = luanet.import_type("PMDC.Data.EvoFormDusk")

---Calculates the target monster data and the items refunded by this devolution
---@param chara userdata the character to devolve
---@return string, number, table, boolean the target species and form, the list of items to be refunded, and true if the devolution is to be aborted because the previous evolution stage is unreleased or nonexistent, false otherwise (including success)
function DEVOLUTION_MOD.calcDevolve(chara)
    local species = _DATA:GetMonster(chara.BaseForm.Species)
    local form = species.Forms[chara.BaseForm.Form]

    local prevSpecies, prevForm, refund_items = species.PromoteFrom, form.PromoteForm, {}
    local method_found = false

    if not _DATA.DataIndices[RogueEssence.Data.DataManager.DataType.Monster]:ContainsKey(prevSpecies) then
        return "", "", {}, true
    end
    local prevSpeciesData = _DATA:GetMonster(prevSpecies)
    if not prevSpeciesData.Released or prevForm >= prevSpeciesData.Forms.Count or not prevSpeciesData.Forms[prevForm].Released then
        return "", "", {}, true
    end

    local evolutions = prevSpeciesData.Promotions
    for method in luanet.each(evolutions) do
        local valid = true
        if method.Result == chara.BaseForm.Species then
            for detail in luanet.each(method.Details) do
                if LUA_ENGINE:TypeOf(detail) == luanet.ctype(DEVOLUTION_MOD.EvoItem) then
                    --store the required item if the evolution requires an item. Straight-forward enough.
                    table.insert(refund_items, detail.ItemNum)
                elseif LUA_ENGINE:TypeOf(detail) == luanet.ctype(DEVOLUTION_MOD.EvoShed) then
                    --stop shed devolutions altogether. No Nincada duplication allowed.
                    valid = false
                    break --detail iteration
                elseif LUA_ENGINE:TypeOf(detail) == luanet.ctype(DEVOLUTION_MOD.EvoForm) then
                    -- if the required form is not the previous form, then this is not the evolution we're
                    -- looking for. Abort.
                    if not detail.ReqForms.Contains(prevForm) then
                        valid = false
                        break --detail iteration
                    end
                elseif LUA_ENGINE:TypeOf(detail) == luanet.ctype(DEVOLUTION_MOD.EvoSetForm) then
                    -- if the evolved form is not the current form, then this is not the evolution we're
                    -- looking for. Abort.
                    if not detail.Form == form then
                        valid = false
                        break --detail iteration
                    end
                    for condition in luanet.each(detail.Conditions) do
                        if LUA_ENGINE:TypeOf(condition) == luanet.ctype(DEVOLUTION_MOD.EvoItem) then
                            --store the required item if the evolution requires an item. Straight-forward enough.
                            table.insert(refund_items, condition.ItemNum)
                        end
                    end
                elseif LUA_ENGINE:TypeOf(detail) == luanet.ctype(DEVOLUTION_MOD.EvoFormDusk) then
                    local found = false
                    --check which item corresponds to the current form and add it to the list if found
                    for pair in luanet.each(LUA_ENGINE:MakeList(detail.ItemMap)) do
                        if pair.Value == chara.BaseForm.Form then
                            table.insert(refund_items, pair.Key)
                            found = true
                            break --pair iteration
                        end
                    end
                    -- if no match is found, check if the default form corresponds to the current one.
                    -- This is the only case in which a harmony scarf can be refunded when not indexed
                    if not found then
                        if detail.DefaultForm == chara.BaseForm.Form then table.insert(refund_items, "evo_harmony_scarf")
                        else
                            -- if the form does not match either, abort.
                            valid = false
                            break --detail iteration
                        end
                    end
                end
            end
        else
            --Wrong evolution method. Skip.
            valid = false
        end
        if valid then
            method_found = true
            break --method iteration
        end
    end
    if not method_found then
        return "", "", {}, false
    end
    return prevSpecies, prevForm, refund_items, false
end

function DEVOLUTION_MOD.CanLearnSkill(chara, skill)
    local forms = {}
    local monsterData = _DATA:GetMonster(chara.BaseForm.Species)
    local formData = monsterData.Forms[chara.BaseForm.Form]
    table.insert(forms, {species = chara.BaseForm.Species, form = chara.BaseForm.Form})
    while monsterData.PromoteFrom and monsterData.PromoteFrom ~= "" do
        table.insert(forms, {species = monsterData.PromoteFrom, form = formData.PromoteForm})
        monsterData = _DATA:GetMonster(monsterData.PromoteFrom)
        formData = monsterData.Forms[formData.PromoteForm]
    end
    for _, form in ipairs(forms) do
        local data = _DATA:GetMonster(form.species).Forms[form.form]
        local lists = {data.LevelSkills, data.TeachSkills, data.SharedSkills, data.SecretSkills}
        for _, list in ipairs(lists) do
            for entry in luanet.each(list) do
                if entry.Skill == skill then return true end
            end
        end
    end
    return false
end

function DEVOLUTION_MOD.DevolveCharacter(chara, form)
    chara:Promote(form)
    chara:FullRestore()

    _DATA.Save:RegisterMonster(chara.BaseForm.Species)
    _DATA.Save:RogueUnlockMonster(chara.BaseForm.Species)
end

function DEVOLUTION_MOD.ReplaceInvalidSkills(chara)
    local replace = 0
    for i=0, 3, 1 do
        local slotSkill = chara.BaseSkills[i]
        if not DEVOLUTION_MOD.CanLearnSkill(chara, slotSkill.SkillNum) and slotSkill.CanForget then
            GAME:ForgetSkill(chara, i)
            replace = replace+1
        end
    end
    local form = _DATA:GetMonster(chara.BaseForm.Species).Forms[chara.BaseForm.Form]
    local newSkills = {}
    local i, s = 0, form.LevelSkills.Count-1
    while i < 4 and s >= 0 and #newSkills<replace do
        local slotSkill = chara.BaseSkills[i]
        if slotSkill.SkillNum and slotSkill.SkillNum ~= "" then
            i=i+1
        else
            if form.LevelSkills[s].Level<=chara.Level then
                local found = false
                for j=0, i-1, 1 do
                    if form.LevelSkills[s].Skill == chara.BaseSkills[j].SkillNum then
                        found = true
                        break
                    end
                end
                if not found then
                    for _, skill in ipairs(newSkills) do
                        if form.LevelSkills[s].Skill == skill then
                            found = true
                            break
                        end
                    end
                end
                if not found then
                    table.insert(newSkills, form.LevelSkills[s].Skill)
                    i=i+1
                end
            end
            s=s-1
        end
    end
    for n = #newSkills, 1, -1 do
        GAME:LearnSkill(chara, newSkills[n])
    end
end