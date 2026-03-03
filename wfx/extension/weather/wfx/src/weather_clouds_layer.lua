local mmax = math.max
local msat = math.sat
local mfloor = math.floor

---@alias CloudCellIndex integer

---@param def CloudsLayerDef
---@param cellIndex CloudCellIndex
local function getCellCenter(def, cellIndex)
  local x = mfloor(cellIndex / 1e5 - 1e4) * def.cellSize
  local y = (math.fmod(cellIndex, 1e5) - 1e4) * def.cellSize
  return x, y
end

---@param def CloudsLayerDef
---@param pos vec3
---@return CloudCellIndex
local function getCellIndex(def, pos)
  return mfloor(1e4 + pos.x / def.cellSize) * 1e5 + mfloor(1e4 + pos.z / def.cellSize)
end

---@param cell CloudCellIndex
---@param x integer
---@param y integer
---@return CloudCellIndex
local function getCellNeighbour(cell, x, y)
  return cell + x + y * 1e5
end

---@class CloudsCell
---@field def CloudsLayerDef
---@field visible boolean
---@field index CloudCellIndex
---@field center vec3
---@field clouds CloudInfo[]
---@field lastActive integer
local CloudsCell_index = {}

local CloudsCell = {}
local CloudsCell_mt = { __index = CloudsCell_index }

---@param def CloudsLayerDef
---@return CloudsCell
function CloudsCell.create(def)
  return setmetatable({
    def = def,
    visible = false,
    index = 0,
    clouds = {},
    lastActive = 0,
    center = vec3(),
  }, CloudsCell_mt)
end

---@param index CloudCellIndex
function CloudsCell_index:assignCellIndex(index)
  self.index = index
  local x, y = getCellCenter(self.def, index)
  self.center:set(x + self.def.cellSize * 0.5, 0, y + self.def.cellSize * 0.5)
  if self.initialized then
    for i = 1, self.def.cloudsPerCell do
      self.clouds[i].pos = self:getPos()
    end
  end
end

function CloudsCell_index:getPos()
  local def = self.def
  return vec3(
    self.center.x + def.cellSize * (math.random() - 0.5),
    def.heightMin + (def.heightMax - def.heightMin) * math.random(),
    self.center.z + def.cellSize * (math.random() - 0.5))
end

---@param e CloudInfo
---@param cond boolean
---@return boolean
local function _addCloudIfVisible(e, cond)
  if cond ~= e.cloudAdded then
    e.cloudAdded = cond
    if cond then
      ac.weatherClouds:push(e.cloud)
    else
      ac.weatherClouds:erase(e.cloud)
      if e.flatCloudAdded then
        e.flatCloudAdded = false
        ac.weatherClouds:erase(e.flatCloud)
      end
    end
  end
  return cond
end

---@param e CloudInfo
---@param cond boolean
---@param def CloudsLayerDef
---@return boolean
local function _addFlatCloudIfVisible(e, cond, def)
  if cond ~= e.flatCloudAdded then
    e.flatCloudAdded = cond
    if cond then
      if e.flatCloud == nil then
        e.flatCloud = def.flatCloudFactory(e.cloud)
      end
      ac.weatherClouds:push(e.flatCloud)
    else
      ac.weatherClouds:erase(e.flatCloud)
    end
  end
  return cond
end

---@param e CloudInfo
---@param flatCutoff number
---@param ctx CloudsUpdateContext
---@param fullDist number
local function _syncFlatCloud(e, flatCutoff, ctx, fullDist)
  local c, f = e.cloud, e.flatCloud or error()
  f.cutoff = flatCutoff
  f.opacity = c.opacity
  f.shadowOpacity = c.shadowOpacity
  f.position.x, f.position.y, f.position.z = c.position.x, c.position.y, c.position.z
  f.extraDownlit.r, f.extraDownlit.g, f.extraDownlit.b = c.extraDownlit.r, c.extraDownlit.g, c.extraDownlit.b
  f.procMap.x, f.procMap.y = c.procMap.x, c.procMap.y
  local up = ctx.windDir.x * f.up.x + ctx.windDir.y * f.up.z
  local side = ctx.windDir.x * f.side.x + ctx.windDir.y * f.side.z
  local windDeltaC = ctx.windDelta / c.size.x
  f.noiseOffset.x = f.noiseOffset.x - windDeltaC * side
  f.noiseOffset.y = f.noiseOffset.y - windDeltaC * up
  f.procShapeShifting = f.procShapeShifting + (ctx.shapeShiftingDelta + windDeltaC * 0.5) * 0.5
  if not f.passedFrustumTest then
    f.orderBy = fullDist + 10
  end
end

function CloudsCell_index:createClouds()
  self.initialized = true
  local def = self.def
  for _ = 1, def.cloudsPerCell do
    local pos = self:getPos()
    local cloud = def.cloudFactory(pos)
    cloud.shadowOpacity = 0
    self.clouds[_] = {
      cloud = cloud,
      flatCloud = nil,
      cloudAdded = false,
      flatCloudAdded = false,
      pos = pos,
      procMap = cloud.procMap:clone(),
      procScale = cloud.procScale:clone(),
      opacity = cloud.opacity,
    }
  end
end

---@param ctx CloudsUpdateContext
---@param dt number
function CloudsCell_index:updateDynamic(ctx, dt)
  local mxDistSqr = (ctx.cellDistance * self.def.cellSize) ^ 2
  local tr1 = (ctx.cellDistance - 1) * self.def.cellSize
  local tr2 = 1 / self.def.cellSize

  for i = 1, ctx.cloudsCount + 0.999 do
    local e = self.clouds[i]
    local px, pz = e.pos.x - ctx.cameraPos.x, e.pos.z - ctx.cameraPos.z
    local horDistSq = px ^ 2 + pz ^ 2
    if _addCloudIfVisible(e, horDistSq < mxDistSqr) then
      local c = e.cloud
      local horDist = math.sqrt(horDistSq)
      local distK = horDist * self.def.horizonFix
      c.position.x, c.position.z = px, pz

      local baseY = e.pos.y - ctx.cameraPos.y
      local distY = c.size.y / 2
      c.position.y = baseY + math.limit(distY - baseY, self.def.heightMin) * distK

      local fullDist = math.sqrt(horDistSq + c.position.y ^ 2)
      if not c.passedFrustumTest then
        c.orderBy = fullDist + self.def.sortOffset
      end

      local lookingFromBelow = self.def.flatCloudFactory and mmax(0, c.position.y / fullDist) or 0
      local flatSwitch = msat((lookingFromBelow - 0.5) / 0.2)
      local baseOpacity = msat(1 - (horDist - tr1) * tr2) * e.opacity
      local baseCutoff = msat((i - ctx.cloudsCount - 1) * ctx.cloudsFade + 1)

      c.opacity = baseOpacity * msat(fullDist / 200 - 1)
      c.cutoff = mmax(baseCutoff, flatSwitch)

      if self.def.castShadow then
        c.shadowOpacity = baseOpacity
      end
      c.procMap.x, c.procMap.y = 0.25, 0.95
      c.normalYExponent = 1 + lookingFromBelow * 3
      c.topFogBoost = lookingFromBelow
      if self.def.lightPollution then
        SetLightPollution(c)
      end

      local windDeltaC = ctx.windDelta / c.size.x
      local fwd = ctx.windDir.x * px / horDist + ctx.windDir.y * pz / horDist
      local side = ctx.windDir.x * pz / horDist + ctx.windDir.y * -px / horDist
      c.noiseOffset.x = c.noiseOffset.x + windDeltaC * side * c.procScale.x
      c.procShapeShifting = c.procShapeShifting + (ctx.shapeShiftingDelta + windDeltaC * fwd * 0.5) * c.procScale.x

      if _addFlatCloudIfVisible(e, flatSwitch > 0, self.def) then
        _syncFlatCloud(e, mmax(baseCutoff, 1 - flatSwitch), ctx, fullDist)
      end
    end
  end
end

local tmpPos = vec3()

---@param ctx CloudsUpdateContext
---@param frameIndex integer
---@param dt number
function CloudsCell_index:updateCell(ctx, frameIndex, dt)
  if frameIndex % 8 == 0 then
    self.visible = ac.testFrustumIntersection(tmpPos:set(self.center):sub(ctx.cameraPos), self.def.cellSize * 1.7)
  end

  if ctx.cameraMoved or self.visible or frameIndex % 16 == 3 then
    if not self.initialized then
      self:createClouds()
    end
    self:updateDynamic(ctx, dt)
  end
end

---@param c CloudInfo
local function disableCloud(c)
  if c.cloudAdded then
    ac.weatherClouds:erase(c.cloud)
    c.cloudAdded = false
  end
  if c.flatCloudAdded then
    ac.weatherClouds:erase(c.flatCloud)
    c.flatCloudAdded = false
  end
end

function CloudsCell_index:deactivate()
  for i = 1, #self.clouds do
    disableCloud(self.clouds[i])
  end
end

---@class CloudsLayer
---@field def CloudsLayerDef
---@field frameIndex integer
---@field ctx CloudsUpdateContext
---@field windOffset vec2
---@field prevCameraPos vec2
---@field cloudCells { [CloudCellIndex]: CloudsCell }
---@field cloudCellsList CloudsCell[]
---@field cellsPool CloudsCell[]
---@field cellsTotal integer
---@field cellsPoolTotal integer
local CloudsLayer_index = {}

local CloudsLayer = {}
local CloudsLayer_mt = { __index = CloudsLayer_index }

---@param def CloudsLayerDef
---@return CloudsLayer
function CloudsLayer.create(def)
  def.horizonFix = def.horizonFix / (def.cellDistance * def.cellSize)
  return setmetatable({
    def = def,
    frameIndex = 0,
    ctx = { cameraPos = vec3(), windDir = {x = 0, y = 0} },
    prevCameraPos = vec2(1e9),
    windOffset = vec2(),
    cloudCells = {},
    cloudCellsList = {},
    cellsTotal = 0,
    cellsPool = {},
    cellsPoolTotal = 0,
  }, CloudsLayer_mt)
end

---@param cellIndex CloudCellIndex
function CloudsLayer_index:_createCloudCell(cellIndex)
  local c = nil ---@type CloudsCell
  if self.cellsPoolTotal > 0 then
    c = self.cellsPool[self.cellsPoolTotal]
    table.remove(self.cellsPool, self.cellsPoolTotal)
    self.cellsPoolTotal = self.cellsPoolTotal - 1
  else
    c = CloudsCell.create(self.def)
  end
  c:assignCellIndex(cellIndex)
  self.cloudCells[cellIndex] = c
  self.cellsTotal = self.cellsTotal + 1
  self.cloudCellsList[self.cellsTotal] = c
  return c
end

function CloudsLayer_index:update(baseCameraPos, windDir, windSpeed, cloudsCountMult, cloudsDistanceMult, dt)
  local ctx = self.ctx
  local cameraPos = ctx.cameraPos:set(baseCameraPos)

  self.windOffset:addScaled(windDir, windSpeed * dt)
  cameraPos.x = cameraPos.x + self.windOffset.x
  cameraPos.z = cameraPos.z + self.windOffset.y

  local shift = (cameraPos.x - self.prevCameraPos.x) ^ 2 + (cameraPos.z - self.prevCameraPos.y) ^ 2
  local cameraMoved = shift > self.def.cellSize / 100
  if cameraMoved then
    self.prevCameraPos:set(cameraPos.x, cameraPos.z)
  end

  local frameIndex = self.frameIndex + 1
  self.frameIndex = frameIndex >= 4096 and 0 or frameIndex

  local cloudsCount = math.round(self.def.cloudsPerCell * cloudsCountMult, 2)
  if self._applied_cloudsCount ~= cloudsCount then
    self._applied_cloudsCount = cloudsCount
    cameraMoved = true
    local disableFrom = math.ceil(cloudsCount) + 1
    for _, v in ipairs(self.cloudCellsList) do
      if v.initialized then
        for j = disableFrom, self.def.cloudsPerCell do
          disableCloud(v.clouds[j])
        end
      end
    end

    ctx.cloudsCount = cloudsCount
    ctx.cloudsFade = self.def.cloudsPerCell > 2 
      and 1 / math.lerp(self.def.cloudsPerCell / 2, 1, (cloudsCount / self.def.cloudsPerCell) ^ 2)
      or 1
  end

  if cloudsCount > 0 then
    local cellDistance = self.def.cellDistance * cloudsDistanceMult
    local cellI = math.ceil(cellDistance)

    ctx.cameraMoved = cameraMoved
    ctx.cellDistance = cellDistance
    ctx.windDir.x, ctx.windDir.y = windDir.x, windDir.y
    ctx.windSpeed = windSpeed
    ctx.windDelta = windSpeed * dt * CloudShapeMovingSpeed
    ctx.shapeShiftingDelta = dt * CloudShapeShiftingSpeed

    local cellIndex = getCellIndex(self.def, cameraPos)
    for x = -cellI, cellI do
      for y = -cellI, cellI do
        local n = getCellNeighbour(cellIndex, x, y)
        local c = self.cloudCells[n]
        if c == nil then
          c = self:_createCloudCell(n)
        end
        if c then
          c:updateCell(ctx, frameIndex + x, dt)
          c.lastActive = frameIndex
        end
      end
    end
  end

  if self.cellsTotal > 0 then
    local x = frameIndex % 32
    for i = self.cellsTotal - x, 1, -1 do
      local cell = self.cloudCellsList[i]
      if frameIndex - cell.lastActive > 10 then
        assert(self.cloudCells[cell.index] == cell)
        table.remove(self.cloudCellsList, i)
        self.cloudCells[cell.index] = nil
        self.cellsTotal, self.cellsPoolTotal = self.cellsTotal - 1, self.cellsPoolTotal + 1
        self.cellsPool[self.cellsPoolTotal] = cell
        cell:deactivate()
      end
    end
  end
end

return CloudsLayer.create
