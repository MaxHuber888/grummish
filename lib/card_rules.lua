-- lib/card_rules.lua
-- Pure functions for card evaluation, scoring, and validation in Watten

local Constants = require("lib.constants")

local CardRules = {}

-- ============================================================================
-- CRITICAL CARDS
-- ============================================================================

--- Check if a card is a critical card
-- @param card Card object with rank and suit
-- @param useCriticals Boolean indicating if critical cards are enabled
-- @return false if not critical, or the critical level (1, 2, or 3) if it is critical
function CardRules.isCriticalCard(card, useCriticals)
    -- Check if criticals are enabled
    if not useCriticals then
        return false
    end

    -- Check against critical cards definition
    for _, criticalCard in ipairs(Constants.CRITICAL_CARDS) do
        if card.rank == criticalCard.rank and card.suit == criticalCard.suit then
            return criticalCard.level
        end
    end
    return false
end

-- ============================================================================
-- CARD SCORING
-- ============================================================================

--- Get the numeric score for a card based on trump rank, suit, and lead suit
-- Higher score means stronger card. Used for determining trick winner.
-- Scoring hierarchy:
--   1. Critical cards (always trump, 10000/9000/8000)
--   2. Rechte - trump rank + trump suit (5000)
--   3. Trump rank cards (3000+)
--   4. Trump suit cards (1000+)
--   5. Cards matching lead suit (500+, only if lead suit is not trump)
--   6. Other cards (0 - cannot beat anything)
-- @param card Card object with rank, suit, and value
-- @param trumpRank The selected trump rank (1-13)
-- @param trumpSuit The selected trump suit ("clubs", "diamonds", "hearts", "spades")
-- @param useCriticals Boolean indicating if critical cards are enabled
-- @param leadSuit Optional suit of the first card played in the trick
-- @return Numeric score for the card
function CardRules.getCardScore(card, trumpRank, trumpSuit, useCriticals, leadSuit)
    -- Check for critical cards first (highest priority)
    local critical = CardRules.isCriticalCard(card, useCriticals)
    if critical then
        if critical == 1 then
            return Constants.SCORE_CRITICAL_1
        elseif critical == 2 then
            return Constants.SCORE_CRITICAL_2
        else
            return Constants.SCORE_CRITICAL_3
        end
    end

    -- Check trump combinations
    local isTrumpRank = (card.rank == trumpRank)
    local isTrumpSuit = (card.suit == trumpSuit)

    if isTrumpRank and isTrumpSuit then
        -- Rechte (trump rank + trump suit) - second highest priority
        return Constants.SCORE_RECHTE
    elseif isTrumpRank then
        -- Trump rank only - third priority
        return Constants.SCORE_TRUMP_RANK + card.value
    elseif isTrumpSuit then
        -- Trump suit only - fourth priority
        return Constants.SCORE_TRUMP_SUIT + card.value
    elseif leadSuit and leadSuit ~= trumpSuit and card.suit == leadSuit then
        -- Card matches the lead suit (which is not trump) - fifth priority
        return Constants.SCORE_LEAD_SUIT + card.value
    elseif leadSuit and card.suit ~= leadSuit then
        -- Card does not match lead suit and is not trump - cannot beat anything
        return 0
    else
        -- No lead suit specified or first card of trick - use base value
        return card.value
    end
end

-- ============================================================================
-- CARD PLAY VALIDATION
-- ============================================================================

--- Check if a card can be legally played according to Watten rules
-- Rules:
--   - First card of trick: always valid
--   - Holy cards: always valid
--   - If first card is holy: any card valid (holy cards have no suit)
--   - If first card is NOT trump suit: any card valid
--   - If first card IS trump suit:
--       * In Blind mode: only cutter/dealer must follow suit
--       * Rechte (highest card): always valid
--       * If player has no trump suit: any card valid
--       * If player has trump suit: must play trump suit OR beat first card
-- @param card Card to validate
-- @param player Player number (1-4)
-- @param hands Table of all player hands {[1]={cards}, [2]={cards}, ...}
-- @param playedCards Array of {card, player} objects already played this trick
-- @param trumpRank The selected trump rank
-- @param trumpSuit The selected trump suit
-- @param useCriticals Boolean indicating if critical cards are enabled
-- @param useBlind Boolean indicating if Blind Watten mode is enabled
-- @param cutter Player number who cut/selected rank (for Blind mode)
-- @param dealer Player number who is dealer (for Blind mode)
-- @return true if card can be played, false otherwise
function CardRules.isCardPlayValid(card, player, hands, playedCards, trumpRank, trumpSuit, useCriticals, useBlind, cutter, dealer)
    -- Always valid if no cards played yet or it's the first card
    if #playedCards == 0 then
        return true
    end

    local firstCard = playedCards[1].card

    -- Critical cards can always be played
    if CardRules.isCriticalCard(card, useCriticals) then
        return true
    end

    -- If first card is critical, it doesn't belong to any suit - any card can be played
    if CardRules.isCriticalCard(firstCard, useCriticals) then
        return true
    end

    -- If first card is NOT trump suit, any card can be played
    if firstCard.suit ~= trumpSuit then
        return true
    end

    -- First card IS trump suit
    -- In Blind Watten, only cutter and dealer must follow trump suit
    -- (teammates don't officially know the trump)
    if useBlind then
        local isKnower = (player == cutter or player == dealer)
        if not isKnower then
            return true -- Teammates can play any card
        end
    end

    -- Must follow suit or beat it (normal mode, or cutter/dealer in blind mode)
    local hand = hands[player]

    -- Check if player has any trump suit cards (excluding critical cards)
    local hasTrumpSuit = false
    for _, c in ipairs(hand) do
        if c.suit == trumpSuit and not CardRules.isCriticalCard(c, useCriticals) and c.rank ~= trumpRank then
            hasTrumpSuit = true
            break
        end
    end

    -- If player has no trump suit, any card is valid
    if not hasTrumpSuit then
        return true
    end

    -- Player has trump suit - must play trump suit or beat the first card
    if card.suit == trumpSuit then
        return true -- Following suit
    end

    -- Check if card can beat the first card
    -- Determine lead suit (suit of first card, unless it's a critical)
    local leadSuit = nil
    if not CardRules.isCriticalCard(firstCard, useCriticals) then
        leadSuit = firstCard.suit
    end

    local cardScore = CardRules.getCardScore(card, trumpRank, trumpSuit, useCriticals, leadSuit)
    local firstCardScore = CardRules.getCardScore(firstCard, trumpRank, trumpSuit, useCriticals, leadSuit)
    if cardScore > firstCardScore then
        return true -- Can beat it
    end

    -- Cannot play this card
    return false
end

return CardRules
