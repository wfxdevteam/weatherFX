local cfg = require 'src/cfg'
local state = require 'src/state'

local _brightnessMultiplier = 1.0
local _cameraOcclusion = 1.0
local _up = vec3(0, 1, 0)

local function update(sunLuminance, ambientLuminance, dt)
  local aoNow = math.lerp(ac.getCameraLookOcclusion(), ac.getCameraOcclusion(_up), 0.5)
  _cameraOcclusion = math.applyLag(_cameraOcclusion, aoNow, state.recentlyJumped > 0 and 0 or 0.95, dt)

  local env = ambientLuminance * 3 + sunLuminance * math.saturate(state.sunDir.y * 20)
  local local_ = math.sqrt((env * _cameraOcclusion ^ 2) ^ 2 + 1)
  local target = 50 / local_

  _brightnessMultiplier = state.recentlyJumped > 0
      and target
      or math.applyLag(_brightnessMultiplier, target, 0.98, dt)

  local bm = cfg.sceneScale * _brightnessMultiplier
  ac.setBrightnessMult(bm)
  ac.setOverallSkyBrightnessMult(1)
  ac.setHDRToLDRConversionHints(1 / (_brightnessMultiplier * cfg.sceneScale), 0.4545)
  ac.setWhiteReferencePoint(0.4 / _brightnessMultiplier)

  -- lights
  local v1 = 0.001 + 0.999 * math.lerpInvSat(_brightnessMultiplier, 2, 5)
  ac.setWeatherLightsMultiplier(v1 ^ (1 / 2.2))
  ac.setWeatherLightsMultiplier2(0.004 / v1 * bm)
  ac.setWeatherLightsRangeFactor(1)
  ac.setWeatherTrackLightsMultiplierThreshold(0.01)
  ac.setBaseAmbientColor(rgb.tmp():set(0.00002))
  ac.setEmissiveMultiplier(0.07)
  ac.setTrueEmissiveMultiplier(3)
  ac.setGlowBrightness(1)
end

return {
  update = update
}
