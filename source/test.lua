import "board"
import "ai"

function TestPlaysCentreOnEmptyBoard()
    local board = Board()

    local aiMove = ChooseAiMove(board, "x")

    luaunit.assertEquals(aiMove, { x = 2, y = 2 })
end
