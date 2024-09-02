RegisterModVariable("readBooks")
RegisterModVariable("fetchedOldBooks")
MOD_READY = false

ModifiedHandles = {}

Ext.Osiris.RegisterListener("GameBookInterfaceClosed", 2, "after", function(item, character)
    MarkBookAsRead(item)
end)

--Update rarity to green for all books in ModVars
function UpdateRarityForAllReadBooks()
    if GetMCM("UPDATE_RARITY") == false then return end
    local rarity = GetMCM("RARITY")
    BasicDebug("UpdateRarityForAllReadBooks()")
    for k, entity in pairs(Ext.Entity.GetAllEntitiesWithComponent("ServerItem")) do
        if entity.Uuid and entity.Uuid.EntityUuid then
            local bookID = Osi.GetBookID(entity.Uuid.EntityUuid)
            if bookID and MyVars.readBooks[bookID] then
                UpdateItemRarity(entity, rarity)
            end
        end
    end
end

--Updata rarity to green for an item entity
function UpdateItemRarity(entity, rarity)
    if GetMCM("UPDATE_RARITY") == true then
        entity.Value.Rarity = rarity
        entity:Replicate("Value")
        if not entity.Health then
            entity:CreateComponent("Health")
        end
        entity:Replicate("Health")
    else
        return
    end
    BasicDebug(string.format("Updating Rarity for item : %s with bookID : %s", entity.Uuid.EntityUuid,
        Osi.GetBookID(entity.Uuid.EntityUuid)))
end

--Update loca handle for read books
function MarkAllReadBooksAsRead()
    for k, handle in pairs(MyVars.readBooks) do
        UpdateBookName(handle)
    end
end

--function to add to list of read books & do cosmetic changes
function MarkBookAsRead(book)
    local bookEntity = Ext.Entity.Get(book)
    UpdateItemRarity(bookEntity, GetMCM("RARITY"))
    local bookId = Osi.GetBookID(book)
    local handle = Osi.GetDisplayName(book)
    if not MyVars.readBooks[bookId] then
        BasicDebug("MarkBookAsRead() - Marking unread book as read, bookID : " .. bookId)
        MyVars.readBooks[bookId] = handle
        if not HandleAlreadyPatched(handle) then
            UpdateBookName(handle)
        end
    end
end

--Update book name with pre/suf
function UpdateBookName(handle)
    local translateString = GetTranslatedString(handle)
    ModifiedHandles[handle] = GetTranslatedString(handle)
    BasicDebug("UpdateBookName() - Before Name Update : " .. translateString)
    UpdateTranslatedString(handle,
        GetMCM("READ_BOOK_PREFIX") ..
        translateString .. GetMCM("READ_BOOK_SUFFIX"))
    BasicDebug("UpdateBookName() - After Name Update : " .. GetTranslatedString(handle))
end

--check if a specific loca is already changed
function HandleAlreadyPatched(handle)
    if not (SE_VERSION >= 10) then return true end

    local locaName = GetTranslatedString(handle)
    if locaName then
        local prefix, suffix = GetMCM("READ_BOOK_PREFIX"),
            GetMCM("READ_BOOK_SUFFIX")
        if (#prefix == 0 and #suffix == 0) or
            (#prefix > 0 and StartsWith(locaName, prefix)) or
            (#suffix > 0 and EndsWith(locaName, suffix)) then
            BasicDebug("HandlesAlreadyPatched() - Handles already patched")
            return true
        end
        BasicDebug("HandlesAlreadyPatched() - Handles not already patched")
        return false
    end
end

--Check if we already changed the locas for this game session
function HandlesAlreadyPatched()
    if not (SE_VERSION >= 10) then return true end
    if MyVars.readBooks then
        local firstKey = next(MyVars.readBooks)
        local firstElement = MyVars.readBooks[firstKey]
        if HandleAlreadyPatched(firstElement) then
            BasicDebug("HandlesAlreadyPatched() - Handles already patched")
            return true
        else
            BasicDebug("HandlesAlreadyPatched() - Handles not already patched")
            return false
        end
    else
        BasicDebug("HandlesAlreadyPatched() - No Pvars yet, ignoring")
        return true
    end
end

--Technically modvars now sadge
function UpdatePvarsWithAlreadyKnownBooks()
    ---@type EntityHandle
    local items = Ext.Entity.GetAllEntitiesWithComponent("ServerItem")
    for k, item in pairs(items) do
        if item.ServerItem.Known == true then
            local uuid = item.Uuid.EntityUuid
            local bookId = Osi.GetBookID(uuid)
            if bookId then
                local handle = Osi.GetDisplayName(uuid)
                if not MyVars.readBooks[bookId] then
                    MyVars.readBooks[bookId] = handle
                end
            end
        end
    end
end

function RestoreHandles()
    for handle, name in pairs(ModifiedHandles) do
        UpdateTranslatedString(handle, name)
    end
end

function Start()
    MyVars = GetModVariables()
    if not MyVars.readBooks then
        MyVars.readBooks = {}
    end
    MOD_READY = true
    if not MyVars.fetchedOldBooks then
        BasicPrint("Fetching books read before installation, should be a one time thing...")
        UpdatePvarsWithAlreadyKnownBooks()
        MyVars.fetchedOldBooks = "true"
    end
    local time = MeasureExecutionTime(UpdateRarityForAllReadBooks)
    BasicPrint(string.format("Books rarity updated in %s ms!", time))
    BasicPrint(string.format("Prefix for read books : %s - Suffix for read books : %s",
        GetMCM("READ_BOOK_PREFIX"),
        GetMCM("READ_BOOK_SUFFIX")))
    --This is dirty but fuck it we ball
    RestoreHandles()
    if not HandlesAlreadyPatched() then
        MarkAllReadBooksAsRead()
    end
end

Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "before", function(root, item, inventoryHolder, addType)
    local bookID = Osi.GetBookID(item)
    if bookID and MOD_READY then
        if MyVars.readBooks and MyVars.readBooks[bookID] then
            MarkBookAsRead(item)
        end
    end
end)


Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", Start)

Ext.Events.ResetCompleted:Subscribe(Start)

Ext.Events.GameStateChanged:Subscribe(function(e)
    if e.ToState == "Save" and MOD_READY then
        GetModVariables()["readBooks"] = MyVars["readBooks"]
    end
    if e.FromState == "Save" and e.ToState == "Running" and MOD_READY then
        UpdateRarityForAllReadBooks()
    end
end)


-- -------------------------------------------------------------------------- --
--                                     MCM                                    --
-- -------------------------------------------------------------------------- --

local debouncedStart = Debounce(Start, 0.800)

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(data)
    if not data or data.modUUID ~= ModuleUUID or not data.settingId then
        return
    end

    if data.settingId == "RARITY" or data.settingId == "READ_BOOK_PREFIX" or data.settingId == "READ_BOOK_SUFFIX" then
        debouncedStart()
    end
end)
