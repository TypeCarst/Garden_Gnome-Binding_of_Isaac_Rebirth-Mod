--StartDebug()

local MOD      = RegisterMod("Garden Gnome", 1);
local CHOMPSKI = Isaac.GetTrinketIdByName("Garden Gnome");

isDebug   = true;
debugText = "";

local wasChompskiSpawned = false;
local pickedUpChompski   = false;
local voidPortalSpawned  = false;
local lostChompski       = false;
local droppedRoomIndex; -- nil or index value
local chompskiKeeper;
local portalKeeper;

function MOD:PostUpdate()
    
    local game            = Game();
    local room            = game:GetRoom();
    local level           = game:GetLevel();
    local mainPlayer      = Isaac.GetPlayer(0);
    local holdingChompski = IsAPlayerHoldingChompski(game);
    local reevaluateCache = false;

    local isCoopMode = game:GetNumPlayers() > 1;
    
    if game:GetFrameCount() <= 1 then
        -- reset values on a new run
        for i=0,game:GetNumPlayers() - 1 do
            Init(game, Isaac.GetPlayer(i));
        end
    end
    
    -- check if goal was already reached or chompski was left behind
    if lostChompski or voidPortalSpawned then
        return;
    end
    
    if portalKeeper ~= nil then -- chompski delivered to destination
        -- TODO: check if isaac touches keeper/house --> room:GetGridEntityFromPos(mainPlayer.Position)
        if not voidPortalSpawned and portalKeeper:HasMortalDamage() then

            for i=0, game:GetNumPlayers() - 1 do
                Isaac.GetPlayer(i):AnimateHappy();
            end

            room:SpawnGridEntity(67, GridEntityType.GRID_TRAPDOOR, 0, 0, 1); -- spawn portal to The Void
            voidPortalSpawned = true;
        end
    elseif wasChompskiSpawned then -- logic between spawning and delivering including leaving chompski behind
        if holdingChompski then
            if droppedRoomIndex ~= nil then
                droppedRoomIndex = nil;
                reevaluateCache  = true;
            end
            
            if not pickedUpChompski then
                pickedUpChompski = true;
                reevaluateCache  = true;
            end
        else
            currentRoomIndex = level:GetCurrentRoomIndex();
            if pickedUpChompski then
                pickedUpChompski = false;
                droppedRoomIndex = currentRoomIndex;
                reevaluateCache  = true;
            elseif droppedRoomIndex ~= nil and currentRoomIndex ~= droppedRoomIndex then -- check if Chompski was left behind in another room
                lostChompski = true;
            end
        end
    elseif chompskiKeeper ~= nil then -- found spawn location of chompski
        if chompskiKeeper:HasMortalDamage() then -- check if chompski keeper was destroyed
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, CHOMPSKI, chompskiKeeper.Position, Vector(1, 1), mainPlayer)
            wasChompskiSpawned = true;
        end
    end
    
    -- update player stats if chompski was picked up or dropped
    if reevaluateCache then
        for i=0,game:GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(i);
            if player:HasTrinket(CHOMPSKI) then
                ReevaluateCache(player);
            end
        end
    end
end

function Init(game, player)
    wasChompskiSpawned      = false;
    pickedUpChompski        = false;
    voidPortalSpawned       = false;
    lostChompski            = false;
    removedChompskiFromGame = false;
    droppedRoomIndex        = nil;
    chompskiKeeper          = nil;
    portalKeeper            = nil;
    
    debugText = "";
    
    -- prevent chompski from spawning in other locations
    --local itempool = game:GetItemPool();
    --itempool:RemoveTrinket(CHOMPSKI);
    
    if isDebug then
        player:AddCollectible(CollectibleType.COLLECTIBLE_COMPASS,0,false);
        player:AddCollectible(CollectibleType.COLLECTIBLE_TREASURE_MAP,0,false);
        player:AddCollectible(CollectibleType.COLLECTIBLE_BLUE_MAP,0,false);
        player:AddCollectible(CollectibleType.COLLECTIBLE_SAD_BOMBS,0,false);
    end
end

function IsAPlayerHoldingChompski(game)
    for i=0,game:GetNumPlayers()-1 do
        if Isaac.GetPlayer(i):HasTrinket(CHOMPSKI) then
            return true;
        end
    end

    return false;
end

function ReevaluateCache(player)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE);
    player:AddCacheFlags(CacheFlag.CACHE_SPEED);
    player:EvaluateItems();
end

function MOD:DrawDebugText(text)
    if not isDebug then
        return;
    end
    
     debugText = text;
end

-- add status changes, while holding Chompski
function MOD:OnCache(player, cacheFlag)
    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage - 0.2
    end
    if cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed * 0.8
    end
end

function MOD:OnRoomChange()
    local game       = Game();
    local room       = game:GetRoom();
    local level      = game:GetLevel();     
    local mainPlayer = Isaac.GetPlayer(0);

    local isCoopMode = game:GetNumPlayers() > 1;

    -- spawn goal to deliver chompski to when right level was reached with chompski
    if wasChompskiSpawned and holdingChompski then
        if level:GetStage() == LevelStage.STAGE1_2 and room:GetFrameCount() == 0 then -- Chompski was delivered to The Chest or Dark Room
            local freePosition = room:FindFreePickupSpawnPosition(Vector(80,160), 0, true);
            portalKeeper = Isaac.Spawn(EntityType.ENTITY_SHOPKEEPER, 0, 0, freePosition, Vector(0,0), mainPlayer);

            for i=0,game:GetNumPlayers() - 1 do
                Isaac.GetPlayer(i):TryRemoveTrinket(CHOMPSKI);
            end
            
            return;
        end
    end
  
    -- spawn gnome keeper when entering stage 1_1 secret room for the first time
    if chompskiKeeper == nil then      
        if level:GetStage() == LevelStage.STAGE1_1 and room:GetType() == RoomType.ROOM_SUPERSECRET then
            local freePosition = room:FindFreePickupSpawnPosition(Vector(80,160), 0, true);
            chompskiKeeper = Isaac.Spawn(EntityType.ENTITY_SHOPKEEPER, 1333, 0, freePosition, Vector(0,0), mainPlayer);
        end
        return;
    end
  
    -- remove chompski from game when left behind
    local foundChompskis = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, CHOMPSKI);
    if foundChompskis ~= nil and #foundChompskis >= 1 then
        for i = 1, #foundChompskis do
            foundChompskis[i]:Remove();
        end
    end
end

function MOD:OnRender(t)
    Isaac.RenderText(debugText, 50, 30, 1, 1, 1, 255)
end

MOD:AddCallback(ModCallbacks.MC_POST_UPDATE, MOD.PostUpdate);
MOD:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, MOD.OnCache);
MOD:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MOD.OnRoomChange);
MOD:AddCallback(ModCallbacks.MC_POST_RENDER, MOD.OnRender);