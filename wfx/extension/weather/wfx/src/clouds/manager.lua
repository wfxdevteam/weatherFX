local materials = require 'src/clouds/materials'
local state = require 'src/state'
local conditions = require 'src/conditions'
require 'src/clouds/types'

CloudMaterials = {
  Main = materials.main,
  Bottom = materials.bottom,
  Hovering = materials.hovering,
  Spread = materials.spread,
}
CloudUseAtlas = true
CloudSpawnScale = 0.5
DynCloudsMinHeight = 400
DynCloudsMaxHeight = 1200
HoveringMinHeight = 1200
HoveringMaxHeight = 1600
CloudShapeShiftingSpeed = 0.005
CloudShapeMovingSpeed = 0.5

-- called by layer for clouds with light pollution
function SetLightPollution(cloud)
  if state.nightK > 0 then
    cloud.extraDownlit:set(state.lightPollutionColor):scale(0.25)
  else
    cloud.extraDownlit:set(0, 0, 0)
  end
end

local cloudsLayer = require 'src/clouds/layer'
local dirUp = vec3(0, 1, 0)

local function createCloud(fn, arg1, arg2)
  local shift = math.random() * 0.1
  local cloud = ac.SkyCloudV2()
  cloud.color:set(1, 1, 1)
  cloud.procMap:set(0.6 + shift, 0.65 + shift + math.random() * 0.05)
  cloud.procNormalScale:set(0.9, 0.3)
  cloud.procShapeShifting = math.random()
  cloud.opacity = 0.9
  cloud.shadowOpacity = 1.0
  cloud.cutoff = 0
  cloud.occludeGodrays = false
  cloud.useNoise = true
  cloud.material = CloudMaterials.Main
  cloud.noiseOffset:set(math.random(), math.random())
  fn(cloud, arg1, arg2)
  cloud.side:setCrossNormalized(dirUp, cloud.position)
  cloud.up:setCrossNormalized(cloud.position, cloud.side)
  return cloud
end

local layerLow = cloudsLayer({
  cellDistance = 4,
  cellSize = 4000,
  heightMin = 1000,
  heightMax = 1500,
  cloudsPerCell = 20,
  sortOffset = -1e5,
  horizonFix = 0.8,
  castShadow = true,
  lightPollution = true,
  cloudFactory = function(pos) return createCloud(CloudTypes.Dynamic, pos, 0.4) end,
  flatCloudFactory = function(c) return createCloud(CloudTypes.Bottom, c) end,
})

local layerHigh = cloudsLayer({
  cellDistance = 2,
  cellSize = 15000,
  heightMin = 4000,
  heightMax = 6000,
  cloudsPerCell = 10,
  sortOffset = 0,
  horizonFix = 0,
  castShadow = false,
  lightPollution = false,
  cloudFactory = function(pos) return createCloud(CloudTypes.Dynamic, pos, 2) end,
  flatCloudFactory = function(c) return createCloud(CloudTypes.Bottom, c) end,
})

local layerSpread = cloudsLayer({
  cellDistance = 2,
  cellSize = 24000,
  heightMin = 8000,
  heightMax = 12000,
  cloudsPerCell = 1,
  sortOffset = 1e5,
  horizonFix = 0,
  castShadow = false,
  lightPollution = false,
  cloudFactory = function(pos)
    if math.random() > 0.75 then
      return createCloud(CloudTypes.Spread, pos, 4)
    else
      return createCloud(CloudTypes.Hovering, pos, 2)
    end
  end,
})

-- static horizon ring
local staticClouds = {}
local function updateStaticClouds(dt, cc)
  local windK = math.saturateN(cc.windSpeed / 100)
  local intensity = cc.clouds * 4 / (1 + 3 * cc.clouds)
  local cutoff = 1 - intensity
  local dtLocal = math.min(dt, 0.05)
  local procMapLerp = 0.5 * intensity
  local opacityMult = state.cloudsMult * math.max(0, cc.clear * 4 - 3)
  for i = 1, #staticClouds do
    local c = staticClouds[i]
    local withWind = cc.windDir.x * c.side.x + cc.windDir.y * c.side.z
    local dtS = 0.005 * dtLocal * (i % 2 == 0 and 1 or -1)
    c.noiseOffset.x = c.noiseOffset.x + (0.2 + windK) * dtS * withWind
    c.procShapeShifting = c.procShapeShifting + (1 + windK * (1 - withWind)) * dtS
    c.extraDownlit:set(state.lightPollutionColor)
    c.extras.randomOffset = c.extras.randomOffset + dt * 0.1
    c.cutoff = cutoff + math.simplex(c.extras.randomOffset * 0.1 + i * 0.68541, 2) * 0.6
    c.opacity = c.extras.opacity * opacityMult
    c.procMap.y = math.lerp(c.extras.procMap.y, c.extras.procMap.x, procMapLerp)
  end
end

for j = 1, 35 do
  local angle  = math.pi * 2 * (j + math.random()) / 35
  local lowRow = vec2(math.sin(angle), math.cos(angle))
  for i = 1, 2 do
    local cloud = createCloud(CloudTypes.Low, lowRow, 1 - (i - 1))
    staticClouds[#staticClouds + 1] = cloud
    ac.weatherClouds[#ac.weatherClouds + 1] = cloud
    lowRow = (lowRow + math.randomVec2():normalize() * 0.2):normalize()
  end
end

local windDir1 = vec2()
local windDir2 = vec2()
local function setRotated(out, input, angle)
  local s, c = math.sin(angle), math.cos(angle)
  out.x, out.y = input.x * c - input.y * s, input.x * s + input.y * c
  return out
end

local camPosition = vec3()
local sim = ac.getSim()

local function update(dt)
  local cc = conditions.current
  camPosition:set(sim.cameraPosition)
  ac.fixHeadingInvSelf(camPosition)

  local windSpeed = cc.windSpeed * 4 + math.perlin(sim.timestamp / 1.03e5, 3) * 20
  local ccClouds = math.lerp(sim.weatherConditions.humidity * 0.02, 1, cc.clouds * state.cloudsMult)
  local ccClear = (0.75 + 0.25 * cc.clear) * math.min(1, (1 - cc.fog) * 4)

  local n0 = math.simplex(sim.timestamp / 1.071e5, 2) * 100
  local n1 = math.simplex(sim.timestamp / 1.072e5, 2) * 100
  local n2 = math.simplex(sim.timestamp / 1.073e5, 2) * 2
  local n3 = math.simplex(sim.timestamp / 1.074e5, 2) * 2

  layerLow:update(camPosition, cc.windDir, windSpeed, ccClouds * ccClear, ccClear, dt)
  layerHigh:update(camPosition, setRotated(windDir1, cc.windDir, n2), windSpeed + n0, ccClouds, ccClear, dt)
  layerSpread:update(camPosition, setRotated(windDir2, cc.windDir, n3), windSpeed + n1, ccClouds, ccClear, dt)

  updateStaticClouds(dt, cc)
  materials.update(cc)
  ac.sortClouds()
  ac.invalidateCloudMaps()
end

return {
  update = update
}
