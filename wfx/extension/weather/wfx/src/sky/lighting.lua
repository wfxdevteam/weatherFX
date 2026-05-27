local cfg = require 'src/cfg'
local T = require 'src/sky/transmittance'
local atmos = T.atmos
local _light = rgb()
local _sunLuminance = 0

local state = require 'src/state'

local GodraysColor = rgb()

local function update(cc)
  ac.getSunDirectionTo(state.sunDir)
  ac.getMoonDirectionTo(state.moonDir)

  local elevationDegree = math.deg(math.asin(math.clamp(state.sunDir.y, -1.0, 1.0)))
  local turbidity = T.turbidity(cc)

  state.nightK = math.lerpInvSat(state.sunDir.y, 0.05, -0.2)
  state.spaceLook = math.saturateN(ac.getAltitude() / 5e4 - 1)
  state.cloudsMult = math.saturateN(2 - ac.getAltitude() / 2e3)
  state.finalFog = math.pow(cc.fog, 1 - 0.5 * state.nightK)

  local Tsun = T.compute(elevationDegree, turbidity)
  local fade = math.lerpInvSat(elevationDegree, 1.0, -1.0)
  local scale = cfg.sunIlluminanceScale * (1 - fade)

  _light.r = atmos.solarIrradiance.r * Tsun.r * scale
  _light.g = atmos.solarIrradiance.g * Tsun.g * scale
  _light.b = atmos.solarIrradiance.b * Tsun.b * scale
  _light:mul(cc.tint)

  _sunLuminance = _light:luminance()

  local skyDom = math.lerpInvSat(_sunLuminance, 0.5, 0.0)
  ac.setLambertGamma(math.lerp(cfg.lambertNight, cfg.lambertDay, (1 - skyDom) ^ 0.5))

  ac.setLightDirection(state.sunDir)
  ac.setLightColor(_light)
  ac.setSpecularColor(_light)
  ac.setSunSpecularMultiplier(cc.clear ^ 2)

  -- fix godrays later
  GodraysColor:set(_light):scale(math.lerpInvSat(state.sunDir.y, 0.01, 0.02))
  ac.setGodraysCustomColor(rgb())
  ac.setGodraysCustomDirection(state.sunDir)
end

return {
  update = update,
  luminance = function() return _sunLuminance end
}
