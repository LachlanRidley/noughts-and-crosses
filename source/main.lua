import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

local SPEED = 10

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound
local timer <const> = pd.timer

local goalX
local goalY
local x
local y
local pencilAnimator

local canvas

function DrawBoard()
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
end

local plan;

function Setup()
	-- set the game up
	pd.display.setRefreshRate(30)

	-- setup canvas
	canvas = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT)

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
	gfx.setLineWidth(math.random(2, 3))
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	gfx.drawLine(previousX, previousY, x, y)
	gfx.unlockFocus()

	if GoalReached() then
		coroutine.resume(plan)
		SetupAnimator()
	end


	gfx.sprite.update()
	timer.updateTimers()
end

function SetupAnimator()
	local initialPoint = pd.geometry.point.new(x, y)
	local goalPoint = pd.geometry.point.new(goalX, goalY)

	pencilAnimator = gfx.animator.new(500, initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
end

function UpdateTipPosition()
	local nextPoint = pencilAnimator:currentValue();
	x = nextPoint.x;
	y = nextPoint.y;
end

function GoalReached()
	return pencilAnimator:ended()
end

Setup()
