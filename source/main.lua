import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240

local NOUGHT_RADIUS <const> = 20

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound
local timer <const> = pd.timer

local pencilX
local pencilY
local pencilAnimator
local pencilAction

local highlightedX = 2
local highlightedY = 2

local playingAi = true

local penThickness = 2

local canvas
local someonesTurn = false
local crossTurn = true

function DrawLine(x1, y1, x2, y2)
	pencilX = x1
	pencilY = y1

	local initialPoint = pd.geometry.point.new(x1, y1)
	local goalPoint = pd.geometry.point.new(x2, y2)

	pencilAnimator = gfx.animator.new(500, initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
end

function DrawCircle(centre, r)
	pencilX = centre.x
	pencilY = centre.y - r

	local path = pd.geometry.arc.new(centre.x, centre.y, r, 0, 360)

	pencilAnimator = gfx.animator.new(1000, path, pd.easingFunctions.inOutQuint)
end

function DrawBoard()
	someonesTurn = false

	DrawLine(160, 21, 156, 187)
	coroutine.yield()

	DrawLine(231, 19, 225, 190)
	coroutine.yield()

	DrawLine(96, 74, 291, 76)
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
end

function DrawWinningLine(location)
	someonesTurn = false
	penThickness = 8

	if location == "row1" then
		DrawLine(89, 46, 301, 48)
	elseif location == "row2" then
		DrawLine(87, 104, 306, 105)
	elseif location == "row3" then
		DrawLine(85, 164, 298, 168)
	elseif location == "col1" then
		DrawLine(121, 15, 122, 191)
	elseif location == "col2" then
		DrawLine(196, 16, 191, 193)
	elseif location == "col3" then
		DrawLine(265, 15, 260, 193)
	elseif location == "tl-to-br" then
		DrawLine(103, 22, 285, 192)
	elseif location == "bl-to-tr" then
		DrawLine(94, 187, 289, 23)
	end

	coroutine.yield()
end

local cursor
local board

function Setup()
	-- set the game up
	pd.display.setRefreshRate(50)

	-- setup board
	board = table.create(3, 0)
	board[1] = { "-", "-", "-" }
	board[2] = { "-", "-", "-" }
	board[3] = { "-", "-", "-" }

	-- setup canvas
	canvas = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT)

	cursor = gfx.sprite.new()
	local r = 5
	cursor:setSize(r * 2, r * 2)
	function cursor:draw()
		gfx.drawCircleAtPoint(r, r, r)
	end

	cursor:add()

	pencilAction = coroutine.create(DrawBoard)
	coroutine.resume(pencilAction)

	gfx.sprite.setBackgroundDrawingCallback(
		function()
			canvas:draw(0, 0)
		end
	)
end

function CheckForWinner()
	if someonesTurn then
		for row = 1, 3, 1 do
			if CountInRow(row, "x") == 3 or CountInRow(row, "o") == 3 then
				DrawWinningLine("row" .. tostring(row))
				return
			end
		end

		for col = 1, 3, 1 do
			if CountInCol(col, "x") == 3 or CountInCol(col, "o") == 3 then
				DrawWinningLine("col" .. tostring(col))
				return
			end
		end

		if CountInTopLeftToBottomRight("x") == 3 or CountInTopLeftToBottomRight("o") == 3 then
			DrawWinningLine("tl-to-br")
			return
		end

		if CountInBottomLeftToTopRight("x") == 3 or CountInBottomLeftToTopRight("o") == 3 then
			DrawWinningLine("bl-to-tr")
			return
		end
	end
end

function pd.update()
	local previousX = pencilX
	local previousY = pencilY

	UpdateTipPosition()
	gfx.sprite.redrawBackground()
	gfx.lockFocus(canvas)
	gfx.setLineWidth(math.random(penThickness, penThickness + 1))
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	gfx.drawLine(previousX, previousY, pencilX, pencilY)
	gfx.unlockFocus()

	if GoalReached() then
		coroutine.resume(pencilAction)
		CheckForWinner()
	end

	if someonesTurn then
		if playingAi and not crossTurn then
			local aiMove = ChooseAiMove()
			highlightedX = aiMove.x
			highlightedY = aiMove.y

			board[highlightedX][highlightedY] = "o"
			pencilAction = coroutine.create(DrawNought)

			crossTurn = not crossTurn
		end

		if pd.buttonJustPressed(pd.kButtonUp) then
			highlightedY = math.max(highlightedY - 1, 1)
		end
		if pd.buttonJustPressed(pd.kButtonDown) then
			highlightedY = math.min(highlightedY + 1, 3)
		end
		if pd.buttonJustPressed(pd.kButtonLeft) then
			highlightedX = math.max(highlightedX - 1, 1)
		end
		if pd.buttonJustPressed(pd.kButtonRight) then
			highlightedX = math.min(highlightedX + 1, 3)
		end

		if pd.buttonJustPressed(pd.kButtonA) and SpaceIsFree(highlightedX, highlightedY) then
			if crossTurn then
				board[highlightedX][highlightedY] = "x"
				pencilAction = coroutine.create(DrawCross)
			else
				board[highlightedX][highlightedY] = "o"
				pencilAction = coroutine.create(DrawNought)
			end

			crossTurn = not crossTurn
		end

		cursor:setVisible(true)

		cursor:moveTo(GetCursorPosition())
	else
		cursor:setVisible(false)
	end

	gfx.sprite.update()
	timer.updateTimers()
end

function SpaceIsFree(x, y)
	return board[x][y] == "-"
end

function ChooseAiMove()
	local availableMoves = {}

	for col = 1, 3, 1 do
		for row = 1, 3, 1 do
			if SpaceIsFree(col, row) then
				table.insert(availableMoves, { x = col, y = row })
			end
		end
	end

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
	pencilX = nextPoint.x;
	pencilY = nextPoint.y;
end

function GoalReached()
	return pencilAnimator:ended()
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

Setup()
