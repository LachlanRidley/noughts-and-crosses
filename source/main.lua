import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240

local SPEED = 5

local mode = "drawing"

local x = SCREEN_WIDTH / 2
local y = SCREEN_HEIGHT / 2

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound
local timer <const> = pd.timer

local tip
local canvas

function Setup()
	-- setup pencil tip
	tip = gfx.sprite.new()
	tip:setSize(6, 6)
	function tip:draw()
		gfx.fillCircleAtPoint(3, 3, 3)
	end

	tip:moveTo(x, y)
	tip:add()

	-- setup canvas
	canvas = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT)
end

Setup()

function LoadGame()
	pd.display.setRefreshRate(30)
	gfx.setBackgroundColor(gfx.kColorWhite)
	gfx.clear()
end

function pd.update()
	previousX = x
	previousY = y

	if pd.buttonIsPressed(pd.kButtonLeft) then
		x -= SPEED
	end
	if pd.buttonIsPressed(pd.kButtonRight) then
		x += SPEED
	end
	if pd.buttonIsPressed(pd.kButtonUp) then
		y -= SPEED
	end
	if pd.buttonIsPressed(pd.kButtonDown) then
		y += SPEED
	end

	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		if mode == "drawing" then
			mode = "erasing"
		elseif mode == "erasing" then
			mode = "drawing"
		end
	end

	-- if mode == "drawing" then
	gfx.lockFocus(canvas)
	gfx.setLineWidth(5)
	gfx.setLineCapStyle(gfx.kLineCapStyleRound)
	gfx.drawLine(previousX, previousY, x, y)
	gfx.unlockFocus()

	-- gfx.fillCircleAtPoint(x, y, 3)
	-- elseif mode == "erasing" then
	-- 	gfx.drawCircleAtPoint(x, y, 3)
	-- end

	tip:moveTo(x, y)

	canvas:draw(0, 0)
	-- gfx.sprite.update()
	-- timer.updateTimers()
end
