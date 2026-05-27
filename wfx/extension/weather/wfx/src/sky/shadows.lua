local state = require 'src/state'

local function update(cc, sunLuminance)
  if sunLuminance < 1e-5 then
    ac.setShadows(ac.ShadowsState.Off)
    return
  end

  local fog = state.finalFog
  if fog > 0.96 then
    ac.setShadowsResolution(256)
  elseif fog > 0.88 then
    ac.setShadowsResolution(512)
  elseif fog > 0.80 then
    ac.setShadowsResolution(1024)
  else
    ac.resetShadowsResolution()
  end

  ac.setShadows(ac.ShadowsState.On)
  ac.setLightShadowOpacity(math.lerp(0, 0.9, cc.clear))
end

return {
  update = update
}
