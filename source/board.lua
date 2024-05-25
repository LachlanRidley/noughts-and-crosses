-- straights are the 8 possible winning rows.
---@enum straight
Straight = {
    TopRow = 1,
    MiddleRow = 2,
    BottomRow = 3,

    LeftColumn = 4,
    MiddleColumn = 5,
    RightColumn = 6,

    TopLeftToBottomRight = 7,
    BottomLeftToTopRight = 8
}

---@class Board
---@field private state ('x' | 'o' | '-')[][]
Board = class('Board').extends() or Board

function Board:init()
    self.state = {
        { "-", "-", "-" },
        { "-", "-", "-" },
        { "-", "-", "-" }
    }
end

---returns all the straights that intersect a position on the board
---@param x 1 | 2 | 3
---@param y 1 | 2 | 3
---@return straight[]
function Board.getStraightsForPosition(x, y)
    local straights = {}
    if x == 1 then
        table.insert(straights, Straight.LeftColumn)
    elseif x == 2 then
        table.insert(straights, Straight.MiddleColumn)
    elseif x == 3 then
        table.insert(straights, Straight.RightColumn)
    end

    if y == 1 then
        table.insert(straights, Straight.TopRow)
    elseif y == 2 then
        table.insert(straights, Straight.MiddleRow)
    elseif y == 3 then
        table.insert(straights, Straight.BottomRow)
    end

    if x == 2 and y == 2 then
        table.insert(straights, Straight.TopLeftToBottomRight)
        table.insert(straights, Straight.BottomLeftToTopRight)
    elseif (x == 1 and y == 1) or (x == 3 and y == 3) then
        table.insert(straights, Straight.TopLeftToBottomRight)
    elseif (x == 1 and y == 3) or (x == 3 and y == 1) then
        table.insert(straights, Straight.BottomLeftToTopRight)
    end

    return straights
end

function Board:countInRow(row, symbol)
    local count = 0
    for col = 1, 3, 1 do
        if self.state[col][row] == symbol then
            count += 1
        end
    end
    return count
end

function Board:countInCol(col, symbol)
    local count = 0
    for row = 1, 3, 1 do
        if self.state[col][row] == symbol then
            count += 1
        end
    end
    return count
end

function Board:countInTopLeftToBottomRight(symbol)
    local count = 0
    if self.state[1][1] == symbol then count += 1 end
    if self.state[2][2] == symbol then count += 1 end
    if self.state[3][3] == symbol then count += 1 end

    return count
end

function Board:countInBottomLeftToTopRight(symbol)
    local count = 0
    if self.state[1][3] == symbol then count += 1 end
    if self.state[2][2] == symbol then count += 1 end
    if self.state[3][1] == symbol then count += 1 end

    return count
end

---counts how many times a symbol appears in a given straight
---@param straight straight
---@param symbol 'x' | 'o'
---@return integer
function Board:countForStraight(straight, symbol)
    if straight == Straight.TopRow then
        return self:countInRow(1, symbol)
    elseif straight == Straight.MiddleRow then
        return self:countInRow(2, symbol)
    elseif straight == Straight.BottomRow then
        return self:countInRow(3, symbol)
    elseif straight == Straight.LeftColumn then
        return self:countInCol(1, symbol)
    elseif straight == Straight.MiddleColumn then
        return self:countInCol(2, symbol)
    elseif straight == Straight.RightColumn then
        return self:countInCol(3, symbol)
    elseif straight == Straight.TopLeftToBottomRight then
        return self:countInTopLeftToBottomRight(symbol)
    elseif straight == Straight.BottomLeftToTopRight then
        return self:countInBottomLeftToTopRight(symbol)
    end

    error("Invalid straight provided")
end

---checks whether a space on the board is currently free
---@param x 1 | 2 | 3
---@param y 1 | 2 | 3
---@return boolean
function Board:spaceIsFree(x, y)
    return self.state[x][y] == "-"
end

---Checks if the given straight has all three of the same symbol
---@param straight straight the straight to check
---@return symbol | nil # the winning symbol or nil if the straight does not have a winner
function Board:getWinnerInStraight(straight)
    if self:countForStraight(straight, "x") == 3 then
        return "x"
    elseif self:countForStraight(straight, "o") == 3 then
        return "o"
    end

    return nil
end

---sets a psotion on the board to symbol
---@param x 1 | 2 | 3
---@param y 1 | 2 | 3
---@param symbol "x" | "o"
function Board:setSpace(x, y, symbol)
    self.state[x][y] = symbol
end
