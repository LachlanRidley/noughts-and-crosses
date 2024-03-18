import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local GameState = {
	SplashScreen = 1,
	Playing = 2
}

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240

local NOUGHT_RADIUS <const> = 20

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound
local timer <const> = pd.timer

local pencilAnimator
local pencilAction
local pencilScratch = snd.sampleplayer.new("scratch")

local pencilImage = gfx.image.new("pencil")

local previousEraserY = nil

class('Pencil').extends(playdate.graphics.sprite)

function Pencil:init(x, y)
	Pencil.super.init(self)
	self:setImage(pencilImage)
	self:moveTo(x, y)
	self:setCenter(0, 1)
	self.drawing = false
end

local pencil

local highlightedX = 2
local highlightedY = 2

local playingAi = true
local aiSymbol = "x"
local playerSymbol = "o"
local currentTurn = "x"

local penThickness = 2

local canvas
local someonesTurn = false

local cursor
local board
local state = GameState.SplashScreen;

-- straights are the 8 possible winning rows.
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

function DrawLine(x1, y1, x2, y2)
	local initialPoint = pd.geometry.point.new(x1, y1)
	local goalPoint = pd.geometry.point.new(x2, y2)

	pencilAnimator = gfx.animator.new(1000, initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
	pencil.drawing = true
	pencil:moveTo(x1, y1)

	pencilScratch:play()
end

function MovePencil(x, y)
	pencil.drawing = false
	local initialPoint = pd.geometry.point.new(pencil.x, pencil.y)
	local goalPoint = pd.geometry.point.new(x, y)

	pencilAnimator = gfx.animator.new(500, initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
end

function DrawCircle(centre, r)
	pencil.drawing = true
	pencil:moveTo(centre.x, centre.y - r)

	local path = pd.geometry.arc.new(centre.x, centre.y, r, 0, 360)

	pencilAnimator = gfx.animator.new(1000, path, pd.easingFunctions.inOutQuint)
	pencilScratch:play()
end

function DrawBoard()
	someonesTurn = false

	DrawLine(160, 21, 156, 187)
	coroutine.yield()

	MovePencil(231, 19)
	coroutine.yield()

	DrawLine(231, 19, 225, 190)
	coroutine.yield()

	MovePencil(96, 74)
	coroutine.yield()

	DrawLine(96, 74, 291, 76)
	coroutine.yield()

	MovePencil(95, 135)
	coroutine.yield()

	DrawLine(95, 135, 293, 138)
	coroutine.yield()

	someonesTurn = true
end

function DrawNought()
	penThickness = 5
	someonesTurn = false

	local centre = GetCursorPosition()

	DrawCircle(centre, NOUGHT_RADIUS)
	coroutine.yield()

	someonesTurn = true
	pencil.drawing = false
end

function DrawCross()
	penThickness = 5
	someonesTurn = false

	local centre = GetCursorPosition()

	DrawLine(centre.x - 17, centre.y - 24, centre.x + 15, centre.y + 21)
	coroutine.yield()

	DrawLine(centre.x - 22, centre.y + 22, centre.x + 18, centre.y - 18)
	coroutine.yield()

	someonesTurn = true
	pencil.drawing = false
end

function DrawWinningLine(straight)
	someonesTurn = false
	penThickness = 8

	if straight == Straight.TopRow then
		DrawLine(89, 46, 301, 48)
	elseif straight == Straight.MiddleRow then
		DrawLine(87, 104, 306, 105)
	elseif straight == Straight.BottomRow then
		DrawLine(85, 164, 298, 168)
	elseif straight == Straight.LeftColumn then
		DrawLine(121, 15, 122, 191)
	elseif straight == Straight.MiddleColumn then
		DrawLine(196, 16, 191, 193)
	elseif straight == Straight.RightColumn then
		DrawLine(265, 15, 260, 193)
	elseif straight == Straight.TopLeftToBottomRight then
		DrawLine(103, 22, 285, 192)
	elseif straight == Straight.BottomLeftToTopRight then
		DrawLine(94, 187, 289, 23)
	end

	coroutine.yield()
end

function Setup()
	-- set the game up
	pd.display.setRefreshRate(50)

	-- setup canvas
	canvas = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT)

	-- setup cursor
	cursor = gfx.sprite.new()
	local r = 5
	cursor:setSize(r * 2, r * 2)
	function cursor:draw()
		gfx.drawCircleAtPoint(r, r, r)
	end

	cursor:add()

	gfx.sprite.setBackgroundDrawingCallback(
		function()
			canvas:draw(0, 0)
		end
	)
end

function NewGame()
	canvas:clear(gfx.kColorWhite)
	state = GameState.Playing

	-- setup board
	board = table.create(3, 0)
	board[1] = { "-", "-", "-" }
	board[2] = { "-", "-", "-" }
	board[3] = { "-", "-", "-" }

	-- setup pencil
	pencil = Pencil(0, 0)
	pencil:add()

	-- draw a board
	pencilAction = coroutine.create(DrawBoard)
	coroutine.resume(pencilAction)
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
	gfx.drawText("Noughts + Crosses", 20, SCREEN_HEIGHT / 2)
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

	local previousX = pencil.x
	local previousY = pencil.y

	UpdateTipPosition()
	gfx.sprite.redrawBackground()

	if pencil.drawing then
		gfx.lockFocus(canvas)
		gfx.setLineWidth(math.random(penThickness, penThickness + 1))
		gfx.setLineCapStyle(gfx.kLineCapStyleRound)
		gfx.drawLine(previousX, previousY, pencil.x, pencil.y)
		gfx.unlockFocus()
	end

	if GoalReached() then
		coroutine.resume(pencilAction)
		if someonesTurn then
			CheckForWinner()
		end
	end

	if someonesTurn then
		if playingAi and currentTurn == aiSymbol then
			local aiMove = ChooseAiMove()
			highlightedX = aiMove.x
			highlightedY = aiMove.y

			board[highlightedX][highlightedY] = aiSymbol
			if aiSymbol == "x" then
				pencilAction = coroutine.create(DrawCross)
			else
				pencilAction = coroutine.create(DrawNought)
			end

			FlipTurn()
		end

		if pd.buttonJustPressed(pd.kButtonUp) then
			MoveCursor("up")
		end
		if pd.buttonJustPressed(pd.kButtonDown) then
			MoveCursor("down")
		end
		if pd.buttonJustPressed(pd.kButtonLeft) then
			MoveCursor("left")
		end
		if pd.buttonJustPressed(pd.kButtonRight) then
			MoveCursor("right")
		end

		if pd.buttonJustPressed(pd.kButtonA) and SpaceIsFree(highlightedX, highlightedY) then
			board[highlightedX][highlightedY] = playerSymbol
			if currentTurn == "x" then
				pencilAction = coroutine.create(DrawCross)
			else
				pencilAction = coroutine.create(DrawNought)
			end

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


	gfx.sprite.update()
	timer.updateTimers()
end

function SpaceIsFree(x, y)
	return board[x][y] == "-"
end

function IsOutOfBound(x, y)
	return x < 1 or x > 3 or y < 1 or y > 3
end

function MoveCursor(direction)
	local newX = highlightedX
	local newY = highlightedY

	repeat
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
	until SpaceIsFree(newX, newY)

	highlightedX = newX
	highlightedY = newY

	local cursorPosition = GetCursorPosition()
	cursor:moveTo(cursorPosition)
	pencil:moveTo(cursorPosition) -- TODO probably don't need to do this twice
end

function ChooseAiMove()
	-- SOURCE: https://en.wikipedia.org/wiki/Tic-tac-toe#Strategy
	local availableMoves = {}

	for x = 1, 3, 1 do
		for y = 1, 3, 1 do
			if SpaceIsFree(x, y) then
				table.insert(availableMoves, { x = x, y = y })
			end
		end
	end

	-- this doesn't quite work. Because we're iterating the available moves rather than the strategies, the AI will pick worse moves if they come up first
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

function GetCursorPosition()
	local cursorX = 125 + (highlightedX - 1) * 70
	local cursorY = 45 + (highlightedY - 1) * 60

	return pd.geometry.point.new(cursorX, cursorY)
end

function UpdateTipPosition()
	if pencilAnimator:ended() then
		return
	end

	local nextPoint = pencilAnimator:currentValue();
	pencil:moveTo(nextPoint)
end

function GoalReached()
	return pencilAnimator:ended()
end

Setup()
