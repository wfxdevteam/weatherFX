OnResolutionChange = {}
require 'src/utils'

-- staying in linear

ac.useLinearColorSpace(true, 100)
ui.setAsynchronousImagesLoading(true)
ac.setAsyncTextureLoading(true)

-- require separate handling
local sim = ac.getSim()
if sim.isShowroomMode or sim.isPreviewsGenerationMode then
  return
end

require 'src/render'
local state = require 'src/state'
local conditions = require 'src/conditions'
local skyParams = require 'src/sky/sky_params'
local lighting = require 'src/sky/lighting'
local ambient = require 'src/sky/ambient'
local fog = require 'src/sky/fog'
local exposure = require 'src/sky/exposure'
local features = require 'src/sky/features'
local shadows = require 'src/sky/shadows'
local tweaks = require 'src/sky/tweaks'
local lightPollution = require 'src/sky/light_pollution'

--
local clouds = require 'src/clouds/manager'
require 'src/clouds/types'


ac.setSkyStarsMap('textures/weather_fx/starmap.dds')
ac.setSkyMoonTexture('textures/weather_fx/moon.dds')
ac.setEarthTexture('textures/weather_fx/earth.dds')
ac.setSkyMoonGradient(0)

-- csp feature flags
ac.setSkyUseV2(true)
ac.setSkyMoonClipThreshold(0.9)
ac.setCloudArcMultiplier(1)
ac.setFogAlgorithm(ac.FogAlgorithm.New)
ac.setMoonEclipse(true)
ac.setSkySunMoonSizeMultiplier(1)
ac.setCloudShadowMaps(true)
ac.setManualCloudsInvalidation(true)
ac.setCloudShadowDistance(8e3)
ac.setCloudShadowScalingFactor(1)
ac.setCloudShadowBlur(0, 0)
ac.useMinDepthResolution(true)

--csp patches
ac.fixSkyColorCalculateResult(true)
ac.fixSkyColorCalculateOrder(true)
ac.fixSkyV2Fog(true)
ac.fixCloudsV2Fog(true)

---
ac.setLambertGamma(1.0 / 2.2)

-- cloud map
local cloudMap = ac.SkyCloudMapParams.new()
cloudMap.perlinFrequency = 4.0
cloudMap.perlinOctaves = 7
cloudMap.worleyFrequency = 3.0
cloudMap.shapeMult = 50.0
cloudMap.shapeExp = 1
cloudMap.shape0Mip = 0.3
cloudMap.shape0Contribution = 0.4
cloudMap.shape1Mip = 1.3
cloudMap.shape1Contribution = 0.7
cloudMap.shape2Mip = 2.3
cloudMap.shape2Contribution = 1.0
ac.generateCloudMap(cloudMap)


--
local lastSunDir = vec3()
local currentSunDir = vec3()
local lastGameTime = 0

local function getCloudsDT(dt)
  local t = ac.getCurrentTime()
  local delta = t - lastGameTime
  lastGameTime = t
  local ratio = math.clamp(math.abs(delta) / math.max(dt, 1e-3) - 150, 1, 200)
  return dt * math.sign(delta) * math.lerp(1, ratio, 0.4)
end

function script.update(dt)
  if not math.isfinite(sim.cameraPosition.x) then
    return
  end

  --smooth ground y
  local groundY = ac.getGroundYApproximation()
  if math.isnan(state.groundY) then
    state.groundY = groundY
  else
    state.groundY = math.applyLag(state.groundY, groundY, 0.995, dt)
  end

  -- jump tracking
  if sim.cameraJumped then
    state.recentlyJumped = 5
  elseif state.recentlyJumped > 0 then
    state.recentlyJumped = state.recentlyJumped - 1
  end

  -- update on sun move or camera jump
  ac.getSunDirectionTo(currentSunDir)
  if math.dot(lastSunDir, currentSunDir) < 0.999995 or sim.cameraJumped then
    state.keepForceUpdates = 1
  end
  if state.keepForceUpdates > 0 then
    lastSunDir:set(currentSunDir)
    state.keepForceUpdates = state.keepForceUpdates - dt
  end

  state.cloudsDT = getCloudsDT(dt)
  conditions.read(dt)

  local cc = conditions.current
  local mix = math.lagMult(0.995, dt)
  if cc.windDir.x == 0 and cc.windDir.y == 0 then
    cc.windDir:set(cc.windDirInstant)
    cc.windSpeed = cc.windSpeedInstant
  else
    cc.windDir:scale(1 - mix):addScaled(cc.windDirInstant, mix)
    cc.windSpeed = math.lerp(cc.windSpeed, cc.windSpeedInstant, mix)
  end

  --#rest


  local altitude = ac.getAltitude()
  skyParams.update(cc, altitude)
  lighting.update(cc)
  ambient.update(cc)
  fog.update(cc)
  exposure.update(lighting.luminance(), ambient.luminance(), dt)
  lightPollution.update()
  features.update(cc)
  shadows.update(cc, lighting.luminance())
  tweaks.update(cc)

  clouds.update(state.cloudsDT)

  --[[
  ac.debug('elevation', altitude)
  ac.debug('cc', cc)
  ac.debug('fog', cc.fog)]]
end

function script.frameBegin(dt)
  --
end

ac.onResolutionChange(function(newSize, makingScreenshot)
  for _, fn in ipairs(OnResolutionChange) do fn() end
  collectgarbage('collect')
end)
