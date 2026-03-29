--------
-- Clouds: spawning dynamically in chunks, moving with the wind and what not. It’s a bit of a mess as I was trying to get it
-- working as fast as possible and produce as little garbage as possible. TODO: move algorithm to C++ side allowing to use 
-- several layers of clouds at once cheaper?
--------

-- Local state (will be updated with values from `conditions_converter.lua`)
local ccClouds = 0
local ccClear = 0
local windDir = vec2(1, 0)
local windSpeed = 0
local windAngle = 0
local dirUp = vec3(0, 1, 0)

-- Different types of clouds
require 'src/weather_clouds_types'

-- Some helper classes
require 'src/weather_clouds_utils'

local CloudsLayer = require 'src/weather_clouds_layer'

-- Creates a new cloud and sets it using `fn`, which would be one of `CloudTypes` functions
---@return ac.SkyCloudV2
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

local layerLow = CloudsLayer({
  cellDistance = 4,
  cellSize = 4000,
  heightMin = 1000,
  heightMax = 1500,
  cloudsPerCell = 20,
  sortOffset = -1e5,
  horizonFix = 0.8,
  castShadow = true,
  lightPollution = true,
  cloudFactory = function (pos)
    return createCloud(CloudTypes.Dynamic, pos, 0.4)
  end,
  flatCloudFactory = function (c)
    return createCloud(CloudTypes.Bottom, c)
  end,
})
 
local layerHigh = CloudsLayer({
  cellDistance = 2,
  cellSize = 15000,
  heightMin = 4000,
  heightMax = 6000,
  cloudsPerCell = 10,
  sortOffset = 0,
  horizonFix = 0,
  castShadow = false,
  lightPollution = false,
  cloudFactory = function (pos)
    return createCloud(CloudTypes.Dynamic, pos, 2)
  end,
  flatCloudFactory = function (c)
    return createCloud(CloudTypes.Bottom, c)
  end,
})
 
local layerSpread = CloudsLayer({
  cellDistance = 2,
  cellSize = 24000,
  heightMin = 8000,
  heightMax = 12000,
  cloudsPerCell = 1,
  sortOffset = 1e5,
  horizonFix = 0,
  castShadow = false,
  lightPollution = false,
  cloudFactory = function (pos)
    if math.random() > -0.75 then
      return createCloud(CloudTypes.Spread, pos, 4)
    else
      return createCloud(CloudTypes.Hovering, pos, 2)
    end
  end,
})

local cloudsCameraPos = vec3()
local windDir1 = vec2()
local windDir2 = vec2()

local function setRotated(out, input, angle) 
  local sin, cos = math.sin(angle), math.cos(angle)
  out.x, out.y = input.x * cos - input.y * sin, input.x * sin + input.y * cos
  return out;
end

local function updateCloudCells(dt)
  local cameraPos = cloudsCameraPos:set(Sim.cameraPosition)
  ac.fixHeadingInvSelf(cameraPos)

  local lowMult = ac.getAltitude()
  lowMult = math.lerpInvSat(lowMult, 1e3, 500)

  local noise0 = math.simplex(Sim.timestamp / 1.071e5, 2) * 100
  local noise1 = math.simplex(Sim.timestamp / 1.072e5, 2) * 100
  local noise2 = math.simplex(Sim.timestamp / 1.073e5, 2) * 2
  local noise3 = math.simplex(Sim.timestamp / 1.074e5, 2) * 2
  layerLow:update(cameraPos, windDir, windSpeed, ccClouds * lowMult * ccClear, ccClear, dt)
  layerHigh:update(cameraPos, setRotated(windDir1, windDir, noise2), windSpeed + noise0, ccClouds, ccClear, dt)
  layerSpread:update(cameraPos, setRotated(windDir2, windDir, noise3), windSpeed + noise1, ccClouds, ccClear, dt)
end

-- Static clouds
local staticClouds = {}
local staticCloudsCount = 0
local function addStaticCloud(cloud)
  staticCloudsCount = staticCloudsCount + 1
  staticClouds[staticCloudsCount] = cloud
  ac.weatherClouds[#ac.weatherClouds + 1] = cloud
end
local function updateStaticClouds(dt)
  local windK = math.saturateN(windSpeed / 100)
  local intensity = ccClouds * 4 / (1 + 3 * ccClouds)
  local cutoff = 1 - intensity
  local lightPollution = GetRemoteLightPollution()
  local dtLocal = math.min(dt, 0.05)
  local procMapLerp = 0.5 * intensity
  local opacityMult = CloudsMult * math.max(0, ccClear * 4 - 3)
  for i = 1, staticCloudsCount do
    local c = staticClouds[i]
    local withWind = windDir.x * c.side.x + windDir.y * c.side.z
    local dtS = 0.005 * dtLocal * (i % 2 == 0 and 1 or -1)
    c.noiseOffset.x = c.noiseOffset.x + (0.2 + windK) * dtS * withWind
    c.procShapeShifting = c.procShapeShifting + (1 + windK * (1 - withWind)) * dtS
    c.extraDownlit:set(lightPollution)
    c.extras.randomOffset = c.extras.randomOffset + dt * 0.1
    c.cutoff = cutoff + math.simplex(c.extras.randomOffset * 0.1 + i * 0.68541, 2) * 0.6
    c.opacity = c.extras.opacity * opacityMult
    c.procMap.y = math.lerp(c.extras.procMap.y, c.extras.procMap.x, procMapLerp)
    -- c.color.g = 0
  end
end
for j = 1, 35 do
  local angle = math.pi * 2 * (j + math.random()) / 35
  local lowRow = vec2(math.sin(angle), math.cos(angle))
  local count = 2
  for i = 1, count do
    addStaticCloud(createCloud(CloudTypes.Low, lowRow, 1 - (i - 1) / (count - 1)))
    lowRow = (lowRow + math.randomVec2():normalize() * 0.2):normalize()
  end
end

function UpdateClouds(dt)
  windDir = CurrentConditions.windDir
  windSpeed = CurrentConditions.windSpeed * 4 -- clouds move faster up there
    + math.perlin(Sim.timestamp / 1.03e5, 3) * 20 -- and a bit of randomization to keep the clouds moving
  windAngle = math.atan2(windDir.y, -windDir.x) * 180 / math.pi
  ccClouds = math.lerp(Sim.weatherConditions.humidity * 0.02, 1, CurrentConditions.clouds * CloudsMult)
  ccClear = (0.75 + 0.25 * CurrentConditions.clear) * math.min(1, (1 - CurrentConditions.fog) * 4)

  updateCloudCells(dt)
  updateStaticClouds(dt)
  ac.sortClouds()
  ac.invalidateCloudMaps()
end
