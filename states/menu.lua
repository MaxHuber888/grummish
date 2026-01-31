-- states/menu.lua
-- Main menu state

local Assets = require("lib.assets")
local Button = require("lib.button")

local Menu = {}

-- Design resolution (same as game state)
local DESIGN_WIDTH = 1600
local DESIGN_HEIGHT = 900

-- Get current scale factors
function Menu:getScale()
    local winW, winH = love.graphics.getDimensions()
    local scaleX = winW / DESIGN_WIDTH
    local scaleY = winH / DESIGN_HEIGHT
    local scale = math.min(scaleX, scaleY)
    return scale, winW, winH
end

-- Get offset to center content
function Menu:getOffset()
    local scale, winW, winH = self:getScale()
    local scaledWidth = DESIGN_WIDTH * scale
    local scaledHeight = DESIGN_HEIGHT * scale
    local offsetX = (winW - scaledWidth) / 2
    local offsetY = (winH - scaledHeight) / 2
    return offsetX, offsetY
end

function Menu:load()
    -- Load menu assets
    self.background = Assets.getSprite("spr_bg_title")
    self.titleSprite = Assets.getSprite("spr_menu_title")

    -- Create buttons
    local centerX = 800
    local startY = 450

    self.playButton = Button.new(
        centerX - 150, startY,
        300, 60,
        "Play Game",
        function() GameState:switch("options") end
    )

    self.quitButton = Button.new(
        centerX - 150, startY + 80,
        300, 60,
        "Quit",
        function() love.event.quit() end
    )

    self.buttons = {self.playButton, self.quitButton}
end

function Menu:enter()
    -- Play menu music if available
    local music = Assets.getSound("snd_main_menu_music")
    if music then
        music:setLooping(true)
        music:setVolume(0.3)
        if not music:isPlaying() then
            music:play()
        end
    end
end

function Menu:update(dt)
end

function Menu:draw()
    local scale, winW, winH = self:getScale()
    local offsetX, offsetY = self:getOffset()

    -- Apply scaling transform
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Draw background
    if self.background then
        love.graphics.setColor(1, 1, 1, 1)
        local scaleX = DESIGN_WIDTH / self.background:getWidth()
        local scaleY = DESIGN_HEIGHT / self.background:getHeight()
        love.graphics.draw(self.background, 0, 0, 0, scaleX, scaleY)
    else
        love.graphics.clear(0.1, 0.2, 0.3, 1)
    end

    -- Draw title
    if self.titleSprite then
        love.graphics.setColor(1, 1, 1, 1)
        local titleScale = 0.5
        local titleWidth = self.titleSprite:getWidth() * titleScale
        love.graphics.draw(self.titleSprite, 800 - titleWidth / 2, 120, 0, titleScale, titleScale)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setNewFont(48)
        love.graphics.printf("Watten Card Game", 0, 180, DESIGN_WIDTH, "center")
    end

    -- Draw buttons
    love.graphics.setNewFont(24)
    for _, button in ipairs(self.buttons) do
        button:draw()
    end

    love.graphics.pop()
end

-- Convert screen coordinates to design coordinates
function Menu:screenToDesign(screenX, screenY)
    local scale, winW, winH = self:getScale()
    local offsetX, offsetY = self:getOffset()
    local designX = (screenX - offsetX) / scale
    local designY = (screenY - offsetY) / scale
    return designX, designY
end

function Menu:mousemoved(x, y)
    local dx, dy = self:screenToDesign(x, y)
    for _, button in ipairs(self.buttons) do
        button:mousemoved(dx, dy)
    end
end

function Menu:mousepressed(x, y, button)
    local dx, dy = self:screenToDesign(x, y)
    for _, btn in ipairs(self.buttons) do
        btn:mousepressed(dx, dy, button)
    end
end

function Menu:mousereleased(x, y, button)
    local dx, dy = self:screenToDesign(x, y)
    for _, btn in ipairs(self.buttons) do
        btn:mousereleased(dx, dy, button)
    end
end

return Menu
