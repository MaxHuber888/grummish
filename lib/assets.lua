-- lib/assets.lua
-- Asset loading and management

local Assets = {
    sprites = {},
    sounds = {}
}

-- Helper function to find PNG in sprite directory
local function findPNG(path)
    local items = love.filesystem.getDirectoryItems(path)
    for _, item in ipairs(items) do
        local fullPath = path .. "/" .. item
        local info = love.filesystem.getInfo(fullPath)
        if info and info.type == "file" and item:match("%.png$") then
            return fullPath
        elseif info and info.type == "directory" then
            local found = findPNG(fullPath)
            if found then return found end
        end
    end
    return nil
end

-- Load a sprite from the sprites directory
function Assets.loadSprite(name)
    local path = "sprites/" .. name
    local pngPath = findPNG(path)
    if pngPath then
        Assets.sprites[name] = love.graphics.newImage(pngPath)
        return Assets.sprites[name]
    end
    return nil
end

-- Load a sound from the sounds directory
function Assets.loadSound(name)
    local path = "sounds/" .. name
    local mp3Path = path .. "/" .. name .. ".mp3"
    if love.filesystem.getInfo(mp3Path) then
        Assets.sounds[name] = love.audio.newSource(mp3Path, "static")
        return Assets.sounds[name]
    end
    return nil
end

-- Get sprite by name
function Assets.getSprite(name)
    if not Assets.sprites[name] then
        Assets.loadSprite(name)
    end
    return Assets.sprites[name]
end

-- Get sound by name
function Assets.getSound(name)
    if not Assets.sounds[name] then
        Assets.loadSound(name)
    end
    return Assets.sounds[name]
end

-- Play a sound effect
function Assets.playSound(name, volume)
    local sound = Assets.getSound(name)
    if sound then
        sound:setVolume(volume or 1.0)
        sound:play()
    end
end

-- Load card sprite based on suit and rank
function Assets.getCardSprite(suit, rank)
    local spriteName = "spr_" .. suit .. "_" .. rank
    return Assets.getSprite(spriteName)
end

return Assets
