-- states/game.lua
-- Main game state for Watten card game

local Deck = require("lib.deck")
local Assets = require("lib.assets")
local Button = require("lib.button")

local Game = {}

-- Rank names for display
local RANK_NAMES = {
    [1] = "Ace", [2] = "2", [3] = "3", [4] = "4", [5] = "5",
    [6] = "6", [7] = "7", [8] = "8", [9] = "9", [10] = "10",
    [11] = "Jack", [12] = "Queen", [13] = "King"
}

local SUIT_NAMES = {
    clubs = "Clubs", diamonds = "Diamonds",
    hearts = "Hearts", spades = "Spades"
}

-- Holy cards helper function
local function isHolyCard(card)
    -- Check if criticals are enabled
    if not _G.GameOptions or not _G.GameOptions.useCriticals then
        return false
    end

    -- King of Hearts (1st), 7 of Clubs (2nd), 7 of Spades (3rd)
    if card.rank == 13 and card.suit == "hearts" then
        return 1 -- King of Hearts
    elseif card.rank == 7 and card.suit == "clubs" then
        return 2 -- 7 of Clubs
    elseif card.rank == 7 and card.suit == "spades" then
        return 3 -- 7 of Spades
    end
    return false
end

-- Design resolution (base for scaling)
local DESIGN_WIDTH = 1600
local DESIGN_HEIGHT = 900

function Game:load()
    self.background = Assets.getSprite("spr_bg")
    -- Initialize particle system for holy cards
    self.particles = {}

    -- Create pause menu buttons
    local centerX = 800
    local startY = 350

    self.pauseResumeButton = Button.new(
        centerX - 150, startY,
        300, 60,
        "Resume Game",
        function() self.paused = false end
    )

    self.pauseNewGameButton = Button.new(
        centerX - 150, startY + 80,
        300, 60,
        "New Game",
        function()
            self.paused = false
            self:enter() -- Restart the game
        end
    )

    self.pauseMenuButton = Button.new(
        centerX - 150, startY + 160,
        300, 60,
        "Main Menu",
        function()
            self.paused = false
            GameState:switch("menu")
        end
    )

    self.pauseQuitButton = Button.new(
        centerX - 150, startY + 240,
        300, 60,
        "Quit",
        function() love.event.quit() end
    )

    self.pauseButtons = {
        self.pauseResumeButton,
        self.pauseNewGameButton,
        self.pauseMenuButton,
        self.pauseQuitButton
    }
end

-- Get current scale factors
function Game:getScale()
    local winW, winH = love.graphics.getDimensions()
    local scaleX = winW / DESIGN_WIDTH
    local scaleY = winH / DESIGN_HEIGHT
    local scale = math.min(scaleX, scaleY) -- Use minimum to maintain aspect ratio
    return scale, winW, winH
end

-- Scale a value
function Game:s(value)
    local scale = self:getScale()
    return value * scale
end

-- Get offset to center content when window is wider/taller than aspect ratio
function Game:getOffset()
    local scale, winW, winH = self:getScale()
    local scaledWidth = DESIGN_WIDTH * scale
    local scaledHeight = DESIGN_HEIGHT * scale
    local offsetX = (winW - scaledWidth) / 2
    local offsetY = (winH - scaledHeight) / 2
    return offsetX, offsetY
end

function Game:enter()
    -- Initialize overall game state
    self.gameScore = {0, 0} -- Points across all hands (0-11)
    self.dealer = 4 -- Start with player 4 as dealer (player 1 will go first)
    self.gameOver = false
    self.overallWinner = nil
    self.paused = false

    -- Stop menu music, start game music
    local menuMusic = Assets.getSound("snd_main_menu_music")
    if menuMusic then menuMusic:stop() end
    local gameMusic = Assets.getSound("snd_game_music")
    if gameMusic then
        gameMusic:setLooping(true)
        gameMusic:setVolume(0.2)
        gameMusic:play()
    end

    -- Start first hand
    self:startNewHand()
end

function Game:startNewHand()
    -- Rotate dealer
    self.dealer = (self.dealer % 4) + 1

    -- Initialize deck (shuffle but don't deal yet)
    self.deck = Deck.new()
    self.deck:shuffle()
    Assets.playSound("snd_card_deck_shuffle", 0.5)

    -- Trump selection
    self.trumpRank = nil
    self.trumpSuit = nil

    -- Player to dealer's left selects rank first (and cuts)
    self.rankSelector = (self.dealer % 4) + 1
    self.suitSelector = self.dealer
    self.cutter = self.rankSelector -- Cutter is the rank selector

    -- Hand state
    self.currentPlayer = self.rankSelector -- First player goes first
    self.playedCards = {}
    self.tricksWon = {0, 0} -- Tricks this hand
    self.handOver = false
    self.handWinner = nil

    -- Start with cutting phase if both criticals and schleck are enabled
    if _G.GameOptions and _G.GameOptions.useCriticals and _G.GameOptions.useSchleck then
        self.phase = "cutting" -- New phase: cutting the deck
        self.cutCard = nil -- The card revealed by cutting
        self.cutResult = nil -- Message about the cut result
        self.cutResultTimer = 0
    else
        -- Skip cutting and deal immediately
        self.hands = self.deck:deal(4, 5)
        self.phase = "selecting_rank"
    end

    -- Timers
    self.aiTimer = 0
    self.aiDelay = 1.5
    self.phaseTimer = 0

    -- UI state
    self.mouseX = 0
    self.mouseY = 0
    self.selectionButtons = {}

    -- Trigger AI actions if needed
    if self.phase == "cutting" and self.cutter ~= 1 then
        self.aiTimer = self.aiDelay
    elseif self.phase == "selecting_rank" and self.rankSelector ~= 1 then
        self.aiTimer = self.aiDelay
    end

    -- Initialize particles for this hand
    self.particles = {}
    self.particleTimer = 0

    -- Card animation state
    self.cardAnimations = {}
end

function Game:update(dt)
    if self.gameOver or self.paused then return end

    self.phaseTimer = self.phaseTimer + dt

    -- Update particles
    self.particleTimer = self.particleTimer + dt
    if self.particleTimer >= 0.05 then -- Spawn particles every 0.05 seconds
        self:spawnHolyCardParticles()
        self.particleTimer = 0
    end
    self:updateParticles(dt)

    if self.phase == "cutting" then
        -- Handle cut result display timer
        if self.cutCard then
            self.cutResultTimer = self.cutResultTimer + dt
            if self.cutResultTimer >= 2.5 then
                -- Proceed to dealing and selecting rank
                self:finishCutting()
            end
        elseif self.cutter ~= 1 then
            -- AI performs cut automatically
            self.aiTimer = self.aiTimer + dt
            if self.aiTimer >= self.aiDelay then
                self:performCut()
                self.aiTimer = 0
            end
        end
    elseif self.phase == "selecting_rank" then
        if self.rankSelector ~= 1 then
            self.aiTimer = self.aiTimer + dt
            if self.aiTimer >= self.aiDelay then
                self:selectAIRank()
                self.aiTimer = 0
            end
        end
    elseif self.phase == "selecting_suit" then
        if self.suitSelector ~= 1 then
            self.aiTimer = self.aiTimer + dt
            if self.aiTimer >= self.aiDelay then
                self:selectAISuit()
                self.aiTimer = 0
            end
        end
    elseif self.phase == "trick_complete" then
        -- Wait 1 second before starting animation (only start once)
        if not self.trickAnimationStarted and self.phaseTimer >= 1.0 then
            self:startCardAnimations(self.trickWinner)
            self.trickAnimationStarted = true
        end

        -- Update card animations
        if self.trickAnimationStarted then
            self:updateCardAnimations(dt)
        end

        -- Wait for animation to complete before starting next trick
        if self.phaseTimer >= 2.5 then
            self:startNextTrick()
        end
    elseif self.phase == "hand_complete" then
        if self.phaseTimer >= 3.0 then
            self:startNewHand()
        end
    elseif self.phase == "playing" then
        -- AI turn
        if self.currentPlayer ~= 1 then
            self.aiTimer = self.aiTimer + dt
            if self.aiTimer >= self.aiDelay then
                self:playAICard()
                self.aiTimer = 0
            end
        end
    end
end

-- Cutting Logic (Schleck/Lick)
function Game:performCut()
    -- Select a random card from the deck as the "cut" card
    local cutIndex = love.math.random(1, #self.deck.cards)
    self.cutCard = self.deck.cards[cutIndex]

    -- Play card flip sound
    Assets.playSound("snd_card_flip_1", 0.5)

    -- Check if it's a critical
    local isCritical = isHolyCard(self.cutCard)

    if isCritical then
        -- Cutter gets to keep the critical card!
        table.remove(self.deck.cards, cutIndex)
        self.cutResult = "Critical! Player " .. self.cutter .. " keeps the " ..
                        RANK_NAMES[self.cutCard.rank] .. " of " ..
                        SUIT_NAMES[self.cutCard.suit] .. "!"
    else
        -- Normal card, just show it and put it back
        self.cutResult = "Player " .. self.cutter .. " cut the " ..
                        RANK_NAMES[self.cutCard.rank] .. " of " ..
                        SUIT_NAMES[self.cutCard.suit] .. "."
    end

    -- Start timer to show result
    self.cutResultTimer = 0
end

function Game:finishCutting()
    -- If the cutter got a critical, initialize their hand with it
    self.hands = {}
    for i = 1, 4 do
        self.hands[i] = {}
    end

    -- Add the cut card to cutter's hand if it was a critical
    if isHolyCard(self.cutCard) then
        table.insert(self.hands[self.cutter], self.cutCard)
    end

    -- Deal the remaining cards (5 to each player, or 4 to cutter if they got a critical)
    for player = 1, 4 do
        local cardsToDeal = (player == self.cutter and isHolyCard(self.cutCard)) and 4 or 5
        for i = 1, cardsToDeal do
            local card = self.deck:draw()
            if card then
                table.insert(self.hands[player], card)
            end
        end
    end

    -- Clear cut state
    self.cutCard = nil
    self.cutResult = nil
    self.cutResultTimer = 0

    -- Move to rank selection phase
    self.phase = "selecting_rank"

    -- Trigger AI trump selection if needed
    if self.rankSelector ~= 1 then
        self.aiTimer = self.aiDelay
    end
end

-- Trump Selection Logic
function Game:selectAIRank()
    local hand = self.hands[self.rankSelector]
    local rankCounts = {}

    -- Count each rank
    for _, card in ipairs(hand) do
        rankCounts[card.rank] = (rankCounts[card.rank] or 0) + 1
    end

    -- Find rank with most cards, or lowest if no duplicates
    local bestRank = 13
    local bestCount = 0
    for rank, count in pairs(rankCounts) do
        if count > bestCount or (count == bestCount and rank < bestRank) then
            bestRank = rank
            bestCount = count
        end
    end

    self:selectRank(bestRank)
end

function Game:selectRank(rank)
    self.trumpRank = rank
    self.phase = "selecting_suit"
    self.phaseTimer = 0
    self.aiTimer = self.suitSelector ~= 1 and self.aiDelay or 0
    Assets.playSound("snd_button_press", 0.5)
end

function Game:selectAISuit()
    local hand = self.hands[self.suitSelector]
    local suitValues = {clubs = 0, diamonds = 0, hearts = 0, spades = 0}

    -- Sum values for each suit
    for _, card in ipairs(hand) do
        suitValues[card.suit] = suitValues[card.suit] + card.value
    end

    -- Find suit with highest total value
    local bestSuit = "clubs"
    local bestValue = 0
    for suit, value in pairs(suitValues) do
        if value > bestValue then
            bestSuit = suit
            bestValue = value
        end
    end

    self:selectSuit(bestSuit)
end

function Game:selectSuit(suit)
    self.trumpSuit = suit
    self.phase = "playing"
    self.phaseTimer = 0
    self.aiTimer = 0
    Assets.playSound("snd_button_press", 0.5)
end

-- Card Playing Logic
function Game:playAICard()
    local hand = self.hands[self.currentPlayer]
    if #hand == 0 then return end

    -- Get valid cards
    local validCards = {}
    for i, card in ipairs(hand) do
        if self:isCardPlayValid(card, self.currentPlayer) then
            table.insert(validCards, {card = card, index = i})
        end
    end

    if #validCards == 0 then
        -- Fallback: if no valid card found, play first (shouldn't happen)
        local card = table.remove(hand, 1)
        self:playCard(card, self.currentPlayer)
        return
    end

    -- Smart AI logic
    local selectedCard = nil

    if #self.playedCards == 0 then
        -- First to play: play highest card to try to win
        selectedCard = self:getHighestCard(validCards)
    else
        -- Determine current winning player and card
        local winningPlayer = self:evaluateTrickSoFar()
        local teammateIsWinning = self:areTeammates(self.currentPlayer, winningPlayer)

        if teammateIsWinning then
            -- Teammate is winning: play lowest card (don't waste good cards)
            selectedCard = self:getLowestCard(validCards)
        else
            -- Opponent is winning: try to beat it if possible
            local winningCards = self:getWinningCards(validCards)
            if #winningCards > 0 then
                -- Can beat it: play the lowest winning card (don't waste high cards)
                selectedCard = self:getLowestCard(winningCards)
            else
                -- Can't beat it: throw away lowest card
                selectedCard = self:getLowestCard(validCards)
            end
        end
    end

    -- Play the selected card
    if selectedCard then
        for i, cardInfo in ipairs(hand) do
            if cardInfo == selectedCard.card then
                table.remove(hand, i)
                self:playCard(selectedCard.card, self.currentPlayer)
                return
            end
        end
        -- If exact match fails, use the stored index
        table.remove(hand, selectedCard.index)
        self:playCard(selectedCard.card, self.currentPlayer)
    end
end

function Game:areTeammates(player1, player2)
    -- Team 1: Players 1 and 3
    -- Team 2: Players 2 and 4
    return (player1 == 1 or player1 == 3) == (player2 == 1 or player2 == 3)
end

function Game:evaluateTrickSoFar()
    -- Find the currently winning player based on cards played so far
    if #self.playedCards == 0 then return nil end

    local winningPlayer = self.playedCards[1].player
    local winningCard = self.playedCards[1].card
    local winningScore = self:getCardScore(winningCard)

    for i = 2, #self.playedCards do
        local card = self.playedCards[i].card
        local score = self:getCardScore(card)
        if score > winningScore then
            winningScore = score
            winningCard = card
            winningPlayer = self.playedCards[i].player
        end
    end

    return winningPlayer
end

function Game:getWinningCards(validCards)
    -- Return cards that would win the current trick
    if #self.playedCards == 0 then return validCards end

    local currentWinningScore = 0
    for _, played in ipairs(self.playedCards) do
        local score = self:getCardScore(played.card)
        if score > currentWinningScore then
            currentWinningScore = score
        end
    end

    local winningCards = {}
    for _, cardInfo in ipairs(validCards) do
        local score = self:getCardScore(cardInfo.card)
        if score > currentWinningScore then
            table.insert(winningCards, cardInfo)
        end
    end
    return winningCards
end

function Game:getLowestCard(cards)
    -- Return the card with the lowest score
    if #cards == 0 then return nil end

    local lowest = cards[1]
    local lowestScore = self:getCardScore(lowest.card)

    for _, cardInfo in ipairs(cards) do
        local score = self:getCardScore(cardInfo.card)
        if score < lowestScore then
            lowestScore = score
            lowest = cardInfo
        end
    end
    return lowest
end

function Game:getHighestCard(cards)
    -- Return the card with the highest score
    if #cards == 0 then return nil end

    local highest = cards[1]
    local highestScore = self:getCardScore(highest.card)

    for _, cardInfo in ipairs(cards) do
        local score = self:getCardScore(cardInfo.card)
        if score > highestScore then
            highestScore = score
            highest = cardInfo
        end
    end
    return highest
end

function Game:isCardPlayValid(card, player)
    -- Always valid if no cards played yet or it's the first card
    if #self.playedCards == 0 then
        return true
    end

    local firstCard = self.playedCards[1].card

    -- Holy cards can always be played
    if isHolyCard(card) then
        return true
    end

    -- If first card is holy, it doesn't belong to any suit - any card can be played
    if isHolyCard(firstCard) then
        return true
    end

    -- If first card is NOT trump suit, any card can be played
    if firstCard.suit ~= self.trumpSuit then
        return true
    end

    -- First card IS trump suit - must follow suit or beat it
    local hand = self.hands[player]

    -- Check if this card is the highest card in the game (trump rank + trump suit)
    local isHighestCard = (card.rank == self.trumpRank and card.suit == self.trumpSuit)
    if isHighestCard then
        return true -- Highest card can always be played
    end

    -- Check if player has any trump suit cards (excluding holy cards)
    local hasTrumpSuit = false
    for _, c in ipairs(hand) do
        if c.suit == self.trumpSuit and not isHolyCard(c) then
            hasTrumpSuit = true
            break
        end
    end

    -- If player has no trump suit, any card is valid
    if not hasTrumpSuit then
        return true
    end

    -- Player has trump suit - must play trump suit or beat the first card
    if card.suit == self.trumpSuit then
        return true -- Following suit
    end

    -- Check if card can beat the first card
    local cardScore = self:getCardScore(card)
    local firstCardScore = self:getCardScore(firstCard)
    if cardScore > firstCardScore then
        return true -- Can beat it
    end

    -- Cannot play this card
    return false
end

function Game:playCard(card, player)
    table.insert(self.playedCards, {card = card, player = player})

    local soundVariant = love.math.random(1, 4)
    Assets.playSound("snd_one_card_placed_" .. soundVariant, 0.4)

    if #self.playedCards == 4 then
        self:completeTrick()
    else
        self.currentPlayer = (self.currentPlayer % 4) + 1
    end
end

function Game:completeTrick()
    -- Find winning card considering trumps
    local winningPlayer = self:evaluateTrick()

    -- Award trick to team
    local team = (winningPlayer == 1 or winningPlayer == 3) and 1 or 2
    self.tricksWon[team] = self.tricksWon[team] + 1

    Assets.playSound("snd_three_cards_placed", 0.5)

    -- Store winning player for later animation
    self.trickWinner = winningPlayer

    -- Check if hand is over (first to 3 tricks wins hand)
    -- But don't end immediately - let the trick animation play first
    if self.tricksWon[1] >= 3 then
        self.handShouldEnd = 1 -- Mark that hand should end after animation
    elseif self.tricksWon[2] >= 3 then
        self.handShouldEnd = 2 -- Mark that hand should end after animation
    else
        self.handShouldEnd = nil
    end

    -- Always enter trick_complete phase to show animation
    self.currentPlayer = winningPlayer
    self.phase = "trick_complete"
    self.phaseTimer = 0
    self.trickAnimationStarted = false -- Track if we've started the animation
end

function Game:evaluateTrick()
    -- Trump evaluation: trump suit+rank > trump rank > trump suit > regular cards
    local winningPlayer = self.playedCards[1].player
    local winningCard = self.playedCards[1].card
    local winningScore = self:getCardScore(winningCard)

    for i = 2, #self.playedCards do
        local card = self.playedCards[i].card
        local score = self:getCardScore(card)

        if score > winningScore then
            winningScore = score
            winningCard = card
            winningPlayer = self.playedCards[i].player
        end
    end

    return winningPlayer
end

function Game:getCardScore(card)
    -- Scoring hierarchy (higher = stronger):
    -- 1. Holy cards (always trump, regardless of selected trump)
    -- 2. Rechte (trump rank + trump suit together)
    -- 3. Trump rank cards (any suit with the trump rank)
    -- 4. Trump suit cards (any card of trump suit that isn't trump rank)
    -- 5. Regular cards (non-trump)

    local holy = isHolyCard(card)
    if holy then
        -- Holy cards: King♥ (10000), 7♣ (9000), 7♠ (8000)
        return 10000 - (holy - 1) * 1000
    end

    local isTrumpRank = (card.rank == self.trumpRank)
    local isTrumpSuit = (card.suit == self.trumpSuit)

    if isTrumpRank and isTrumpSuit then
        -- Rechte: 5000 (beats all other trumps except holy cards)
        return 5000
    elseif isTrumpRank then
        -- Trump rank: 3000-3014 (beats trump suit)
        return 3000 + card.value
    elseif isTrumpSuit then
        -- Trump suit: 1000-1014 (beats all non-trump cards)
        return 1000 + card.value
    else
        -- Regular cards: 7-14
        return card.value
    end
end

function Game:startNextTrick()
    -- Check if hand should end after the trick animation
    if self.handShouldEnd then
        local winningTeam = self.handShouldEnd
        self.handShouldEnd = nil
        self:endHand(winningTeam)
        return
    end

    -- Continue to next trick
    self.playedCards = {}
    self.phase = "playing"
    self.phaseTimer = 0
    self.aiTimer = 0
end

function Game:endHand(winningTeam)
    self.handOver = true
    self.handWinner = winningTeam
    self.gameScore[winningTeam] = self.gameScore[winningTeam] + 2

    -- Check if game is over
    if self.gameScore[1] >= 11 then
        self:endGame(1)
    elseif self.gameScore[2] >= 11 then
        self:endGame(2)
    else
        self.phase = "hand_complete"
        self.phaseTimer = 0
    end

    -- Play hand win sound
    if winningTeam == 1 then
        Assets.playSound("snd_game_win", 0.4)
    else
        Assets.playSound("snd_game_lose", 0.4)
    end
end

function Game:endGame(winningTeam)
    self.gameOver = true
    self.overallWinner = winningTeam
    Assets.playSound(winningTeam == 1 and "snd_game_win" or "snd_game_lose", 0.6)
end

-- Card Animation System
function Game:startCardAnimations(winningPlayer)
    self.cardAnimations = {}

    -- Get winner position (updated for new layout)
    local winnerPositions = {
        {800, 660},   -- Bottom
        {140, 450},   -- Left
        {800, 120},   -- Top
        {1460, 450}   -- Right
    }
    local targetPos = winnerPositions[winningPlayer]

    -- Center positions where cards start
    local startPositions = {
        {800, 500}, {650, 450}, {800, 400}, {950, 450}
    }

    -- Create animation for each played card
    for i, played in ipairs(self.playedCards) do
        local startPos = startPositions[played.player]
        table.insert(self.cardAnimations, {
            card = played.card,
            player = played.player,
            x = startPos[1],
            y = startPos[2],
            startX = startPos[1],
            startY = startPos[2],
            targetX = targetPos[1],
            targetY = targetPos[2],
            progress = 0,
            alpha = 1
        })
    end
end

function Game:updateCardAnimations(dt)
    if not self.cardAnimations then return end

    local animSpeed = 1.5 -- Animation takes ~0.67 seconds
    local allComplete = true

    for _, anim in ipairs(self.cardAnimations) do
        if anim.progress < 1 then
            allComplete = false
            anim.progress = math.min(anim.progress + dt * animSpeed, 1)

            -- Ease-out movement
            local t = anim.progress
            local eased = 1 - (1 - t) * (1 - t)

            anim.x = anim.startX + (anim.targetX - anim.startX) * eased
            anim.y = anim.startY + (anim.targetY - anim.startY) * eased
            anim.alpha = 1 - anim.progress
        end
    end

    -- When animation completes, clear the array (cards disappear)
    if allComplete then
        self.cardAnimations = {}
    end
end

-- Particle System for Holy Cards
function Game:spawnHolyCardParticles()
    -- Skip particle spawning if criticals are disabled
    if not _G.GameOptions or not _G.GameOptions.useCriticals then
        return
    end

    -- Skip if hands haven't been dealt yet (during cutting phase)
    if not self.hands or not self.hands[1] then
        return
    end

    -- Spawn particles around holy cards in player's hand and played cards
    local playerHand = self.hands[1]
    local playerX = 800
    local playerY = 750

    -- Player's hand (cards are 110x145)
    for i, card in ipairs(playerHand) do
        if isHolyCard(card) then
            local cardX = playerX - (#playerHand * 65) + (i - 1) * 130 + 55
            local cardY = playerY + 72
            self:createParticle(cardX, cardY, isHolyCard(card))
        end
    end

    -- Played cards (cards are 110x150) - don't spawn during animation
    if not self.cardAnimations or #self.cardAnimations == 0 then
        local positions = {
            {800, 500}, {650, 450}, {800, 400}, {950, 450}
        }
        for _, played in ipairs(self.playedCards) do
            if isHolyCard(played.card) then
                local pos = positions[played.player]
                self:createParticle(pos[1], pos[2], isHolyCard(played.card))
            end
        end
    end
end

function Game:createParticle(x, y, holyLevel)
    -- Create a golden shimmer particle
    local angle = love.math.random() * math.pi * 2
    local speed = 20 + love.math.random() * 30
    local colors = {
        {1, 0.843, 0}, -- Gold
        {1, 0.92, 0.2}, -- Light gold
        {1, 1, 0.5}  -- Pale gold
    }
    local color = colors[love.math.random(1, 3)]

    table.insert(self.particles, {
        x = x + (love.math.random() - 0.5) * 100,
        y = y + (love.math.random() - 0.5) * 130,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed - 30,
        life = 0.8 + love.math.random() * 0.4,
        maxLife = 1.2,
        size = 2 + love.math.random() * 2,
        color = color
    })
end

function Game:updateParticles(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 50 * dt -- Gravity
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function Game:drawParticles()
    for _, p in ipairs(self.particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
end

-- Drawing Functions
function Game:draw()
    local scale, winW, winH = self:getScale()
    local offsetX, offsetY = self:getOffset()

    -- Apply scaling transform
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Background
    if self.background then
        love.graphics.setColor(1, 1, 1, 1)
        local scaleX = DESIGN_WIDTH / self.background:getWidth()
        local scaleY = DESIGN_HEIGHT / self.background:getHeight()
        love.graphics.draw(self.background, 0, 0, 0, scaleX, scaleY)
    else
        love.graphics.clear(0.1, 0.3, 0.2, 1)
    end

    -- Draw players (adjusted positions and sizes) - skip during cutting phase
    if self.phase ~= "cutting" then
        self:drawPlayer(1, 800, 750, "You", true, 0)          -- Bottom (human) - moved further down to prevent overlap
        self:drawPlayer(2, 140, 450, "Left", false, math.pi/2) -- Left - rotated 90°, moved in
        self:drawPlayer(3, 800, 60, "Top", false, 0)          -- Top - moved further up to prevent overlap
        self:drawPlayer(4, 1460, 450, "Right", false, -math.pi/2) -- Right - rotated -90°, moved in
    end

    -- Draw played cards
    if self.phase == "playing" then
        -- Normal play: show static cards
        self:drawPlayedCards()
    elseif self.phase == "trick_complete" then
        if not self.trickAnimationStarted then
            -- Before animation: show static cards
            self:drawPlayedCards()
        elseif self.cardAnimations and #self.cardAnimations > 0 then
            -- During animation: show animated cards only (don't show after animation completes)
            self:drawPlayedCards()
        end
        -- After animation completes (empty cardAnimations), draw nothing - no flash!
    end

    -- Draw particles
    self:drawParticles()

    -- Draw HUD
    self:drawHUD()

    -- Draw phase-specific UI
    if self.phase == "cutting" then
        self:drawCutting()
    elseif self.phase == "selecting_rank" and self.rankSelector == 1 then
        self:drawRankSelection()
    elseif self.phase == "selecting_suit" and self.suitSelector == 1 then
        self:drawSuitSelection()
    end

    -- Draw game over
    if self.gameOver then
        self:drawGameOver()
    elseif self.phase == "hand_complete" then
        self:drawHandComplete()
    end

    -- Draw pause menu (on top of everything)
    if self.paused then
        self:drawPauseMenu()
    end

    love.graphics.pop()
end

function Game:drawPlayer(player, x, y, name, showCards, rotation)
    rotation = rotation or 0

    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)

    -- Dealer indicator
    if player == self.dealer then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setNewFont(16)
        love.graphics.print("D", -65, -30)
    end

    -- Player name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(18)
    love.graphics.printf(name, -50, -30, 100, "center")

    local hand = self.hands[player]
    local cardBack = Assets.getSprite("spr_card_back")

    if showCards then
        -- Player cards: 110x145 (slightly smaller)
        local cardW, cardH = 110, 145
        for i, card in ipairs(hand) do
            -- Improved spacing: 130px apart (was 120px)
            local cardX = -(#hand * 65) + (i - 1) * 130
            local cardY = 0

            -- Add floaty wobble effect for player 1's hand
            if player == 1 then
                local time = love.timer.getTime()
                local wobbleSpeed = 1.5 -- How fast the wobble oscillates
                local wobbleAmplitude = 4 -- How much vertical movement (pixels)
                local phaseOffset = i * 0.4 -- Each card wobbles at a different phase
                cardY = cardY + math.sin(time * wobbleSpeed + phaseOffset) * wobbleAmplitude
            end

            local cardSprite = Assets.getCardSprite(card.suit, card.rank)
            local isHovered = self:isCardHovered(x + cardX, y + cardY, cardW, cardH, rotation)

            if self.phase == "playing" and self.currentPlayer == 1 and isHovered then
                cardY = cardY - 20
            end

            -- Draw glow for holy cards
            if isHolyCard(card) then
                love.graphics.setColor(1, 0.843, 0, 0.3)
                love.graphics.rectangle("fill", cardX - 4, cardY - 4, cardW + 8, cardH + 8, 10, 10)
            end

            if cardSprite then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(cardSprite, cardX, cardY, 0,
                    cardW / cardSprite:getWidth(), cardH / cardSprite:getHeight())
            else
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 5, 5)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.setNewFont(20)
                love.graphics.printf(card.rank .. "\n" .. card.suit:sub(1,1):upper(),
                    cardX, cardY + 40, cardW, "center")
            end
        end
    else
        -- Opponent face-down cards: 65x85
        local cardW, cardH = 65, 85
        for i = 1, #hand do
            -- Improved spacing: 77px apart (proportional to player cards)
            local cardX = -(#hand * 38.5) + (i - 1) * 77
            local cardY = 0

            if cardBack then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(cardBack, cardX, cardY, 0,
                    cardW / cardBack:getWidth(), cardH / cardBack:getHeight())
            else
                love.graphics.setColor(0.5, 0.5, 0.8, 1)
                love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 5, 5)
            end
        end
    end

    love.graphics.pop()
end

function Game:drawPlayedCards()
    -- Bigger cards (110x150)
    local cardW, cardH = 110, 150

    -- If animating, draw animated cards
    if self.cardAnimations and #self.cardAnimations > 0 then
        for _, anim in ipairs(self.cardAnimations) do
            local cardSprite = Assets.getCardSprite(anim.card.suit, anim.card.rank)

            -- Rotation based on player (0 for top/bottom, 90 for left, -90 for right)
            local rotation = 0
            if anim.player == 2 then rotation = math.pi / 2 end  -- Left: 90 degrees
            if anim.player == 4 then rotation = -math.pi / 2 end -- Right: -90 degrees

            -- Draw glow for holy cards
            if isHolyCard(anim.card) then
                love.graphics.setColor(1, 0.843, 0, 0.3 * anim.alpha)
                if rotation == 0 then
                    love.graphics.rectangle("fill", anim.x - cardW/2 - 4, anim.y - cardH/2 - 4,
                        cardW + 8, cardH + 8, 8, 8)
                else
                    love.graphics.rectangle("fill", anim.x - cardH/2 - 4, anim.y - cardW/2 - 4,
                        cardH + 8, cardW + 8, 8, 8)
                end
            end

            if cardSprite then
                love.graphics.setColor(1, 1, 1, anim.alpha)
                local scaleW = cardW / cardSprite:getWidth()
                local scaleH = cardH / cardSprite:getHeight()
                love.graphics.draw(cardSprite, anim.x, anim.y, rotation, scaleW, scaleH,
                    cardSprite:getWidth() / 2, cardSprite:getHeight() / 2)
            end
        end
    else
        -- Normal static display with rotation
        local positions = {
            {800, 500}, {650, 450}, {800, 400}, {950, 450}
        }

        for _, played in ipairs(self.playedCards) do
            local pos = positions[played.player]
            local cardSprite = Assets.getCardSprite(played.card.suit, played.card.rank)

            -- Rotation based on player
            local rotation = 0
            if played.player == 2 then rotation = math.pi / 2 end  -- Left: 90 degrees
            if played.player == 4 then rotation = -math.pi / 2 end -- Right: -90 degrees

            -- Draw glow for holy cards
            if isHolyCard(played.card) then
                love.graphics.setColor(1, 0.843, 0, 0.3)
                if rotation == 0 then
                    love.graphics.rectangle("fill", pos[1] - cardW/2 - 4, pos[2] - cardH/2 - 4,
                        cardW + 8, cardH + 8, 8, 8)
                else
                    love.graphics.rectangle("fill", pos[1] - cardH/2 - 4, pos[2] - cardW/2 - 4,
                        cardH + 8, cardW + 8, 8, 8)
                end
            end

            if cardSprite then
                love.graphics.setColor(1, 1, 1, 1)
                local scaleW = cardW / cardSprite:getWidth()
                local scaleH = cardH / cardSprite:getHeight()
                love.graphics.draw(cardSprite, pos[1], pos[2], rotation, scaleW, scaleH,
                    cardSprite:getWidth() / 2, cardSprite:getHeight() / 2)
            end
        end
    end
end

function Game:drawHUD()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(22)

    -- Simplified score display
    love.graphics.print("You: " .. self.gameScore[1] .. " score | " .. self.tricksWon[1] .. " tricks", 10, 10)
    love.graphics.print("Opponents: " .. self.gameScore[2] .. " score | " .. self.tricksWon[2] .. " tricks", 10, 40)

    -- Trump info
    if self.trumpRank and self.trumpSuit then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setNewFont(24)
        love.graphics.print("Trump: " .. RANK_NAMES[self.trumpRank] .. " of " .. SUIT_NAMES[self.trumpSuit], 400, 15)
    elseif self.trumpRank then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setNewFont(24)
        love.graphics.print("Trump Rank: " .. RANK_NAMES[self.trumpRank], 400, 15)
    end

    -- Current turn
    if self.phase == "playing" and not self.gameOver then
        love.graphics.setColor(0.5, 1, 0.5, 1)
        love.graphics.setNewFont(18)
        love.graphics.print("Current Turn: " .. self:getPlayerName(self.currentPlayer), 10, 75)
    end
end

function Game:drawRankSelection()
    -- No black overlay - just draw text at top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(36)
    love.graphics.printf("Click a card to select its RANK as trump", 0, 50, DESIGN_WIDTH, "center")

    love.graphics.setNewFont(24)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.printf("(" .. self:getPlayerName(self.rankSelector) .. "'s turn to choose)", 0, 95, DESIGN_WIDTH, "center")
end

function Game:drawSuitSelection()
    -- No black overlay - just draw text at top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(36)
    love.graphics.printf("Click a card to select its SUIT as trump", 0, 50, DESIGN_WIDTH, "center")

    love.graphics.setNewFont(24)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.printf("(" .. self:getPlayerName(self.suitSelector) .. "'s turn to choose)", 0, 95, DESIGN_WIDTH, "center")
end

function Game:drawCutting()
    -- Draw instruction text at top
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(36)
    love.graphics.printf("Cut the Deck (Schleck)", 0, 50, DESIGN_WIDTH, "center")

    love.graphics.setNewFont(24)
    love.graphics.setColor(1, 1, 0, 1)
    local cutterName = self:getPlayerName(self.cutter)
    love.graphics.printf("(" .. cutterName .. " cuts to look for a Critical)", 0, 95, DESIGN_WIDTH, "center")

    -- Draw the deck in center of screen
    local deckX = 800 - 55 -- Center the 110px wide card
    local deckY = 400 - 75 -- Center vertically
    local deckW, deckH = 110, 150

    if not self.cutCard then
        -- Show face-down deck (clickable)
        local cardBack = Assets.getSprite("spr_card_back")
        if cardBack then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cardBack, deckX, deckY, 0,
                deckW / cardBack:getWidth(), deckH / cardBack:getHeight())
        else
            love.graphics.setColor(0.3, 0.3, 0.8, 1)
            love.graphics.rectangle("fill", deckX, deckY, deckW, deckH, 10, 10)
        end

        -- Add hover effect for player 1
        if self.cutter == 1 then
            if self.mouseX >= deckX and self.mouseX <= deckX + deckW and
               self.mouseY >= deckY and self.mouseY <= deckY + deckH then
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", deckX - 4, deckY - 4, deckW + 8, deckH + 8, 12, 12)
            end

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setNewFont(20)
            love.graphics.printf("Click to cut", 0, deckY + deckH + 20, DESIGN_WIDTH, "center")
        end
    else
        -- Show the revealed cut card
        local cardSprite = Assets.getCardSprite(self.cutCard.suit, self.cutCard.rank)

        -- Draw glow if it's a critical
        if isHolyCard(self.cutCard) then
            love.graphics.setColor(1, 0.843, 0, 0.5)
            love.graphics.rectangle("fill", deckX - 8, deckY - 8, deckW + 16, deckH + 16, 12, 12)
        end

        if cardSprite then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cardSprite, deckX, deckY, 0,
                deckW / cardSprite:getWidth(), deckH / cardSprite:getHeight())
        else
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", deckX, deckY, deckW, deckH, 10, 10)
        end

        -- Show result message
        love.graphics.setNewFont(28)
        if isHolyCard(self.cutCard) then
            love.graphics.setColor(1, 0.843, 0, 1) -- Gold for critical
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.printf(self.cutResult, 0, deckY + deckH + 30, DESIGN_WIDTH, "center")
    end
end

function Game:drawHandComplete()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, DESIGN_WIDTH, DESIGN_HEIGHT)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(42)
    local msg = self.handWinner == 1 and "You Win the Hand! (+2 points)" or "Opponents Win the Hand! (+2 points)"
    love.graphics.printf(msg, 0, 400, DESIGN_WIDTH, "center")
end

function Game:drawGameOver()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, DESIGN_WIDTH, DESIGN_HEIGHT)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(54)
    local message = self.overallWinner == 1 and "You Win the Game!" or "You Lose the Game!"
    love.graphics.printf(message, 0, 350, DESIGN_WIDTH, "center")

    love.graphics.setNewFont(28)
    love.graphics.printf("Final Score: " .. self.gameScore[1] .. " - " .. self.gameScore[2], 0, 425, DESIGN_WIDTH, "center")
    love.graphics.printf("Press ESC for menu or SPACE to play again", 0, 470, DESIGN_WIDTH, "center")
end

function Game:drawPauseMenu()
    -- Semi-transparent dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, DESIGN_WIDTH, DESIGN_HEIGHT)

    -- Pause title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setNewFont(54)
    love.graphics.printf("PAUSED", 0, 250, DESIGN_WIDTH, "center")

    -- Draw buttons
    love.graphics.setNewFont(24)
    for _, button in ipairs(self.pauseButtons) do
        button:draw()
    end
end

function Game:getPlayerName(player)
    if player == 1 then return "You"
    elseif player == 2 then return "Left"
    elseif player == 3 then return "Top"
    else return "Right" end
end

function Game:isCardHovered(x, y, w, h, rotation)
    rotation = rotation or 0
    -- For simplicity, only handle non-rotated cards (player 1)
    if rotation == 0 then
        return self.mouseX >= x and self.mouseX <= x + w and
               self.mouseY >= y and self.mouseY <= y + h
    end
    return false
end

-- Input Handlers
function Game:mousemoved(x, y)
    -- Convert screen coordinates to design coordinates
    local scale, winW, winH = self:getScale()
    local offsetX, offsetY = self:getOffset()
    self.mouseX = (x - offsetX) / scale
    self.mouseY = (y - offsetY) / scale

    -- Handle pause menu button hover
    if self.paused then
        for _, button in ipairs(self.pauseButtons) do
            button:mousemoved(self.mouseX, self.mouseY)
        end
    end
end

function Game:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Convert screen coordinates to design coordinates
    local scale, winW, winH = self:getScale()
    local offsetX, offsetY = self:getOffset()
    local mx = (x - offsetX) / scale
    local my = (y - offsetY) / scale

    -- Handle pause menu clicks
    if self.paused then
        for _, btn in ipairs(self.pauseButtons) do
            btn:mousepressed(mx, my, button)
        end
        return
    end

    -- Cutting phase - click the deck to cut
    if self.phase == "cutting" and self.cutter == 1 and not self.cutCard then
        -- Define deck position (center of screen)
        local deckX = 800 - 55 -- Center the 110px wide card
        local deckY = 400 - 75 -- Center vertically
        local deckW, deckH = 110, 150

        if mx >= deckX and mx <= deckX + deckW and my >= deckY and my <= deckY + deckH then
            self:performCut()
            return
        end
    end

    local hand = self.hands[1]
    local playerX = 800
    local playerY = 750
    local cardW, cardH = 110, 145

    -- Trump rank selection - click a card to choose its rank
    if self.phase == "selecting_rank" and self.rankSelector == 1 then
        for i, card in ipairs(hand) do
            local cardX = playerX - (#hand * 65) + (i - 1) * 130
            local cardY = playerY

            if mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH then
                self:selectRank(card.rank)
                return
            end
        end
    end

    -- Trump suit selection - click a card to choose its suit
    if self.phase == "selecting_suit" and self.suitSelector == 1 then
        for i, card in ipairs(hand) do
            local cardX = playerX - (#hand * 65) + (i - 1) * 130
            local cardY = playerY

            if mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH then
                self:selectSuit(card.suit)
                return
            end
        end
    end

    -- Card playing
    if self.phase == "playing" and self.currentPlayer == 1 and not self.gameOver then
        for i, card in ipairs(hand) do
            local cardX = playerX - (#hand * 65) + (i - 1) * 130
            local cardY = playerY

            if mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH then
                -- Validate card play
                if not self:isCardPlayValid(card, 1) then
                    -- Invalid play - don't allow it, play error sound
                    Assets.playSound("snd_button_hover", 0.3) -- Use hover sound as "error"
                    return
                end

                -- Valid play - remove and play the card
                table.remove(hand, i)
                self:playCard(card, 1)
                return
            end
        end
    end
end

function Game:mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Convert screen coordinates to design coordinates
    local scale, winW, winH = self:getScale()
    local offsetX, offsetY = self:getOffset()
    local mx = (x - offsetX) / scale
    local my = (y - offsetY) / scale

    -- Handle pause menu button releases
    if self.paused then
        for _, btn in ipairs(self.pauseButtons) do
            btn:mousereleased(mx, my, button)
        end
        return
    end
end

function Game:keypressed(key)
    if key == "escape" then
        if not self.gameOver then
            self.paused = not self.paused
        end
    elseif key == "space" and self.gameOver then
        self:enter()
    end
end

return Game
