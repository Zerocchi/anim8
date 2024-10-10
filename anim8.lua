local anim8 = {
    _VERSION = "anim8 v2.3.1",
    _DESCRIPTION = "An animation library for LÖVE",
    _URL = "https://github.com/kikito/anim8",
    _LICENSE = [[
    MIT LICENSE

    Copyright (c) 2011 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]],
}

---@class Grid
---@field frameWidth integer
---@field frameHeight integer
---@field imageHeight integer
---@field imageWidth integer
---@field left number
---@field top number
---@field border number
---@field width integer
---@field height integer
---@field _key integer
---
---@field getFrames fun(self: Grid, ...:number|string): love.Quad

---@type Grid
---@diagnostic disable-next-line: missing-fields
local Grid = {}

---@type love.Quad[]
local _frames = {}

---@param value any
---@param name any
local function assertPositiveInteger(value, name)
    if type(value) ~= "number" then
        error(("%s should be a number, was %q"):format(name, tostring(value)))
    end
    if value < 1 then
        error(("%s should be a positive number, was %d"):format(name, value))
    end
    if value ~= math.floor(value) then
        error(("%s should be an integer, was %f"):format(name, value))
    end
end

---@param self Grid
---@param x number
---@param y number
---@return love.Quad
local function createFrame(self, x, y)
    local fw, fh = self.frameWidth, self.frameHeight
    return love.graphics.newQuad(
        self.left + (x - 1) * fw + x * self.border,
        self.top + (y - 1) * fh + y * self.border,
        fw,
        fh,
        self.imageWidth,
        self.imageHeight
    )
end

---@vararg any
---@return string
local function getGridKey(...)
    return table.concat({ ... }, "-")
end

---@param self Grid
---@param x number
---@param y number
---@return love.Quad
local function getOrCreateFrame(self, x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        error(("There is no frame for x=%d, y=%d"):format(x, y))
    end
    local key = self._key
    _frames[key] = _frames[key] or {}
    _frames[key][x] = _frames[key][x] or {}
    _frames[key][x][y] = _frames[key][x][y] or createFrame(self, x, y)
    return _frames[key][x][y]
end

---@param str number|string
---@return number?, number?, integer
local function parseInterval(str)
    if type(str) == "number" then
        return str, str, 1
    end
    str = str:gsub("%s", "") -- remove spaces
    local min, max = str:match("^(%d+)-(%d+)$")
    assert(min and max, ("Could not parse interval from %q"):format(str))
    min, max = tonumber(min), tonumber(max)
    local step = min <= max and 1 or -1
    return min, max, step
end

---@param ... number|string
---@return love.Quad[]
function Grid:getFrames(...)
    local result, args = {}, { ... }
    local minx, maxx, stepx, miny, maxy, stepy

    for i = 1, #args, 2 do
        minx, maxx, stepx = parseInterval(args[i])
        miny, maxy, stepy = parseInterval(args[i + 1])
        for y = miny, maxy, stepy do
            for x = minx, maxx, stepx do
                result[#result + 1] = getOrCreateFrame(self, x, y)
            end
        end
    end

    return result
end

local Gridmt = {
    __index = Grid,
    __call = Grid.getFrames,
}

---@param frameWidth integer
---@param frameHeight integer
---@param imageWidth integer
---@param imageHeight integer
---@param left? number
---@param top? number
---@param border? number
---@return Grid
local function newGrid(
    frameWidth,
    frameHeight,
    imageWidth,
    imageHeight,
    left,
    top,
    border
)
    assertPositiveInteger(frameWidth, "frameWidth")
    assertPositiveInteger(frameHeight, "frameHeight")
    assertPositiveInteger(imageWidth, "imageWidth")
    assertPositiveInteger(imageHeight, "imageHeight")

    left = left or 0
    top = top or 0
    border = border or 0

    local key = getGridKey(
        frameWidth,
        frameHeight,
        imageWidth,
        imageHeight,
        left,
        top,
        border
    )

    ---@type Grid
    local grid = setmetatable({
        frameWidth = frameWidth,
        frameHeight = frameHeight,
        imageWidth = imageWidth,
        imageHeight = imageHeight,
        left = left,
        top = top,
        border = border,
        width = math.floor(imageWidth / frameWidth),
        height = math.floor(imageHeight / frameHeight),
        _key = key,
    }, Gridmt)
    return grid
end

-----------------------------------------------------------

---@class Animation
---@field frames love.Quad[]
---@field durations number|table
---@field onLoop fun(self: Animation, loops: integer)|string?
---@field flippedH boolean?
---@field flippedV boolean?
---@field intervals number[]?
---@field totalDuration number?
---@field timer number,
---@field position integer
---@field status "playing"|"paused"
---
---@field clone fun(self: Animation, ...: number|string): Animation
---@field flipH fun(self: Animation): self
---@field flipV fun(self: Animation): self
---@field update fun(self: Animation, dt: number)
---@field pause fun(self: Animation)
---@field gotoFrame fun(self: Animation, position: integer)
---@field pauseAtEnd fun(self: Animation)
---@field pauseAtStart fun(self: Animation)
---@field resume fun(self: Animation)
---@field draw fun(self: Animation, image: love.Texture|love.Drawable, x: number?, y: number?, r: number?, sx: number?, sy: number?, ox: number?, oy: number?, kx: number?, ky: number?)
---@field getFrameInfo fun(self: Animation, x: number?, y: number?, r: number?, sx: number?, sy: number?, ox: number?, oy: number?, kx: number?, ky: number?): love.Quad, number?, number?, number?, number?, number?, number?, number?, number?, number?
---@field getDimensions fun(self: Animation): number, number

---@type Animation
---@diagnostic disable-next-line: missing-fields
local Animation = {}

---@param arr table
---@return table
local function cloneArray(arr)
    local result = {}
    for i = 1, #arr do
        result[i] = arr[i]
    end
    return result
end

---@param durations number|table
---@param frameCount integer
---@return table
local function parseDurations(durations, frameCount)
    local result = {}
    if type(durations) == "number" then
        for i = 1, frameCount do
            result[i] = durations
        end
    else
        local min, max, step
        for key, duration in pairs(durations) do
            assert(
                type(duration) == "number",
                "The value [" .. tostring(duration) .. "] should be a number"
            )
            min, max, step = parseInterval(key)
            for i = min, max, step do
                result[i] = duration
            end
        end
    end

    if #result < frameCount then
        error(
            "The durations table has length of "
                .. tostring(#result)
                .. ", but it should be >= "
                .. tostring(frameCount)
        )
    end

    return result
end

---@param durations number|table
---@return table, integer
local function parseIntervals(durations)
    local result, time = { 0 }, 0
    for i = 1, #durations do
        time = time + durations[i]
        result[i + 1] = time
    end
    return result, time
end

local Animationmt = { __index = Animation }
local nop = function() end

---@param frames love.Quad[]
---@param durations number|table
---@param onLoop function|string?
---@return Animation
local function newAnimation(frames, durations, onLoop)
    local td = type(durations)
    if (td ~= "number" or durations <= 0) and td ~= "table" then
        error(
            "durations must be a positive number. Was " .. tostring(durations)
        )
    end
    onLoop = onLoop or nop
    durations = parseDurations(durations, #frames)
    local intervals, totalDuration = parseIntervals(durations)
    return setmetatable({
        frames = cloneArray(frames),
        durations = durations,
        intervals = intervals,
        totalDuration = totalDuration,
        onLoop = onLoop,
        timer = 0,
        position = 1,
        status = "playing",
        flippedH = false,
        flippedV = false,
    }, Animationmt)
end

---@return Animation
function Animation:clone()
    local newAnim = newAnimation(self.frames, self.durations, self.onLoop)
    newAnim.flippedH, newAnim.flippedV = self.flippedH, self.flippedV
    return newAnim
end

---@return Animation
function Animation:flipH()
    self.flippedH = not self.flippedH
    return self
end

---@return Animation
function Animation:flipV()
    self.flippedV = not self.flippedV
    return self
end

---@param intervals number[]
---@param timer number
---@return integer
local function seekFrameIndex(intervals, timer)
    local high, low, i = #intervals - 1, 1, 1

    while low <= high do
        i = math.floor((low + high) / 2)
        if timer >= intervals[i + 1] then
            low = i + 1
        elseif timer < intervals[i] then
            high = i - 1
        else
            return i
        end
    end

    return i
end

---@param dt number time delta
function Animation:update(dt)
    if self.status ~= "playing" then
        return
    end

    self.timer = self.timer + dt
    local loops = math.floor(self.timer / self.totalDuration)
    if loops ~= 0 then
        self.timer = self.timer - self.totalDuration * loops
        local f = type(self.onLoop) == "function" and self.onLoop
            or self[self.onLoop]
        f(self, loops)
    end

    self.position = seekFrameIndex(self.intervals, self.timer)
end

function Animation:pause()
    self.status = "paused"
end

---@param position integer
function Animation:gotoFrame(position)
    self.position = position
    self.timer = self.intervals[self.position]
end

function Animation:pauseAtEnd()
    self.position = #self.frames
    self.timer = self.totalDuration
    self:pause()
end

function Animation:pauseAtStart()
    self.position = 1
    self.timer = 0
    self:pause()
end

function Animation:resume()
    self.status = "playing"
end

---@param image love.Texture|love.Drawable
---@param x number?
---@param y number?
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
function Animation:draw(image, x, y, r, sx, sy, ox, oy, kx, ky)
    love.graphics.draw(
        image,
        self:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky)
    )
end

---@param x number?
---@param y number?
---@param r number?
---@param sx number?
---@param sy number?
---@param ox number?
---@param oy number?
---@param kx number?
---@param ky number?
---@return love.Quad, number?, number?, number?, number?, number?, number?, number?, number?, number?
function Animation:getFrameInfo(x, y, r, sx, sy, ox, oy, kx, ky)
    local frame = self.frames[self.position]
    if self.flippedH or self.flippedV then
        r, sx, sy, ox, oy, kx, ky =
            r or 0, sx or 1, sy or 1, ox or 0, oy or 0, kx or 0, ky or 0
        local _, _, w, h = frame:getViewport()

        if self.flippedH then
            sx = sx * -1
            ox = w - ox
            kx = kx * -1
            ky = ky * -1
        end

        if self.flippedV then
            sy = sy * -1
            oy = h - oy
            kx = kx * -1
            ky = ky * -1
        end
    end
    return frame, x, y, r, sx, sy, ox, oy, kx, ky
end

---@return number, number
function Animation:getDimensions()
    local _, _, w, h = self.frames[self.position]:getViewport()
    return w, h
end

-----------------------------------------------------------

anim8.newGrid = newGrid
anim8.newAnimation = newAnimation

return anim8
