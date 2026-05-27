local T = require 'src/sky/transmittance'
local state = require 'src/state'

local _fogColor = rgb()
local _horizonDir = vec3()

local function update(cc)
  _horizonDir:set(state.sunDir.x, 0.05, state.sunDir.z):normalize()
  ac.calculateSkyColorTo(_fogColor, _horizonDir, false, false, false)

  local turbidity = T.turbidity(cc)
  local fog = state.finalFog

  local fogDist = math.lerp(28e3, 800, fog) / math.max(turbidity / 2.0, 1.0)

  ac.setFogColor(_fogColor)
  ac.setFogDistance(fogDist)
  ac.setFogExponent(1 - cc.pollution * 0.5)
  ac.setFogBlend(math.lerpInvSat(ac.getAltitude(), 10e3, 5e3))
  ac.setFogAtmosphere(fogDist * (1 - fog * 0.5) / 22.5e3)
  ac.setSkyFogMultiplier(math.min(1, 1.5 * fog / (0.5 + fog)) * 0.8)
  ac.setHorizonFogMultiplier(1, math.lerp(10, 0.5, fog), 1)
  ac.setFogBacklitExponent(12)
  ac.setFogBacklitMultiplier(4 * (1 - cc.clouds))
end

return {
  update = update
}
