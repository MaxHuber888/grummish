-- main.lua
-- Watten card game - LÖVE2D implementation

-- Game state manager
local GameState = {
    current = "menu",
    states = {}
}

function GameState:switch(state)
    if self.states[state] then
        self.current = state
        if self.states[state].enter then
            self.states[state]:enter()
        end
    end
end

function GameState:register(name, state)
    self.states[name] = state
end

-- Load all game modules
local Menu = require("states.menu")
local Options = require("states.options")
local Game = require("states.game")

function love.load()
    -- Set up window in fullscreen
    love.window.setTitle("Grummish")
    love.window.setFullscreen(true, "desktop")

    -- Initialize global game options
    _G.GameOptions = {
        useCriticals = true, -- Default: play with criticals (holy cards)
        useSchleck = true, -- Default: play with schleck (cutting)
        useBlind = false, -- Default: normal trump selection (not blind)
        debugMode = false -- Default: no debug mode (hide opponent info)
    }

    -- Register game states
    GameState:register("menu", Menu)
    GameState:register("options", Options)
    GameState:register("game", Game)

    -- Initialize all states
    for _, state in pairs(GameState.states) do
        if state.load then
            state:load()
        end
    end

    -- Start with menu
    GameState:switch("menu")
end

function love.update(dt)
    local state = GameState.states[GameState.current]
    if state and state.update then
        state:update(dt)
    end
end

function love.draw()
    local state = GameState.states[GameState.current]
    if state and state.draw then
        state:draw()
    end
end

function love.mousepressed(x, y, button)
    local state = GameState.states[GameState.current]
    if state and state.mousepressed then
        state:mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    local state = GameState.states[GameState.current]
    if state and state.mousereleased then
        state:mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    local state = GameState.states[GameState.current]
    if state and state.mousemoved then
        state:mousemoved(x, y, dx, dy)
    end
end

function love.keypressed(key)
    -- Let the current state handle escape first
    local state = GameState.states[GameState.current]
    if state and state.keypressed then
        state:keypressed(key)
    end

    -- Global escape handling for non-game states
    if key == "escape" then
        if GameState.current ~= "game" and GameState.current ~= "options" then
            love.event.quit()
        elseif GameState.current == "options" then
            GameState:switch("menu")
        end
    end
end

-- Make GameState globally accessible
_G.GameState = GameState
