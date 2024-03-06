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

local goalX
local goalY
local x
local y
local pencilAnimator

local highlightedX = 1
local highlightedY = 1

local penThickness = 2

local canvas
local playerCanInteract = false
local crossTurn = true

function DrawBoard()
	penThickness = 2
	x = 160
	y = 21

	goalX = 156
	goalY = 187
	SetupAnimator()

	coroutine.yield()

	x = 231
	y = 19
	goalX = 225
	goalY = 190
	SetupAnimator()

	coroutine.yield()

	x = 96
	y = 74
	goalX = 291
	goalY = 76
	SetupAnimator()

	coroutine.yield()

	x = 95
	y = 135
	goalX = 293
	goalY = 138
	SetupAnimator()

	coroutine.yield()

	playerCanInteract = true
end

function DrawNought()
	penThickness = 5
	playerCanInteract = false

	local centre = GetCursorPosition()
	x = centre.x
	y = centre.y - NOUGHT_RADIUS

	SetupAnimatorCircle()

	coroutine.yield()

	playerCanInteract = true
end

function DrawCross()
	penThickness = 5
	playerCanInteract = false

	local centre = GetCursorPosition()

	x = centre.x - 17
	y = centre.y - 24
	goalX = centre.x + 15
	goalY = centre.y + 21
	SetupAnimator()

	coroutine.yield()

	x = centre.x - 22
	y = centre.y + 22
	goalX = centre.x + 18
	goalY = centre.y - 18
	SetupAnimator()

	coroutine.yield()
	playerCanInteract = true
end

local plan
local cursor

function Setup()
	-- set the game up
	pd.display.setRefreshRate(50)

	-- setup canvas
	canvas = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT)

	cursor = gfx.sprite.new()
	local r = 5
	cursor:setSize(r * 2, r * 2)
	function cursor:draw()
		gfx.drawCircleAtPoint(r, r, r)
	end

	cursor:add()

	plan = coroutine.create(DrawBoard)
	coroutine.resume(plan)

	gfx.sprite.setBackgroundDrawingCallback(
		function()
			canvas:draw(0, 0)
		end
	)
end

function pd.update()
	local previousX = x
	local previousY = y

	UpdateTipPosition()
	gfx.sprite.redrawBackground()
	gfx.lockFocus(canvas)
	gfx.setLineWidth(math.random(penThickness, penThickness + 1))
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	gfx.drawLine(previousX, previousY, x, y)
	gfx.unlockFocus()

	if GoalReached() then
		coroutine.resume(plan)
	end

	if playerCanInteract then
		if pd.buttonJustPressed(pd.kButtonUp) then
			highlightedY = math.max(highlightedY - 1, 0)
		end
		if pd.buttonJustPressed(pd.kButtonDown) then
			highlightedY = math.min(highlightedY + 1, 2)
		end
		if pd.buttonJustPressed(pd.kButtonLeft) then
			highlightedX = math.max(highlightedX - 1, 0)
		end
		if pd.buttonJustPressed(pd.kButtonRight) then
			highlightedX = math.min(highlightedX + 1, 2)
		end

		if pd.buttonJustPressed(pd.kButtonA) then
			if crossTurn then
				plan = coroutine.create(DrawCross)
			else
				plan = coroutine.create(DrawNought)
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

function GetCursorPosition()
	local cursorX = 125 + highlightedX * 70
	local cursorY = 45 + highlightedY * 60

	return pd.geometry.point.new(cursorX, cursorY)
end

function SetupAnimator()
	local initialPoint = pd.geometry.point.new(x, y)
	local goalPoint = pd.geometry.point.new(goalX, goalY)

	pencilAnimator = gfx.animator.new(500, initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
end

function SetupAnimatorCircle()
	local path = pd.geometry.arc.new(x, y + NOUGHT_RADIUS, NOUGHT_RADIUS, 0, 360)

	pencilAnimator = gfx.animator.new(1000, path, pd.easingFunctions.inOutQuint)
end

function UpdateTipPosition()
	if pencilAnimator:ended() then
		return
	end

	local nextPoint = pencilAnimator:currentValue();
	print(nextPoint)
	x = nextPoint.x;
	y = nextPoint.y;
end

function GoalReached()
	return pencilAnimator:ended()
end

Setup()
