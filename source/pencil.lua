local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound

local pencilScratch = snd.sampleplayer.new("scratch")

---@class Pencil: _Sprite
---@field x integer
---@field y integer
---@field drawing boolean
---@field thickness integer
---@field private animator _Animator
---@field private action thread
---@overload fun(x: integer, y: integer, canvas: _Image): Pencil
Pencil = class('Pencil').extends(playdate.graphics.sprite) or Pencil

---@type _Image?
local pencilImage = gfx.image.new("pencil")

function Pencil:init(x, y, canvas)
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
    self.canvas = canvas
end

function Pencil:update()
    if self.animator:ended() then
        if coroutine.status(self.action) == "dead" then return end

        -- TODO if there's no actions queued then the pencil should just drift towards the cursor

        coroutine.resume(self.action)
    end

    local previousX = self.x
    local previousY = self.y

    local nextPoint = self.animator:currentValue();
    self:moveTo(nextPoint.x, nextPoint.y)

    if self.drawing then
        gfx.lockFocus(self.canvas)
        gfx.setLineWidth(math.random(self.thickness, self.thickness + 1))
        gfx.setLineCapStyle(gfx.kLineCapStyleRound)
        gfx.drawLine(previousX, previousY, self.x, self.y)
        gfx.unlockFocus()
    end
end

function Pencil:DrawLine(x1, y1, x2, y2)
    local initialPoint = pd.geometry.point.new(x1, y1)
    local goalPoint = pd.geometry.point.new(x2, y2)

    self.animator = gfx.animator.new(1000,
        initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
    self.drawing = true
    self:moveTo(x1, y1)

    pencilScratch:play()
end

function Pencil:DrawPoly(poly)
    self.animator = gfx.animator.new(poly:length() * 10, poly,
        pd.easingFunctions.inOutQuint)
    self.drawing = true
    self:moveTo(poly:getPointAt(1))

    pencilScratch:play()
end

function Pencil:IsDone()
    return self.animator:ended()
end

---Raise the pencil and move it to a position
---@param x integer
---@param y integer
function Pencil:MovePencil(x, y)
    self.drawing = false
    local initialPoint = pd.geometry.point.new(self.x, self.y)
    local goalPoint = pd.geometry.point.new(x, y)

    self.animator = gfx.animator.new(500, initialPoint, goalPoint,
        pd.easingFunctions.inOutQuint)
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

function Pencil:Queue(fun)
    self.action = coroutine.create(fun)
    coroutine.resume(self.action)
end
