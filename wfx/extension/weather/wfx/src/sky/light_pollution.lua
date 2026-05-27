local state = require 'src/state'

local _gradient = ac.SkyExtraGradient()
_gradient.isAdditive = true
_gradient.exponent = 0.5
ac.addSkyExtraGradient(_gradient)

local _lpData = ac.getTrackLightPollution()
_lpData.tint:clamp(rgb.colors.black, rgb.colors.white)

local _lpPos = vec3()

local function update()
  local lp = _lpData
  local density = lp.density
  if density == 0 then
    state.lightPollutionK = 0
    state.lightPollutionColor:set(0, 0, 0)
    return
  end

  _lpPos:set(lp.position):sub(ac.getSim().cameraPosition)
  local dist = _lpPos:length()
  local distK = math.saturateN(lp.radius / math.max(dist - lp.radius, 1))

  _gradient.color:set(lp.tint)
      :scale(density ^ 2 * (distK ^ 0.25) * 0.003)
      :pow(2.2)

  local dir = _lpPos:clone():normalize()
  _gradient.sizeFull = -1 + distK * 2
  _gradient.sizeStart = 1 + distK * 2
  _gradient.direction:setLerp(dir, dir + vec3(0, -8, 0), distK)

  state.lightPollutionK = math.saturateN(density * distK)
  state.lightPollutionColor:set(lp.tint):scale(distK * state.nightK * density * 0.003)
end

return {
  update = update
}
