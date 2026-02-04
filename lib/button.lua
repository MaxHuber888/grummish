-- lib/button.lua
-- Button widget with hover and click support

local Assets = require("lib.assets")

local Button = {}
Button.__index = Button

function Button.new(x, y, width, height, text, callback, sprite, hoverSprite)
    local self = setmetatable({}, Button)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.text = text
    self.callback = callback
    self.sprite = sprite
    self.hoverSprite = hoverSprite
    self.hovered = false
    self.pressed = false
    return self
end

function Button:contains(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.height
end

function Button:mousemoved(x, y)
    local wasHovered = self.hovered
    self.hovered = self:contains(x, y)

    -- Play hover sound on first hover
    if self.hovered and not wasHovered then
        Assets.playSound("button_hover", 0.3)
    end
end

function Button:mousepressed(x, y, button)
    if button == 1 and self:contains(x, y) then
        self.pressed = true
        Assets.playSound("button_press", 0.5)
    end
end

function Button:mousereleased(x, y, button)
    if button == 1 and self.pressed and self:contains(x, y) then
        if self.callback then
            self.callback()
        end
    end
    self.pressed = false
end

function Button:draw()
    -- Draw sprite if available
    if self.sprite then
        local currentSprite = (self.hovered and self.hoverSprite) or self.sprite
        if currentSprite then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(currentSprite, self.x, self.y, 0,
                self.width / currentSprite:getWidth(),
                self.height / currentSprite:getHeight())
        end
    else
        -- Fallback to rectangle button
        if self.hovered then
            love.graphics.setColor(0.3, 0.5, 0.8, 1)
        else
            love.graphics.setColor(0.2, 0.3, 0.6, 1)
        end
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 10, 10)
    end

    -- Draw text
    if self.text then
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(self.text)
        local textHeight = font:getHeight()
        love.graphics.print(self.text,
            self.x + (self.width - textWidth) / 2,
            self.y + (self.height - textHeight) / 2)
    end
end

return Button
