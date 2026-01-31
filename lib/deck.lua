-- lib/deck.lua
-- Card deck management system

local Deck = {}
Deck.__index = Deck

-- Card suits and ranks (Watten uses 7-Ace only)
local SUITS = {"clubs", "diamonds", "hearts", "spades"}
local RANKS = {7, 8, 9, 10, 11, 12, 13, 1} -- 1 = Ace

function Deck.new()
    local self = setmetatable({}, Deck)
    self.cards = {}
    self:reset()
    return self
end

function Deck:reset()
    self.cards = {}
    for _, suit in ipairs(SUITS) do
        for _, rank in ipairs(RANKS) do
            -- Ace (rank 1) is high in Watten
            local value = rank == 1 and 14 or rank
            table.insert(self.cards, {
                suit = suit,
                rank = rank,
                value = value
            })
        end
    end
end

function Deck:shuffle()
    for i = #self.cards, 2, -1 do
        local j = love.math.random(1, i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function Deck:draw()
    if #self.cards > 0 then
        return table.remove(self.cards)
    end
    return nil
end

function Deck:count()
    return #self.cards
end

-- Deal cards to multiple players
function Deck:deal(numPlayers, cardsPerPlayer)
    local hands = {}
    for i = 1, numPlayers do
        hands[i] = {}
    end

    for cardNum = 1, cardsPerPlayer do
        for player = 1, numPlayers do
            local card = self:draw()
            if card then
                table.insert(hands[player], card)
            end
        end
    end

    return hands
end

return Deck
