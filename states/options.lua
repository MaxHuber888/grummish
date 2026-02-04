-- states/options.lua
-- Game options/settings state

local Assets = require("lib.assets")
local Button = require("lib.button")
local Checkbox = require("lib.checkbox")
local Constants = require("lib.constants")

local Options = {}

function Options:load()
    -- Load background
    self.background = Assets.getSprite("bg_title")

    -- Initialize game options (these will be read by game state)
    if not _G.GameOptions then
        _G.GameOptions = {
            useCriticals = true, -- Default: play with criticals (holy cards)
            useSchleck = true, -- Default: play with schleck (cutting)
            useBlind = false, -- Default: normal trump selection (not blind)
            debugMode = false -- Default: no debug mode (hide opponent info)
        }
    end

    -- Create checkboxes
    local centerX = 800
    local startY = 260

    self.criticalsCheckbox = Checkbox.new(
        centerX - 200, startY,
        "Play with Criticals (King♥, 7♣, 7♠ as highest cards)",
        _G.GameOptions.useCriticals
    )

    self.schleckCheckbox = Checkbox.new(
        centerX - 200, startY + 50,
        "Play with Schleck (Cut deck before dealing)",
        _G.GameOptions.useSchleck
    )

    self.blindCheckbox = Checkbox.new(
        centerX - 200, startY + 100,
        "Blind Watten (Random trump, teammates must guess)",
        _G.GameOptions.useBlind
    )

    self.debugCheckbox = Checkbox.new(
        centerX - 200, startY + 150,
        "Debug Mode (Show all hands and events)",
        _G.GameOptions.debugMode
    )

    self.checkboxes = {self.criticalsCheckbox, self.schleckCheckbox, self.blindCheckbox, self.debugCheckbox}

    -- Create play button
    self.playButton = Button.new(
        centerX - 150, startY + 270,
        300, 60,
        "Play Game",
        function()
            -- Save options
            _G.GameOptions.useCriticals = self.criticalsCheckbox.checked
            _G.GameOptions.useSchleck = self.schleckCheckbox.checked
            _G.GameOptions.useBlind = self.blindCheckbox.checked
            _G.GameOptions.debugMode = self.debugCheckbox.checked
            -- Start game
            GameState:switch("game")
        end
    )

    -- Create back button
    self.backButton = Button.new(
        centerX - 150, startY + 350,
        300, 60,
        "Back to Menu",
        function() GameState:switch("menu") end
    )

    self.buttons = {self.playButton, self.backButton}
end

function Options:enter()
    -- Refresh checkbox state from global options
    if self.criticalsCheckbox then
        self.criticalsCheckbox.checked = _G.GameOptions.useCriticals
    end
    if self.schleckCheckbox then
        self.schleckCheckbox.checked = _G.GameOptions.useSchleck
    end
    if self.blindCheckbox then
        self.blindCheckbox.checked = _G.GameOptions.useBlind
    end
    if self.debugCheckbox then
        self.debugCheckbox.checked = _G.GameOptions.debugMode
    end
end

function Options:update(dt)
end

function Options:draw()
    local scale, winW, winH = Constants.getScale()
    local offsetX, offsetY = Constants.getOffset()

    -- Apply scaling transform
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Draw background
    if self.background then
        love.graphics.setColor(1, 1, 1, 1)
        local scaleX = Constants.DESIGN_WIDTH / self.background:getWidth()
        local scaleY = Constants.DESIGN_HEIGHT / self.background:getHeight()
        love.graphics.draw(self.background, 0, 0, 0, scaleX, scaleY)
    else
        love.graphics.clear(0.1, 0.2, 0.3, 1)
    end

    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(48)
    love.graphics.printf("Game Options", 0, 180, Constants.DESIGN_WIDTH, "center")

    -- Draw description
    love.graphics.setNewFont(20)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("Choose your preferred rules for Watten", 0, 250, Constants.DESIGN_WIDTH, "center")

    -- Draw checkboxes
    love.graphics.setNewFont(24)
    for _, checkbox in ipairs(self.checkboxes) do
        checkbox:draw()
    end

    -- Draw buttons
    for _, button in ipairs(self.buttons) do
        button:draw()
    end

    love.graphics.pop()
end

function Options:mousemoved(x, y)
    local dx, dy = Constants.screenToDesign(x, y)
    for _, checkbox in ipairs(self.checkboxes) do
        checkbox:mousemoved(dx, dy)
    end
    for _, button in ipairs(self.buttons) do
        button:mousemoved(dx, dy)
    end
end

function Options:mousepressed(x, y, button)
    local dx, dy = Constants.screenToDesign(x, y)
    for _, checkbox in ipairs(self.checkboxes) do
        checkbox:mousepressed(dx, dy, button)
    end
    for _, btn in ipairs(self.buttons) do
        btn:mousepressed(dx, dy, button)
    end
end

function Options:mousereleased(x, y, button)
    local dx, dy = Constants.screenToDesign(x, y)
    for _, btn in ipairs(self.buttons) do
        btn:mousereleased(dx, dy, button)
    end
end

return Options
