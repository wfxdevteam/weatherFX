local cfg = require 'src/cfg'
local T = require 'src/sky/transmittance'
local state = require 'src/state'

local function update(cc)
  local moonElevationDegree = math.deg(math.asin(math.clamp(state.moonDir.y, -1, 1)))
  local turbidity = T.turbidity(cc)
  local moonPhase = ac.getMoonFraction()
  local skyVisibility = cc.clear * (1 - cc.clouds * 0.8)

  -- moon
  local moonT = T.compute(moonElevationDegree, turbidity)
  -- moon albedo is approximately 0.12
  local moonLuminance = moonT:luminance() * moonPhase * 0.12
  local moonVisible = math.saturateN(state.moonDir.y) * skyVisibility

  -- 50 is completely arbitrary, and should be changed by testing against full moon
  ac.setSkyMoonBrightness(moonLuminance * cfg.sunIlluminanceScale * 50 * moonVisible)
  ac.setSkyMoonOpacity(math.lerp(0.1, 1, state.nightK) * skyVisibility)
  ac.setSkyMoonBaseColor(rgb(1, 1.2, 1.8))
  ac.setSkyMoonMieMultiplier(0.00003 * (1 - cc.clear) * (1 - state.finalFog))
  ac.setSkyMoonMieExp(120)
  ac.setSkyMoonDepthSkip(true)

  -- stars
  local moonWash = moonPhase * math.saturateN(state.moonDir.y) * 0.5
  local starBrightness = state.nightK * skyVisibility * (1 - state.lightPollutionK * 0.9) * (1 - moonWash)

  ac.setSkyStarsBrightness(starBrightness * 2)
  ac.setSkyStarsColor(rgb(1, 1.2, 1.8))
  ac.setSkyStarsSaturation(0.3 * skyVisibility)
  ac.setSkyStarsExponent(math.lerp(4, 12, state.lightPollutionK))

  ac.setSkyPlanetsBrightness(5)
  ac.setSkyPlanetsOpacity(state.nightK * skyVisibility)
end

return {
  update = update
}
