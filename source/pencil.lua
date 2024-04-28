local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound

local maxGroundOffset <const> = 10

local pencilScratch = snd.sampleplayer.new("scratch")

---@class Pencil: _Sprite
---@field x integer
---@field y integer
---@field drawing boolean
---@field thickness integer
---@field private animator _Animator
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
    self.drawing = false
    self.groundOffset = maxGroundOffset
    self.thickness = 2
    self.canvas = canvas

    local ditheredPencilShadowImage = pencilShadowImage:fadedImage(0.5, gfx.image.kDitherTypeBayer2x2)
    self.shadow = gfx.sprite.new(ditheredPencilShadowImage)
    self.shadow:setCenter(0, 1)
    self.shadow:moveTo(self.x, self.y)
    self.shadow:add()
end

function Pencil:startDrawing()
    self.drawing = true
    self.raisePencilAnimator = gfx.animator.new(300, self.groundOffset, 0)
end

function Pencil:stopDrawing()
    self.drawing = false
    self.raisePencilAnimator = gfx.animator.new(300, self.groundOffset, maxGroundOffset)
end

function Pencil:update()
    if self.animator:ended() then
        if coroutine.status(self.action) ~= "dead" then
            coroutine.resume(self.action)
        end
    end

    local previousX = self.x
    local previousY = self.y

    -- update ground offset with animator
    if self.raisePencilAnimator ~= nil then
        self.groundOffset = self.raisePencilAnimator:currentValue();
    end

    local shadowXOffset = self.groundOffset
    local pencilYOffset = -self.groundOffset

    if not self.animator:ended() then
        local nextPoint = self.animator:currentValue();
        self:moveTo(nextPoint.x, nextPoint.y + pencilYOffset)
    end

    if self:HasNoQueuedActions() then
        self:moveTowardsGoal()
    end

    if self.groundOffset == 0 then
        gfx.lockFocus(self.canvas)
        gfx.setLineWidth(math.random(self.thickness, self.thickness + 1))
        gfx.setLineCapStyle(gfx.kLineCapStyleRound)
        gfx.drawLine(previousX, previousY, self.x, self.y)
        gfx.unlockFocus()
    end

    self.shadow:moveTo(self.x + shadowXOffset, self.y - pencilYOffset) -- TODO it's gross we have to subtract pencil offset here. We should save canonical coordinates which we offset both sprites from
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

function Pencil:drawLine(x1, y1, x2, y2)
    local initialPoint = pd.geometry.point.new(x1, y1)
    local goalPoint = pd.geometry.point.new(x2, y2)

    self.animator = gfx.animator.new(1000,
        initialPoint, goalPoint, pd.easingFunctions.inOutQuint)
    self:startDrawing()
    self:moveTo(x1, y1)

    pencilScratch:play()
end

function Pencil:drawPoly(poly)
    self.animator = gfx.animator.new(poly:length() * 10, poly,
        pd.easingFunctions.inOutQuint)
    self:startDrawing()
    self:moveTo(poly:getPointAt(1))

    pencilScratch:play()
end

function Pencil:IsDone()
    return self.animator:ended()
end

function Pencil:HasNoQueuedActions()
    return coroutine.status(self.action) == "dead"
end

---Raise the pencil and move it to a position
---@param x integer
---@param y integer
function Pencil:movePencil(x, y)
    self:stopDrawing()
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
function Pencil:drawCircle(centre, radius)
    self:startDrawing()
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
