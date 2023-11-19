Ext.Require("Server/_ModInfos.lua")
Ext.Require("Shared/_Globals.lua")
Ext.Require("Shared/_Utils.lua")
Ext.Require("Server/_Config.lua")



Ext.Osiris.RegisterListener("GameBookInterfaceClosed", 2, "after", function(item, character)
    MarkBookAsRead(item)
end)

--Check all books and update their rarity if read
function UpdateRarityForAllReadBooks()
    if not Config.GetValue(Config.config_tbl, "UPDATE_RARITY") == 1 then return end
    BasicDebug("UpdateRarityForAllReadBooks()")
    local allEntities = Ext.Entity.GetAllEntitiesWithComponent("ServerItem")
    for k, v in pairs(allEntities) do
        if Osi.GetBookID(v.Uuid.EntityUuid) then
            if PersistentVars.readBooks[Osi.GetBookID(v.Uuid.EntityUuid)] then
                UpdateItemRarity(v)
            end
        end
    end
end

--Updata rarity to green for an item entity
function UpdateItemRarity(entity)
    if Config.GetValue(Config.config_tbl, "UPDATE_RARITY") == 1 then
        entity.Value.Rarity = 1
        entity:Replicate("Value")
        entity:Replicate("Health")
    else
        return
    end
    --BasicPrint("Updating Rarity for item",entity.Uuid.EntityUuid)
end

--Update loca handle for read books
function MarkAllReadBooksAsRead()
    for k, handle in pairs(PersistentVars.readBooks) do
        UpdateBookName(handle)
    end
end

--function to add to list of read books & do cosmetic changes
function MarkBookAsRead(book)
    local bookEntity = Ext.Entity.Get(book)
    UpdateItemRarity(bookEntity)
    local bookId = Osi.GetBookID(book)
    local handle = Osi.GetDisplayName(book)
    if not PersistentVars.readBooks[bookId] then
        BasicDebug("MarkBookAsRead() - Marking unread book as read, bookID : " .. bookId)
        PersistentVars.readBooks[bookId] = handle
        if not HandleAlreadyPatched(handle) then
            UpdateBookName(handle)
        end
    end
end

--Update book name with pre/suf
function UpdateBookName(handle)
    BasicDebug("UpdateBookName() - Before Name Update : " .. GetTranslatedString(handle))
    UpdateTranslatedString(handle,
        Config.GetValue(Config.config_tbl, "READ_BOOK_PREFIX") ..
        GetTranslatedString(handle) .. Config.GetValue(Config.config_tbl, "READ_BOOK_SUFFIX"))
    BasicDebug("UpdateBookName() - After Name Update : " .. GetTranslatedString(handle))
end

--check a if a specific loca is already changed
function HandleAlreadyPatched(handle)
    local locaName = GetTranslatedString(handle)
    local prefix, suffix = Config.GetValue(Config.config_tbl, "READ_BOOK_PREFIX"),
        Config.GetValue(Config.config_tbl, "READ_BOOK_SUFFIX")
    if #prefix > 0 and StartsWith(locaName, prefix) then
        --BasicDebug("HandlesAlreadyPatched() - Handles already patched")
        return true
    elseif #suffix > 0 and EndsWith(locaName, suffix) then
        --BasicDebug("HandlesAlreadyPatched() - Handles already patched")
        return true
    end
    --BasicDebug("HandlesAlreadyPatched() - Handles not already patched")
    return false
end

--Check if we already changed the locas for this game session
function HandlesAlreadyPatched()
    if PersistentVars.readBooks then
        local firstKey = next(PersistentVars.readBooks)
        local firstElement = PersistentVars.readBooks[firstKey]
        local locaName = GetTranslatedString(firstElement)
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

function Start()
    if not Config.initDone then Config.Init() end
    if not PersistentVars.readBooks then PersistentVars.readBooks = {} end
    local time = MeasureExecutionTime(UpdateRarityForAllReadBooks)
    BasicPrint("Books rarity updated in " .. time .. " ms!")
    BasicPrint(string.format("Prefix for read books : %s - Suffix for read books : %s",
        Config.GetValue(Config.config_tbl, "READ_BOOK_PREFIX"), Config.GetValue(Config.config_tbl, "READ_BOOK_SUFFIX")))
    if not HandlesAlreadyPatched() then
        MarkAllReadBooksAsRead()
    end
end

Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "before", function(root, item, inventoryHolder, addType)
    if Osi.GetBookID(item) then
        MarkBookAsRead(item)
    end
end)

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", Start)

Ext.Events.ResetCompleted:Subscribe(Start)

Ext.Events.GameStateChanged:Subscribe(function(e)
    if e.FromState == "Save" and e.ToState == "Running" then
        UpdateRarityForAllReadBooks()
    end
end)
