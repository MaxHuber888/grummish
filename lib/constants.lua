-- lib/constants.lua
-- Central configuration file for all game constants

local Constants = {}

-- ============================================================================
-- DESIGN RESOLUTION
-- ============================================================================
Constants.DESIGN_WIDTH = 1600
Constants.DESIGN_HEIGHT = 900

-- Get current scale factors
function Constants.getScale()
    local winW, winH = love.graphics.getDimensions()
    local scaleX = winW / Constants.DESIGN_WIDTH
    local scaleY = winH / Constants.DESIGN_HEIGHT
    return math.min(scaleX, scaleY), winW, winH
end

-- Get offset to center content
function Constants.getOffset()
    local scale, winW, winH = Constants.getScale()
    local scaledWidth = Constants.DESIGN_WIDTH * scale
    local scaledHeight = Constants.DESIGN_HEIGHT * scale
    return (winW - scaledWidth) / 2, (winH - scaledHeight) / 2
end

-- Convert screen coordinates to design coordinates
function Constants.screenToDesign(screenX, screenY)
    local scale, winW, winH = Constants.getScale()
    local offsetX, offsetY = Constants.getOffset()
    return (screenX - offsetX) / scale, (screenY - offsetY) / scale
end

-- ============================================================================
-- CARD DIMENSIONS
-- ============================================================================
-- Player hand cards (bottom player)
Constants.CARD_WIDTH_PLAYER = 110
Constants.CARD_HEIGHT_PLAYER = 145

-- Opponent face-down cards (other players)
Constants.CARD_WIDTH_OPPONENT = 65
Constants.CARD_HEIGHT_OPPONENT = 85

-- Center played cards (larger for visibility)
Constants.CARD_WIDTH_CENTER = 110
Constants.CARD_HEIGHT_CENTER = 150

-- ============================================================================
-- PLAYER POSITIONS
-- ============================================================================
-- Display positions for each player
Constants.PLAYER_POSITIONS = {
    {800, 750},   -- Player 1 (bottom, human)
    {140, 450},   -- Player 2 (left)
    {800, 60},    -- Player 3 (top)
    {1460, 450}   -- Player 4 (right)
}

-- Rotations for each player (in radians)
Constants.PLAYER_ROTATIONS = {
    0,              -- Player 1 (bottom)
    math.pi/2,      -- Player 2 (left, 90°)
    0,              -- Player 3 (top)
    -math.pi/2      -- Player 4 (right, -90°)
}

-- Names for each player
Constants.PLAYER_NAMES = {
    "You",
    "Left",
    "Top",
    "Right"
}

-- ============================================================================
-- CARD ANIMATION POSITIONS
-- ============================================================================
-- Target positions for trick-winning card animations (toward each player)
Constants.ANIMATION_TARGET_POSITIONS = {
    {800, 660},   -- Bottom (toward player 1)
    {240, 450},   -- Left (toward player 2)
    {800, 180},   -- Top (toward player 3)
    {1360, 450}   -- Right (toward player 4)
}

-- ============================================================================
-- CENTER CARD POSITIONS
-- ============================================================================
-- Positions for played cards in the center of the table
-- Evenly spaced around center (800, 450) with 40px gaps between card edges
-- Card dimensions: 110w x 150h (rotated cards: 150w x 110h)
Constants.PLAYED_CARD_POSITIONS = {
    {800, 545},   -- Bottom (center + half-height + gap)
    {705, 450},   -- Left (center - half-rotated-width - gap)
    {800, 355},   -- Top (center - half-height - gap)
    {895, 450}    -- Right (center + half-rotated-width + gap)
}

-- ============================================================================
-- DECK POSITION
-- ============================================================================
Constants.DECK_X = 800 - 55  -- Center the 110px wide card
Constants.DECK_Y = 400 - 75

-- ============================================================================
-- TIMING VALUES
-- ============================================================================
Constants.AI_DELAY = 1.5                    -- Seconds between AI actions
Constants.CUT_RESULT_DISPLAY_TIME = 2.5     -- Seconds to display cut result
Constants.BLIND_REVEAL_TIME = 1.5           -- Seconds for blind trump reveal
Constants.TRICK_COMPLETE_DISPLAY_TIME = 2.5 -- Seconds to display trick winner
Constants.HAND_COMPLETE_DISPLAY_TIME = 3.0  -- Seconds to display hand winner
Constants.TRICK_ANIMATION_DELAY = 1.0       -- Seconds before starting trick animation
Constants.ANIMATION_SPEED = 1.5             -- Speed multiplier for card drift animation
Constants.CARD_WOBBLE_SPEED = 1.5           -- Speed of hover wobble effect

-- ============================================================================
-- SCORING VALUES
-- ============================================================================
-- Critical cards - highest priority
Constants.SCORE_CRITICAL_1 = 10000  -- King of Hearts
Constants.SCORE_CRITICAL_2 = 9000   -- 7 of Clubs
Constants.SCORE_CRITICAL_3 = 8000   -- 7 of Spades

-- Rechte (trump rank + trump suit) - second highest priority
Constants.SCORE_RECHTE = 5000

-- Trump rank (not trump suit) - third priority
Constants.SCORE_TRUMP_RANK = 3000

-- Trump suit (not trump rank) - fourth priority
Constants.SCORE_TRUMP_SUIT = 1000

-- Lead suit (cards matching first played suit when not trump) - fifth priority
Constants.SCORE_LEAD_SUIT = 500

-- ============================================================================
-- COLORS
-- ============================================================================
-- Golden glow for critical cards
Constants.COLOR_GOLD = {1, 0.843, 0}
Constants.GOLD_ALPHA_NORMAL = 0.3
Constants.GOLD_ALPHA_BRIGHT = 0.5
Constants.GOLD_ALPHA_FULL = 1.0

-- ============================================================================
-- CARD LAYOUT
-- ============================================================================
-- Card spacing in hand (horizontal offset between cards)
Constants.CARD_SPACING = 65
Constants.CARD_OVERLAP = 130  -- Distance between card centers (2 * CARD_SPACING)

-- ============================================================================
-- UI POSITIONS
-- ============================================================================
-- Pause menu
Constants.PAUSE_MENU_CENTER_X = 800
Constants.PAUSE_MENU_START_Y = 350
Constants.PAUSE_MENU_BUTTON_WIDTH = 300
Constants.PAUSE_MENU_BUTTON_HEIGHT = 60
Constants.PAUSE_MENU_BUTTON_SPACING = 80

-- Dealer indicator offset
Constants.DEALER_INDICATOR_OFFSET_X = -65
Constants.DEALER_INDICATOR_OFFSET_Y = -30

-- ============================================================================
-- TRICK HISTORY DISPLAY
-- ============================================================================
-- Positions where completed tricks are displayed next to each player
Constants.TRICK_HISTORY_POSITIONS = {
    {1050, 750},  -- Player 1 (bottom) - to the right
    {300, 450},   -- Player 2 (left) - to the right
    {550, 60},    -- Player 3 (top) - to the left
    {1250, 450}   -- Player 4 (right) - to the left
}

-- Trick history card dimensions (smaller than regular cards)
Constants.TRICK_CARD_WIDTH = 55
Constants.TRICK_CARD_HEIGHT = 75

-- Spacing for trick history cards in star formation
Constants.TRICK_CARD_GAP = 10  -- Gap between card edges in trick display

-- ============================================================================
-- RANK AND SUIT NAMES
-- ============================================================================
Constants.RANK_NAMES = {
    [1] = "Ace", [2] = "2", [3] = "3", [4] = "4", [5] = "5",
    [6] = "6", [7] = "7", [8] = "8", [9] = "9", [10] = "10",
    [11] = "Jack", [12] = "Queen", [13] = "King"
}

Constants.SUIT_NAMES = {
    clubs = "Clubs",
    diamonds = "Diamonds",
    hearts = "Hearts",
    spades = "Spades"
}

-- ============================================================================
-- CRITICAL CARDS DEFINITION
-- ============================================================================
-- Defines critical cards with highest priority
Constants.CRITICAL_CARDS = {
    {rank = 13, suit = "hearts", level = 1},  -- King of Hearts
    {rank = 7, suit = "clubs", level = 2},    -- 7 of Clubs
    {rank = 7, suit = "spades", level = 3}    -- 7 of Spades
}

-- ============================================================================
-- PARTICLE SYSTEM
-- ============================================================================
Constants.PARTICLE_SPAWN_RATE = 0.05  -- Seconds between particle spawns
Constants.PARTICLE_GRAVITY = 50       -- Downward acceleration
Constants.PARTICLE_LIFETIME = 1.0     -- Seconds before particle fades out

return Constants
