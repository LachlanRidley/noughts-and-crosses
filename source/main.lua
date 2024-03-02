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

local canvas

local plan = coroutine.create(function()
	x = 160
	y = 21

	goalX = 156
	goalY = 187

	coroutine.yield()

	x = 231
	y = 19
	goalX = 225
	goalY = 190

	coroutine.yield()

	x = 96
	y = 74
	goalX = 291
	goalY = 76

	coroutine.yield()

	x = 95
	y = 135
	goalX = 293
	goalY = 138
end)

function Setup()
	-- set the game up
	pd.display.setRefreshRate(30)

	-- setup canvas
	canvas = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT)

	-- get the start of the plan
	coroutine.resume(plan)
end

Setup()

function pd.update()
	local previousX = x
	local previousY = y

	UpdateTipPosition()
	gfx.lockFocus(canvas)
	gfx.setLineWidth(5)
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	gfx.drawLine(previousX, previousY, x, y)
	gfx.unlockFocus()

	if Distance(x, y, goalX, goalY) < SPEED + 1 then
		coroutine.resume(plan)
	end

	canvas:draw(0, 0)
	-- gfx.sprite.update()
	-- timer.updateTimers()
end

function UpdateTipPosition()
	local initialPositionVector = pd.geometry.vector2D.new(x, y)
	local goalVector = pd.geometry.vector2D.new(goalX, goalY)

	local movementVector = goalVector - initialPositionVector
	movementVector:normalize()
	movementVector *= SPEED

	x += movementVector.dx
	y += movementVector.dy
end

function Distance(x1, y1, x2, y2)
	local dx = x1 - x2
	local dy = y1 - y2
	return math.sqrt(dx * dx + dy * dy)
end
