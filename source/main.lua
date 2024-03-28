import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

-- globals
local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240

local NOUGHT_RADIUS <const> = 20


local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound
local timer <const> = pd.timer

---@enum GameState
local GameState = {
	SplashScreen = 1,
	Playing = 2
}

---@type _Image
local canvas

---@type thread
local pencilAction
local pencilScratch = snd.sampleplayer.new("scratch")

---@type _Image?
local pencilImage = gfx.image.new("pencil")

---@type _Font
local font = gfx.font.new("Cameltry")

---@type integer | nil
local previousEraserY = nil

---@class Pencil: _Sprite
---@field x integer
---@field y integer
---@field drawing boolean
---@field thickness integer
---@field private animator _Animator
---@overload fun(x: integer, y: integer): Pencil
Pencil = class('Pencil').extends(playdate.graphics.sprite) or Pencil

function Pencil:init(x, y)
	Pencil.super.init(self)
	if pencilImage == nil then
		print("Failed to load pencil image")
		return
	end
	self:setImage(pencilImage)
	self:moveTo(x, y)
	self:setCenter(0, 1)
	self.drawing = false
	self.thickness = 2
end

---@type Pencil
local pencil

function Pencil:update()
	if self.animator:ended() then
		if coroutine.status(pencilAction) == "dead" then return end -- TODO if there's no actions queued then the pencil should just drift towards the cursor
		coroutine.resume(pencilAction)
	end

	local previousX = self.x
	local previousY = self.y

	local nextPoint = self.animator:currentValue();
	self:moveTo(nextPoint.x, nextPoint.y)

	if self.drawing then
		gfx.lockFocus(canvas)
		gfx.setLineWidth(math.random(self.thickness, self.thickness + 1))
		gfx.setLineCapStyle(gfx.kLineCapStyleRound)
		gfx.drawLine(previousX, previousY, self.x, self.y)
		gfx.unlockFocus()
	end
end

function Pencil:DrawLine(x1, y1, x2, y2)
	local initialPoint = pd.geometry.point.new(x1, y1)
	local goalPoint = pd.geometry.point.new(x2, y2)

	self.animator = gfx.animator.new(1000, initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
	self.drawing = true
	self:moveTo(x1, y1)

	pencilScratch:play()
end

function Pencil:IsDone()
	return pencil.animator:ended()
end

---Raise the pencil and move it to a position
---@param x integer
---@param y integer
function Pencil:MovePencil(x, y)
	self.drawing = false
	local initialPoint = pd.geometry.point.new(self.x, self.y)
	local goalPoint = pd.geometry.point.new(x, y)

	self.animator = gfx.animator.new(500, initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
end

---Queues a circle draw
---@param centre _Point
---@param radius integer
function Pencil:DrawCircle(centre, radius)
	self.drawing = true
	self:moveTo(centre.x, centre.y - radius)

	local path = pd.geometry.arc.new(centre.x, centre.y, radius, 0, 360)

	self.animator = gfx.animator.new(1000, path, pd.easingFunctions.inOutQuint)
	pencilScratch:play()
end

---@class Cursor: _Sprite
---@field boardX boardDimension
---@field boardY boardDimension
---@overload fun(x: boardDimension, y: boardDimension): Cursor
Cursor = class('Cursor').extends(gfx.sprite) or Cursor

function Cursor:init(x, y)
	Cursor.super.init(self)

	self.boardX = x
	self.boardY = y

	local r = 5
	self:setSize(r * 2, r * 2)
	function self:draw()
		gfx.drawCircleAtPoint(r, r, r)
	end
end

---@alias direction "up" | "down" | "left" | "right"

---@param direction direction
function Cursor:MoveInDirection(direction)
	local newX = self.boardX
	local newY = self.boardY

	if direction == "up" then
		newY -= 1
	elseif direction == "down" then
		newY += 1
	elseif direction == "left" then
		newX -= 1
	elseif direction == "right" then
		newX += 1
	end
	if IsOutOfBound(newX, newY) then return end

	self.boardX = newX
	self.boardY = newY

	local cursorPosition = ConvertBoardCoordinateToScreenSpace({ x = self.boardX, y = self.boardY })
	self:moveTo(cursorPosition.x, cursorPosition.y)
end

---set the cursors position in board space
---@param x boardDimension
---@param y boardDimension
function Cursor:MoveToBoardCoordinate(x, y)
	self.boardX = x
	self.boardY = y

	local cursorPosition = ConvertBoardCoordinateToScreenSpace({ x = self.boardX, y = self.boardY })
	self:moveTo(cursorPosition.x, cursorPosition.y)
end

local playingAi = true

---@alias symbol "-" | "o" | "x"
---@type symbol
local aiSymbol = "x"
---@type symbol
local playerSymbol = "o"
---@type symbol
local currentTurn = "x"

local someonesTurn = false

---@type Cursor
local cursor

---Takes a cursor and converts it's board coordinate into screen space so that it can be drawn
---@param coordinate boardCoordinate
---@return _Point
function ConvertBoardCoordinateToScreenSpace(coordinate)
	local screenX = 125 + (coordinate.x - 1) * 70
	local screenY = 45 + (coordinate.y - 1) * 60

	return pd.geometry.point.new(screenX, screenY)
end

---@type symbol[][]
local board

---@type GameState
local state = GameState.SplashScreen;

-- straights are the 8 possible winning rows.
---@enum straight
local Straight = {
	TopRow = 1,
	MiddleRow = 2,
	BottomRow = 3,

	LeftColumn = 4,
	MiddleColumn = 5,
	RightColumn = 6,

	TopLeftToBottomRight = 7,
	BottomLeftToTopRight = 8
}

---@alias boardDimension 1 | 2 | 3

---@class boardCoordinate
---@field x boardDimension
---@field y boardDimension

---Returns all the straights that include a given position on the board.
---@param x boardDimension
---@param y boardDimension
---@return straight[]
function GetStraightsForPosition(x, y)
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

---@param straight straight
---@param symbol symbol
function CountForStraight(straight, symbol)
	if straight == Straight.TopRow then
		return CountInRow(1, symbol)
	elseif straight == Straight.MiddleRow then
		return CountInRow(2, symbol)
	elseif straight == Straight.BottomRow then
		return CountInRow(3, symbol)
	elseif straight == Straight.LeftColumn then
		return CountInCol(1, symbol)
	elseif straight == Straight.MiddleColumn then
		return CountInCol(2, symbol)
	elseif straight == Straight.RightColumn then
		return CountInCol(3, symbol)
	elseif straight == Straight.TopLeftToBottomRight then
		return CountInTopLeftToBottomRight(symbol)
	elseif straight == Straight.BottomLeftToTopRight then
		return CountInBottomLeftToTopRight(symbol)
	end

	error("Invalid straight provided")
end

function CountInRow(row, symbol)
	local count = 0
	for col = 1, 3, 1 do
		if board[col][row] == symbol then
			count += 1
		end
	end
	return count
end

function CountInCol(col, symbol)
	local count = 0
	for row = 1, 3, 1 do
		if board[col][row] == symbol then
			count += 1
		end
	end
	return count
end

function CountInTopLeftToBottomRight(symbol)
	local count = 0
	if board[1][1] == symbol then count += 1 end
	if board[2][2] == symbol then count += 1 end
	if board[3][3] == symbol then count += 1 end

	return count
end

function CountInBottomLeftToTopRight(symbol)
	local count = 0
	if board[1][3] == symbol then count += 1 end
	if board[2][2] == symbol then count += 1 end
	if board[3][1] == symbol then count += 1 end

	return count
end

function FlipTurn()
	if currentTurn == "x" then
		currentTurn = "o"
	else
		currentTurn = "x"
	end
end

function DrawBoard()
	someonesTurn = false

	pencil:DrawLine(160, 21, 156, 187)
	coroutine.yield()

	pencil:MovePencil(231, 19)
	coroutine.yield()

	pencil:DrawLine(231, 19, 225, 190)
	coroutine.yield()

	pencil:MovePencil(96, 74)
	coroutine.yield()

	pencil:DrawLine(96, 74, 291, 76)
	coroutine.yield()

	pencil:MovePencil(95, 135)
	coroutine.yield()

	pencil:DrawLine(95, 135, 293, 138)
	coroutine.yield()

	someonesTurn = true
end

---creates a function that can then be passed to pencil action
---@param x boardDimension
---@param y boardDimension
---@return function
function DrawNought(x, y)
	return function()
		pencil.thickness = 5
		someonesTurn = false

		local centre = ConvertBoardCoordinateToScreenSpace({ x = x, y = y })

		pencil:DrawCircle(centre, NOUGHT_RADIUS)
		coroutine.yield()

		someonesTurn = true
		pencil.drawing = false
	end
end

---creates a function that can then be passed to the pencil action
---@param x boardDimension
---@param y boardDimension
---@return function
function DrawCross(x, y)
	return function()
		pencil.thickness = 5
		someonesTurn = false

		local centre = ConvertBoardCoordinateToScreenSpace({ x = x, y = y })

		pencil:DrawLine(centre.x - 17, centre.y - 24, centre.x + 15, centre.y + 21)
		coroutine.yield()

		pencil:DrawLine(centre.x - 22, centre.y + 22, centre.x + 18, centre.y - 18)
		coroutine.yield()

		someonesTurn = true
		pencil.drawing = false
	end
end

---@param straight straight
function DrawWinningLine(straight)
	someonesTurn = false
	pencil.thickness = 8

	if straight == Straight.TopRow then
		pencil:DrawLine(89, 46, 301, 48)
	elseif straight == Straight.MiddleRow then
		pencil:DrawLine(87, 104, 306, 105)
	elseif straight == Straight.BottomRow then
		pencil:DrawLine(85, 164, 298, 168)
	elseif straight == Straight.LeftColumn then
		pencil:DrawLine(121, 15, 122, 191)
	elseif straight == Straight.MiddleColumn then
		pencil:DrawLine(196, 16, 191, 193)
	elseif straight == Straight.RightColumn then
		pencil:DrawLine(265, 15, 260, 193)
	elseif straight == Straight.TopLeftToBottomRight then
		pencil:DrawLine(103, 22, 285, 192)
	elseif straight == Straight.BottomLeftToTopRight then
		pencil:DrawLine(94, 187, 289, 23)
	end

	coroutine.yield()
end

function EraseCanvas()
	canvas:clear(gfx.kColorWhite)
end

function RestartGame()
	EraseCanvas()
	NewGame()
end

function Setup()
	-- set the game up
	pd.display.setRefreshRate(50)

	-- set up game menu
	local menu = playdate.getSystemMenu()

	menu:addMenuItem("Restart game", function()
		RestartGame()
	end)

	-- setup canvas
	canvas = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT)

	gfx.setFont(font)

	gfx.sprite.setBackgroundDrawingCallback(
		function()
			canvas:draw(0, 0)
		end
	)

	if pd.argv[1] ~= nil then
		NewGame(pd.argv[1])
	end
end

---Starts a new game. Can safely be called at any time
---@param startState string?
function NewGame(startState)
	canvas:clear(gfx.kColorWhite)
	state = GameState.Playing

	-- setup game
	board = {
		{ "-", "-", "-" },
		{ "-", "-", "-" },
		{ "-", "-", "-" }
	}
	currentTurn = "x"

	-- setup pencil
	if pencil ~= nil then
		pencil:remove()
	end
	pencil = Pencil(0, 0)
	pencil:add()

	-- setup cursor
	if cursor ~= nil then
		cursor:remove()
	end
	cursor = Cursor(1, 1)
	cursor:add()

	-- draw a board
	pencilAction = coroutine.create(DrawBoard)
	coroutine.resume(pencilAction)

	-- if startState ~= nil then
	-- 	for i = 1, #startState do
	-- 		local x = math.floor(i / 3)
	-- 		local y = i % 3

	-- 		PlayOnSpace(x, y, startState[i])
	-- 	end
	-- end
end

function CheckForWinner()
	for _, straight in pairs(Straight) do
		if CountForStraight(straight, "x") == 3 or CountForStraight(straight, "o") == 3 then
			DrawWinningLine(straight)
		end
	end
end

function DrawSplashScreen()
	gfx.lockFocus(canvas)
	gfx.drawText("NOUGHTS AND CROSSES", 20, SCREEN_HEIGHT / 2)
	gfx.unlockFocus()
	gfx.sprite.redrawBackground()
	gfx.sprite.update()
end

function pd.update()
	if state == GameState.SplashScreen then
		DrawSplashScreen()

		if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
			NewGame()
		end
		return
	end

	if pencil:IsDone() and someonesTurn then
		CheckForWinner()
	end

	if someonesTurn then
		if playingAi and currentTurn == aiSymbol then
			local aiMove = ChooseAiMove()
			PlayOnSpace(aiMove.x, aiMove.y, aiSymbol)
			FlipTurn()
		end

		if pd.buttonJustPressed(pd.kButtonUp) then
			cursor:MoveInDirection("up")
		end
		if pd.buttonJustPressed(pd.kButtonDown) then
			cursor:MoveInDirection("down")
		end
		if pd.buttonJustPressed(pd.kButtonLeft) then
			cursor:MoveInDirection("left")
		end
		if pd.buttonJustPressed(pd.kButtonRight) then
			cursor:MoveInDirection("right")
		end

		if pd.buttonJustPressed(pd.kButtonA) and SpaceIsFree(cursor.boardX, cursor.boardY) then
			PlayOnSpace(cursor.boardX, cursor.boardY, playerSymbol)
			FlipTurn()
		end

		cursor:setVisible(true)
	else
		cursor:setVisible(false)
	end

	if not pd.isCrankDocked() then
		-- TODO erasing should always starts from the top, no matter the start position of the crank
		-- TODO erasing the whole screen should take multiple turns of the crank
		-- TODO erasing the screen should happen in a back and forth motion (as if you're rubbing it out)

		local crankPosition = pd.getCrankPosition()
		local crankPositionToScreenY = math.floor((crankPosition / 360) * SCREEN_HEIGHT);

		if previousEraserY == nil then
			-- this means we've only just started erasing so set the starting pos to the current crank pos
			previousEraserY = crankPositionToScreenY
		end

		local erasedSectionY = math.min(previousEraserY, crankPositionToScreenY)
		local erasedSectionBottomY = math.max(previousEraserY, crankPositionToScreenY)

		local erasedSectionHeight = math.ceil(math.abs(erasedSectionY - erasedSectionBottomY))

		if erasedSectionHeight > 0 then
			gfx.lockFocus(canvas)
			gfx.setColor(gfx.kColorWhite)
			gfx.fillRect(0, erasedSectionY, SCREEN_WIDTH, erasedSectionHeight)
			gfx.unlockFocus()

			previousEraserY = previousEraserY + erasedSectionHeight
		end
	else
		previousEraserY = nil
	end

	gfx.sprite.redrawBackground()
	gfx.sprite.update()
	timer.updateTimers()
end

--- Plays a symbol in the provided space. Currently assumes that you have already checked that the space is free.
---@param x 1 | 2 | 3
---@param y 1 | 2 | 3
---@param symbol symbol
function PlayOnSpace(x, y, symbol)
	board[x][y] = symbol
	if symbol == "x" then
		pencilAction = coroutine.create(DrawCross(x, y))
	else
		pencilAction = coroutine.create(DrawNought(x, y))
	end
end

function SpaceIsFree(x, y)
	return board[x][y] == "-"
end

---Checks whether a given x and y coordinate lies on the board
---@param x integer
---@param y integer
---@return boolean
function IsOutOfBound(x, y)
	return x < 1 or x > 3 or y < 1 or y > 3
end

---Based on the current state of the board, chooses a move for the AI
---@return boardCoordinate
function ChooseAiMove()
	-- SOURCE: https://en.wikipedia.org/wiki/Tic-tac-toe#Strategy
	---@type boardCoordinate[]
	local availableMoves = {}

	for x = 1, 3, 1 do
		for y = 1, 3, 1 do
			if SpaceIsFree(x, y) then
				table.insert(availableMoves, { x = x, y = y })
			end
		end
	end

	for _, move in pairs(availableMoves) do
		local straights = GetStraightsForPosition(move.x, move.y)

		for _, straight in ipairs(straights) do
			if CountForStraight(straight, aiSymbol) == 2 then
				-- this move is on a straight which already has two "o" so playing here is a win
				print("I can win so I will")
				return move
			end
		end
	end

	for _, move in pairs(availableMoves) do
		local straights = GetStraightsForPosition(move.x, move.y)

		for _, straight in ipairs(straights) do
			if CountForStraight(straight, playerSymbol) == 2 then
				-- I have to block the opponent here or I will lose
				print("I have to block")
				return move
			end
		end
	end

	for _, move in ipairs(availableMoves) do
		-- forking means playing any move which will convert 2 unblocked straights into a winnable straight
		-- that's actually not complicated. Any move with 2 or more unblocked straights is a fork
		-- get all my unblocked straights (straights with 1 "o" and 0 "x")
		-- if there are 2 or more then play here to create a fork
		local straights = GetStraightsForPosition(move.x, move.y)

		local unblockedStraights = {}
		for _, straight in ipairs(straights) do
			if CountForStraight(straight, aiSymbol) == 1 and CountForStraight(straight, playerSymbol) == 0 then
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
	-- the logic is also slightly different here. Normally we can just look for a good move until we find one and take it but here we have to anticipate the player's move and determine which is the most valuable one to block.
	-- we have to identify any moves that on the player's turn will create a fork
	-- if there's only one fork, then we block it, easy
	-- if there's a move that can block all forks, then we should take it as long as it will produce a winnable straight (which the player will then be forced to block)
	-- if no such move exists, then we have to stall. Pick any move which will produce a winning straight but not force the player to make a fork when they defend against it

	for _, move in pairs(availableMoves) do
		if move.x == 2 and move.y == 2 then
			print("hmm, I guess I'll take the centre")
			return move
		end
	end

	-- TODO opposite corner

	for _, move in pairs(availableMoves) do
		if ((move.x == 1 or move.x == 3) and move.y ~= 2) or ((move.y == 1 or move.y == 3) and move.x ~= 2) then
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

	print("damn, I don't know what to do. I'll choose an available move at random")
	local chosenMove = availableMoves[math.random(1, #availableMoves)]

	return chosenMove
end

Setup()
