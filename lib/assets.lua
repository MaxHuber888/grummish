-- lib/assets.lua
-- Asset loading and management

local Assets = {
    sprites = {},
    sounds = {}
}

-- Load a sprite from the images directory
-- Searches multiple category directories: cards, backgrounds, ui, effects
function Assets.loadSprite(name)
    local categories = {"cards", "backgrounds", "ui", "effects"}
    for _, category in ipairs(categories) do
        local path = "images/" .. category .. "/" .. name .. ".png"
        if love.filesystem.getInfo(path) then
            Assets.sprites[name] = love.graphics.newImage(path)
            return Assets.sprites[name]
        end
    end
    return nil
end

-- Load a sound from the sounds directory
-- Sounds are now in flat structure: sounds/name.mp3
-- Music files use "stream" type, sound effects use "static"
function Assets.loadSound(name)
    local path = "sounds/" .. name .. ".mp3"
    if love.filesystem.getInfo(path) then
        local soundType = (name:match("music") or name:match("theme")) and "stream" or "static"
        Assets.sounds[name] = love.audio.newSource(path, soundType)
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
    local spriteName = suit .. "_" .. rank
    return Assets.getSprite(spriteName)
end

return Assets
