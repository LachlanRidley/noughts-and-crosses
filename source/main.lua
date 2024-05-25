import 'luaunit/playdate_luaunit_fix'
import 'luaunit/luaunit'

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

import "pencil"
import "board"
import "ai"
import 'test'

playdate.stop()

-- TODO probably want to make these only run in simulator
luaunit.PRINT_TABLE_REF_IN_ERROR_MSG = true
local luaunit_args = { '--output', 'text', '--verbose', '-r' }

local returnValue = luaunit.LuaUnit.run(table.unpack(luaunit_args))

print("unit test return value = " .. returnValue);

playdate.start()

-- globals
local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240

local NOUGHT_RADIUS <const> = 20

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound
local timer <const> = pd.timer

local splashLetters <const> = {
	-- N
	{
		40, 97,
		48, 25,
		72, 81,
		85, 28
	},
	-- O
	{
		102, 72,
		102, 66,
		106, 60,
		115, 58,
		123, 60,
		128, 63,
		130, 67,
		130, 71,
		129, 77,
		126, 81,
		121, 84,
		113, 85,
		109, 85,
		106, 83,
		103, 79,
		102, 72
	},
	-- U
	{
		152, 62,
		152, 85,
		153, 88,
		156, 90,
		160, 91,
		164, 91,
		168, 91,
		171, 90,
		172, 87,
		174, 84,
		177, 81,
		179, 79,
		180, 76,
		181, 73,
		182, 68,
		180, 84,
		179, 90,
		181, 93,
		183, 94,
	},
	--G
	{
		224, 68,
		214, 68,
		208, 76,
		208, 87,
		218, 93,
		223, 93,
		228, 88,
		230, 72,
		232, 93,
		232, 125,
		229, 131,
		227, 133,
		224, 133,
		220, 129,
		218, 124,
		218, 117
	},
	--H
	{
		247, 32,
		240, 76,
		240, 90,
		241, 83,
		247, 76,
		250, 74,
		253, 76,
		259, 89
	},
	--T part 1
	{
		289, 33,
		282, 59,
		282, 83,
		279, 93
	},
	--T part 2
	{
		270, 64,
		274, 61,
		288, 61
	},
	-- S
	{
		323, 62,
		318, 63,
		312, 68,
		312, 75,
		316, 79,
		321, 81,
		325, 83,
		324, 87,
		317, 87,
		313, 90,
		303, 90
	},
	-- PLUS 1
	{
		175, 113,
		176, 122,
		177, 125,
		178, 142

	},
	-- PLUS 2
	{
		168, 136,
		170, 134,
		184, 130,
		191, 127,
		197, 125
	},
	-- C
	{
		71, 149,
		63, 154,
		53, 166,
		48, 175,
		48, 189,
		52, 193,
		52, 195,
		59, 200,
		66, 202,
		79, 203
	},
	-- R
	{
		106, 172,
		106, 201,
		106, 180,
		111, 174,
		119, 172,
		124, 176

	},
	-- O
	{
		141, 193,
		143, 185,
		148, 174,
		154, 174,
		158, 171,
		164, 175,
		165, 188,
		161, 197,
		157, 199,
		154, 199,
		148, 195,
		148, 190
	},
	-- S
	{
		205, 172,
		203, 170,
		193, 170,
		188, 177,
		188, 181,
		203, 190,
		205, 193,
		205, 199,
		200, 201,
		195, 201,
		193, 204,
		188, 203,
		185, 194

	},
	-- S
	{
		234, 173,
		228, 173,
		224, 180,
		224, 184,
		238, 191,
		240, 193,
		239, 198,
		237, 200,
		232, 201,
		229, 201,
		225, 200
	},
	-- E
	{
		266, 188,
		271, 187,
		271, 178,
		267, 174,
		258, 174,
		255, 181,
		256, 187,
		262, 191,
		268, 197,
		282, 197
	},
	-- S
	{
		306, 173,
		299, 175,
		296, 177,
		296, 185,
		303, 192,
		305, 198,
		302, 202,
		290, 202,
		286, 199
	}
}

---@enum GameState
local GameState = {
	SplashScreen = 1,
	Playing = 2
}

local scores = {
	x = 0, o = 0
}

---@type _Image
local canvas

---@type integer | nil
local previousEraserY = nil

---@type Pencil
local pencil

---@class Cursor: _Sprite
---@field boardX boardDimension
---@field boardY boardDimension
---@overload fun(x: boardDimension, y: boardDimension): Cursor
Cursor = class('Cursor').extends(gfx.sprite) or Cursor

function Cursor:init(x, y)
	Cursor.super.init(self)

	self.boardX = x
	self.boardY = y
	self:UpdatePositionOnBoard()

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
	self:UpdatePositionOnBoard()
end

function Cursor:UpdatePositionOnBoard()
	local cursorPosition = ConvertBoardCoordinateToScreenSpace({
		x = self.boardX,
		y =
			self.boardY
	})
	self:moveTo(cursorPosition.x, cursorPosition.y)
end

---set the cursors position in board space
---@param x boardDimension
---@param y boardDimension
function Cursor:MoveToBoardCoordinate(x, y)
	self.boardX = x
	self.boardY = y

	local cursorPosition = ConvertBoardCoordinateToScreenSpace({
		x = self.boardX,
		y = self.boardY
	})
	self:moveTo(cursorPosition.x, cursorPosition.y)
end

local playingAi = true

---@alias symbol "-" | "o" | "x"
---@type "x" | "o"
local aiSymbol = "x"
---@type "x" | "o"
local playerSymbol = "o"
---@type symbol
local currentTurn = "x"

local someonesTurn = false

---@type Cursor
local cursor

--- Takes a cursor and converts it's board coordinate into screen space so that
--- it can be drawn
---@param coordinate boardCoordinate
---@return _Point
function ConvertBoardCoordinateToScreenSpace(coordinate)
	local screenX = 125 + (coordinate.x - 1) * 70
	local screenY = 45 + (coordinate.y - 1) * 60

	return pd.geometry.point.new(screenX, screenY)
end

---@type Board
local board

---@type GameState
local state = GameState.SplashScreen;


---@alias boardDimension 1 | 2 | 3

---@class boardCoordinate
---@field x boardDimension
---@field y boardDimension

function FlipTurn()
	if currentTurn == "x" then
		currentTurn = "o"
	else
		currentTurn = "x"
	end
end

function DrawBoard()
	someonesTurn = false

	pencil:movePencil(160, 21)
	coroutine.yield()

	pencil:startDrawing()
	coroutine.yield()

	pencil:moveAlongLine(160, 21, 156, 187)
	coroutine.yield()

	pencil:stopDrawing()
	coroutine.yield()

	pencil:movePencil(231, 19)
	coroutine.yield()

	pencil:startDrawing()
	coroutine.yield()

	pencil:moveAlongLine(231, 19, 225, 190)
	coroutine.yield()

	pencil:stopDrawing()
	coroutine.yield()

	pencil:movePencil(96, 74)
	coroutine.yield()

	pencil:startDrawing()
	coroutine.yield()

	pencil:moveAlongLine(96, 74, 291, 76)
	coroutine.yield()

	pencil:stopDrawing()
	coroutine.yield()

	pencil:movePencil(95, 135)
	coroutine.yield()

	pencil:startDrawing()
	coroutine.yield()

	pencil:moveAlongLine(95, 135, 293, 138)
	coroutine.yield()

	pencil:stopDrawing()
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

		pencil:startDrawing()
		coroutine.yield()

		pencil:moveInCircle(centre, NOUGHT_RADIUS)
		coroutine.yield()

		pencil:stopDrawing()
		coroutine.yield()

		someonesTurn = true
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

		pencil:movePencil(centre.x - 17, centre.y - 24)
		coroutine.yield()

		pencil:startDrawing()
		coroutine.yield()

		pencil:moveAlongLine(centre.x - 17, centre.y - 24, centre.x + 15, centre.y + 21)
		coroutine.yield()

		pencil:stopDrawing()
		coroutine.yield()

		pencil:movePencil(centre.x - 22, centre.y + 22)
		coroutine.yield()

		pencil:startDrawing();
		coroutine.yield();

		pencil:moveAlongLine(centre.x - 22, centre.y + 22, centre.x + 18, centre.y - 18)
		coroutine.yield()

		pencil:stopDrawing()
		coroutine.yield()

		someonesTurn = true
	end
end

---@param straight straight
function DrawWinningLine(straight)
	someonesTurn = false
	pencil.thickness = 8

	if straight == Straight.TopRow then
		pencil:moveAlongLine(89, 46, 301, 48)
	elseif straight == Straight.MiddleRow then
		pencil:moveAlongLine(87, 104, 306, 105)
	elseif straight == Straight.BottomRow then
		pencil:moveAlongLine(85, 164, 298, 168)
	elseif straight == Straight.LeftColumn then
		pencil:moveAlongLine(121, 15, 122, 191)
	elseif straight == Straight.MiddleColumn then
		pencil:moveAlongLine(196, 16, 191, 193)
	elseif straight == Straight.RightColumn then
		pencil:moveAlongLine(265, 15, 260, 193)
	elseif straight == Straight.TopLeftToBottomRight then
		pencil:moveAlongLine(103, 22, 285, 192)
	elseif straight == Straight.BottomLeftToTopRight then
		pencil:moveAlongLine(94, 187, 289, 23)
	end

	coroutine.yield()
end

function DrawSplashText()
	pencil.thickness = 4

	pencil:movePencil(splashLetters[1][1], splashLetters[1][2])
	coroutine:yield()

	for index in ipairs(splashLetters) do
		pencil:startDrawing()
		coroutine:yield()

		pencil:moveAlongPoly(pd.geometry.polygon.new(table.unpack(splashLetters[index])))
		coroutine:yield()

		pencil:stopDrawing()
		coroutine:yield()

		pencil:movePencil(splashLetters[index + 1][1], splashLetters[index + 1][2])
		coroutine:yield()
	end
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

	gfx.sprite.setBackgroundDrawingCallback(
		function()
			canvas:draw(0, 0)
		end
	)

	-- if pd.argv[1] ~= nil then
	-- 	NewGame(pd.argv[1])
	-- end

	pencil = Pencil(0, 0, canvas)
	pencil:add()

	pencil:queue(DrawSplashText)
end

---Starts a new game. Can safely be called at any time
---@param startState string?
function NewGame(startState)
	canvas:clear(gfx.kColorWhite)
	state = GameState.Playing

	-- setup game
	board = Board()
	currentTurn = "x"

	-- setup pencil
	if pencil ~= nil then
		pencil:remove()
	end
	pencil = Pencil(0, 0, canvas)
	pencil:add()

	-- setup cursor
	if cursor ~= nil then
		cursor:remove()
	end
	cursor = Cursor(1, 1)
	cursor:add()

	-- draw a board
	pencil:queue(DrawBoard)

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
		local winningSymbol = board:getWinnerInStraight(straight)

		if winningSymbol ~= nil then
			DrawWinningLine(straight)
			scores[winningSymbol] = 1
		end
	end
end

function pd.update()
	if state == GameState.SplashScreen then
		if pd.buttonJustPressed(pd.kButtonA)
			or pd.buttonJustPressed(pd.kButtonB) then
			NewGame()
		end
	elseif state == GameState.Playing then
		if pencil:isDone() and someonesTurn then
			CheckForWinner()
		end

		if someonesTurn then
			if playingAi and currentTurn == aiSymbol then
				local aiMove = ChooseAiMove(board, aiSymbol)
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

			pencil:SetGoal(cursor.x, cursor.y)

			if pd.buttonJustPressed(pd.kButtonA)
				and board:spaceIsFree(cursor.boardX, cursor.boardY) then
				PlayOnSpace(cursor.boardX, cursor.boardY, playerSymbol)
				FlipTurn()
			end

			cursor:setVisible(true)
		else
			cursor:setVisible(false)
		end

		if not pd.isCrankDocked() then
			-- TODO erasing should always starts from the top, no matter the
			-- start position of the crank
			-- TODO erasing the whole screen should take multiple turns of the crank
			-- TODO erasing the screen should happen in a back and forth motion (as if you're rubbing it out)

			local crankPosition = pd.getCrankPosition()
			local crankPositionToScreenY = math.floor((crankPosition / 360) *
				SCREEN_HEIGHT);

			if previousEraserY == nil then
				-- this means we've only just started erasing so set the
				-- starting pos to the current crank pos
				previousEraserY = crankPositionToScreenY
			end

			local erasedSectionY = math.min(previousEraserY,
				crankPositionToScreenY)
			local erasedSectionBottomY = math.max(previousEraserY,
				crankPositionToScreenY)

			local erasedSectionHeight = math.ceil(math.abs(erasedSectionY -
				erasedSectionBottomY))

			if erasedSectionHeight > 0 then
				gfx.lockFocus(canvas)
				gfx.setColor(gfx.kColorWhite)
				gfx.fillRect(
					0, erasedSectionY, SCREEN_WIDTH, erasedSectionHeight)
				gfx.unlockFocus()

				previousEraserY = previousEraserY + erasedSectionHeight
			end
		else
			previousEraserY = nil
		end
	end

	if not pencil:isDone() and pd.buttonJustPressed(pd.kButtonA) then
		pencil:skip()
	end

	gfx.sprite.redrawBackground()
	gfx.sprite.update()
	timer.updateTimers()

	-- gfx.drawTextAligned("X: " .. scores.x .. " - O: " .. scores.o, SCREEN_WIDTH / 2, SCREEN_HEIGHT - 30,
	-- 	kTextAlignment.center)
end

--- Plays a symbol in the provided space. Currently assumes that you have
--- already checked that the space is free.
---@param x 1 | 2 | 3
---@param y 1 | 2 | 3
---@param symbol "x" | "o"
function PlayOnSpace(x, y, symbol)
	board:setSpace(x, y, symbol)
	if symbol == "x" then
		pencil:queue(DrawCross(x, y))
	else
		pencil:queue(DrawNought(x, y))
	end
end

---Checks whether a given x and y coordinate lies on the board
---@param x integer
---@param y integer
---@return boolean
function IsOutOfBound(x, y)
	return x < 1 or x > 3 or y < 1 or y > 3
end

Setup()
