-- lib/checkbox.lua
-- Checkbox UI component

local Assets = require("lib.assets")

local Checkbox = {}
Checkbox.__index = Checkbox

function Checkbox.new(x, y, label, checked)
    local self = setmetatable({}, Checkbox)
    self.x = x
    self.y = y
    self.label = label
    self.checked = checked or false
    self.size = 30 -- Size of the checkbox box
    self.hovered = false
    return self
end

function Checkbox:isInside(mx, my)
    -- Check if mouse is inside the checkbox (box + label area)
    local labelWidth = love.graphics.getFont():getWidth(self.label)
    local totalWidth = self.size + 10 + labelWidth
    return mx >= self.x and mx <= self.x + totalWidth and
           my >= self.y and my <= self.y + self.size
end

function Checkbox:mousemoved(mx, my)
    local wasHovered = self.hovered
    self.hovered = self:isInside(mx, my)

    -- Play hover sound when starting to hover
    if self.hovered and not wasHovered then
        Assets.playSound("snd_button_hover", 0.3)
    end
end

function Checkbox:mousepressed(mx, my, button)
    if button == 1 and self:isInside(mx, my) then
        self.checked = not self.checked
        Assets.playSound("snd_button_press", 0.4)
    end
end

function Checkbox:draw()
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw checkbox box
    if self.checked then
        love.graphics.setColor(0.2, 0.8, 0.2, 1) -- Green when checked
        love.graphics.rectangle("fill", self.x, self.y, self.size, self.size)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", self.x, self.y, self.size, self.size)

        -- Draw checkmark
        love.graphics.setLineWidth(3)
        love.graphics.line(
            self.x + 5, self.y + self.size / 2,
            self.x + self.size / 3, self.y + self.size - 8,
            self.x + self.size - 5, self.y + 5
        )
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0.3, 0.3, 0.3, 1) -- Dark gray when unchecked
        love.graphics.rectangle("fill", self.x, self.y, self.size, self.size)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", self.x, self.y, self.size, self.size)
    end

    -- Draw label
    local labelX = self.x + self.size + 10
    local labelY = self.y + (self.size - love.graphics.getFont():getHeight()) / 2

    if self.hovered then
        love.graphics.setColor(1, 1, 0.5, 1) -- Yellow on hover
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.print(self.label, labelX, labelY)
end

return Checkbox
