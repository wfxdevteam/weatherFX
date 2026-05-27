local state = require 'src/state'

local function update(cc)
  local heat = math.lerpInvSat(state.sunDir.y, 0.6, 0.7)
      * math.lerpInvSat(cc.clear, 0.7, 0.9)
      * math.lerpInvSat(cc.clouds, 0.6, 0.3)
      * math.lerpInvSat(cc.windSpeed, 7, 3)
  ac.setTrackHeatFactor(heat)

  local sim = ac.getSim()
  local grassThrive = math.saturateN(sim.ambientTemperature / 20) * (cc.humidity or 0)
  ac.configureGrassShading(
    0.07 * (1 + math.saturateN(1 - state.sunDir.y)),
    0.03 * (1 + math.saturateN(1 - state.sunDir.y)),
    grassThrive * 2,
    0.25 + grassThrive)
end

return {
  update = update
}
