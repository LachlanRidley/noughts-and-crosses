import "board"
import "ai"

function TestPlaysCentreOnEmptyBoard()
    local board = SetupBoard()

    local aiMove = ChooseAiMove(board, "x")

    luaunit.assertEquals(aiMove, { x = 2, y = 2 })
end

function TestPlaysCornerIfCentreTaken()
    local board = SetupBoard({
        { "-", "-", "-" },
        { "-", "x", "-" },
        { "-", "-", "-" }
    })

    local aiMove = ChooseAiMove(board, "o")

    luaunit.assertEquals(aiMove, { x = 1, y = 1 })
end

function TestTakesTopRowWinIfAvailable()
    local board = SetupBoard({
        { "x", "-", "x" },
        { "-", "-", "-" },
        { "-", "-", "-" }
    })
    local aiMove = ChooseAiMove(board, "x")

    luaunit.assertEquals(aiMove, { x = 2, y = 1 })
end

function TestTakesMiddleRowWinIfAvailable()
    local board = SetupBoard({
        { "-", "-", "-" },
        { "x", "-", "x" },
        { "-", "-", "-" }
    })
    local aiMove = ChooseAiMove(board, "x")

    luaunit.assertEquals(aiMove, { x = 2, y = 2 })
end

function TestTakesBottomRowWinIfAvailable()
    local board = SetupBoard({
        { "-", "-", "-" },
        { "-", "-", "-" },
        { "x", "-", "x" }
    })
    local aiMove = ChooseAiMove(board, "x")

    luaunit.assertEquals(aiMove, { x = 2, y = 3 })
end

---comment
---@param state ("x" | "o" | "-" )[][] | nil
---@return Board
function SetupBoard(state)
    ---@type Board
    local board = Board()

    if state ~= nil then
        for y = 1, 3, 1 do
            for x = 1, 3, 1 do
                if state[y][x] == "x" or state[y][x] == "o" then
                    board:setSpace(x, y, state[y][x])
                end
            end
        end
    end

    return board
end
