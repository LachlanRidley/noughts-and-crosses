import "board"

---Based on the current state of the board, chooses a move for the AI
---@param board Board the current state of the board
---@param symbol 'x' | 'o' the symbol to choose a move for
---@return boardCoordinate
function ChooseAiMove(board, symbol)
    -- SOURCE: https://en.wikipedia.org/wiki/Tic-tac-toe#Strategy

    local playerSymbol = symbol == 'x' and 'o' or 'x'
    local aiSymbol = symbol == 'x' and 'x' or 'o'

    local availableMoves = board:getFreeSpaces()

    for _, move in pairs(availableMoves) do
        local straights = board.getStraightsForPosition(move.x, move.y)

        for _, straight in ipairs(straights) do
            if board:countForStraight(straight, aiSymbol) == 2 then
                -- this move is on a straight which already has two "o"
                -- so playing here is a win
                print("I can win so I will")
                return move
            end
        end
    end

    for _, move in pairs(availableMoves) do
        local straights = board.getStraightsForPosition(move.x, move.y)

        for _, straight in ipairs(straights) do
            if board:countForStraight(straight, playerSymbol) == 2 then
                -- I have to block the opponent here or I will lose
                print("I have to block")
                return move
            end
        end
    end

    for _, move in ipairs(availableMoves) do
        -- forking means playing any move which will convert 2 unblocked
        -- straights into a winnable straight that's actually not complicated.
        -- Any move with 2 or more unblocked straights is a fork
        -- get all my unblocked straights (straights with 1 "o" and 0 "x")
        -- if there are 2 or more then play here to create a fork
        local straights = board.getStraightsForPosition(move.x, move.y)

        local unblockedStraights = {}
        for _, straight in ipairs(straights) do
            if board:countForStraight(straight, aiSymbol) == 1
                and board:countForStraight(straight, playerSymbol) == 0 then
                table.insert(unblockedStraights, straight)
            end
        end

        if #unblockedStraights >= 2 then
            print("I can make a fork which means I'll win next turn")
            return move
        end
    end

    -- TODO block opponents fork
    -- so this is the most complicated one.
    -- the logic is also slightly different here. Normally we can just look
    -- for a good move until we find one and take it but here we have to
    -- anticipate the player's move and determine which is the most valuable
    -- one to block.
    -- we have to identify any moves that on the player's turn will create a
    -- fork
    -- if there's only one fork, then we block it, easy
    -- if there's a move that can block all forks, then we should take it as
    -- long as it will produce a winnable straight (which the player will then
    -- be forced to block)
    -- if no such move exists, then we have to stall. Pick any move which will
    -- produce a winning straight but not force the player to make a fork when
    -- they defend against it

    for _, move in pairs(availableMoves) do
        if move.x == 2 and move.y == 2 then
            print("hmm, I guess I'll take the centre")
            return move
        end
    end

    -- TODO opposite corner

    for _, move in pairs(availableMoves) do
        if ((move.x == 1 or move.x == 3) and move.y ~= 2)
            or ((move.y == 1 or move.y == 3) and move.x ~= 2) then
            print("I'll take an empty corner plz")
            return move
        end
    end

    for _, move in pairs(availableMoves) do
        if move.x == 2 or move.y == 2 then
            print("empty sides are the way to go")
            return move
        end
    end

    print(
        "damn, I don't know what to do. I'll choose a move at random")
    local chosenMove = availableMoves[math.random(1, #availableMoves)]

    return chosenMove
end
