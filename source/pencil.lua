import "CoreLibs/math"

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound

local maxGroundOffset <const> = 10

local pencilScratch = snd.sampleplayer.new("scratch")

---@class Pencil: _Sprite
---@field x integer
---@field y integer
---@field thickness integer
---@field private lineToDraw _LineSegment | nil
---@field private animator _Animator | nil
---@field private raisePencilAnimator _Animator | nil
---@field private groundOffset number
---@field private action thread
---@field private goal _Point | nil
---@field private shadow _Sprite
---@overload fun(x: integer, y: integer, canvas: _Image): Pencil
Pencil = class('Pencil').extends(playdate.graphics.sprite) or Pencil

---@type _Image?
local pencilShadowImage = gfx.image.new("pencil-shadow")

---@type _Image?
local pencilImage = gfx.image.new("pencil")

function Pencil:init(x, y, canvas)
    Pencil.super.init(self)
    if pencilImage == nil or pencilShadowImage == nil then
        print("Failed to load images")
        return
    end

    self:setImage(pencilImage)
    self:moveTo(x, y)
    self:setCenter(0, 1)
    self.groundOffset = maxGroundOffset
    self.thickness = 2
    self.canvas = canvas

    local ditheredPencilShadowImage = pencilShadowImage:fadedImage(0.5, gfx.image.kDitherTypeBayer2x2)
    self.shadow = gfx.sprite.new(ditheredPencilShadowImage)
    self.shadow:setCenter(0, 1)
    self.shadow:moveTo(self.x, self.y)
    self.shadow:add()
end

function Pencil:update()
    local previousX = self.x
    local previousY = self.y + self.groundOffset

    local nextX = previousX
    local nextY = previousY

    if self.raisePencilAnimator ~= nil then
        self.groundOffset = self.raisePencilAnimator:currentValue();
    end

    if self:isDone() then
        if coroutine.status(self.action) ~= "dead" then
            coroutine.resume(self.action)
        end
    end

    if self.animator ~= nil and not self.animator:ended() then
        local nextPoint = self.animator:currentValue();
        nextX = nextPoint.x
        nextY = nextPoint.y
    end

    if self:HasNoQueuedActions() then
        self:moveTowardsGoal()
    end

    if self.groundOffset == 0 then
        gfx.lockFocus(self.canvas)
        gfx.setLineWidth(math.random(self.thickness, self.thickness + 1))
        gfx.setLineCapStyle(gfx.kLineCapStyleRound)
        gfx.drawLine(previousX, previousY, nextX, nextY)
        gfx.unlockFocus()
    end

    self:moveTo(nextX, nextY - self.groundOffset)
    self.shadow:moveTo(nextX + self.groundOffset, nextY)
end

function Pencil:skip()
    if self:isDone() then return end
    if self.lineToDraw == nil then return end

    local distanceLeft = pd.geometry.distanceToPoint(self.x, self.y, self.lineToDraw.x2, self.lineToDraw.y2);

    local segments = distanceLeft / 3;

    gfx.lockFocus(self.canvas)
    for i = 0, segments, 1 do
        local previousX = self.x
        local previousY = self.y

        self.x = pd.math.lerp(self.x, self.lineToDraw.x2, 1 / segments * i)
        self.y = pd.math.lerp(self.y, self.lineToDraw.y2, 1 / segments * i)

        if self.groundOffset == 0 then
            gfx.setLineWidth(math.random(self.thickness, self.thickness + 1))
            gfx.setLineCapStyle(gfx.kLineCapStyleRound)
            gfx.drawLine(previousX, previousY, self.x, self.y)
        end
    end
    gfx.unlockFocus()

    self.animator = nil
end

function Pencil:moveTowardsGoal()
    if self.goal == nil then return end

    local goalPosVector = pd.geometry.vector2D.new(self.goal.x, self.goal.y)
    local currentPosVector = pd.geometry.vector2D.new(self.x, self.y)

    ---@type _Vector2D
    local travelVector = goalPosVector - currentPosVector

    local distanceToGoal = travelVector:magnitude()

    if distanceToGoal <= 5 then
        self.goal = nil
    else
        travelVector:normalize()
        travelVector:scale(5)

        self:moveBy(travelVector.dx, travelVector.dy)
    end
end

function Pencil:startDrawing()
    self.raisePencilAnimator = gfx.animator.new(300, self.groundOffset, 0)
end

function Pencil:stopDrawing()
    self.raisePencilAnimator = gfx.animator.new(300, self.groundOffset, maxGroundOffset)
end

function Pencil:moveAlongLine(x1, y1, x2, y2)
    self.lineToDraw = playdate.geometry.lineSegment.new(x1, y1, x2, y2)

    self.animator = gfx.animator.new(1000, self.lineToDraw, pd.easingFunctions.inOutQuint)
    self:moveTo(x1, y1)

    pencilScratch:play()
end

function Pencil:moveAlongPoly(poly)
    self.animator = gfx.animator.new(poly:length() * 10, poly,
        pd.easingFunctions.inOutQuint)
    self:moveTo(poly:getPointAt(1))

    pencilScratch:play()
end

function Pencil:isDone()
    local doneMoving = self.animator == nil or self.animator:ended()
    local doneRaising = self.raisePencilAnimator == nil or self.raisePencilAnimator:ended()

    return doneMoving and doneRaising
end

function Pencil:HasNoQueuedActions()
    return coroutine.status(self.action) == "dead"
end

---Raise the pencil and move it to a position
---@param x integer
---@param y integer
function Pencil:movePencil(x, y)
    local initialPoint = pd.geometry.point.new(self.x, self.y)
    local goalPoint = pd.geometry.point.new(x, y)

    self.animator = gfx.animator.new(500, initialPoint, goalPoint,
        pd.easingFunctions.inOutQuint)
end

---Set a location for the pencil to move towards. Is overridden by queued actions
---@param x integer
---@param y integer
function Pencil:SetGoal(x, y)
    self.goal = pd.geometry.point.new(x, y)
end

---Queues a circle draw
---@param centre _Point
---@param radius integer
function Pencil:moveInCircle(centre, radius)
    self:moveTo(centre.x, centre.y - radius)

    local path = pd.geometry.arc.new(centre.x, centre.y, radius, 0, 360)

    self.animator = gfx.animator.new(1000, path, pd.easingFunctions.inOutQuint)
    pencilScratch:play()
end

function Pencil:queue(fun)
    self.action = coroutine.create(fun)
    coroutine.resume(self.action)
end

function Pencil:remove()
    self.shadow:remove();
    Pencil.super.remove(self)
end
