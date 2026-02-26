if not ScriptSettings.EXTRA_EFFECTS.FOG_ABOVE then
  UpdateAboveFog = function(dt) end
  return
end

local intensity = 0
local renderFogParams = {
  blendMode = render.BlendMode.AlphaBlend,
  depthMode = render.DepthMode.ReadOnly,
  depth = 0,
  shader = 'shaders/fog.fx',
  values = {
    gIntensity = intensity,
    gDensity = 0.015,
    gFalloff = 0.02,
    gHeightOffset = 0.0,
    gSunScattering = 8.0,
    gSunDirection = vec3(),
    gSunColor = rgb()
  },
  async = true,
  cacheKey = 2
}

local function renderFog()
  local sim = ac.getSim()
  renderFogParams.values.gIntensity = intensity
  renderFogParams.values.gSunDirection = sim.lightDirection
  renderFogParams.values.gSunColor = sim.lightColor
  renderFogParams.values.gHeightOffset = ac.getGroundYApproximation()
  render.fullscreenPass(renderFogParams)
end

local subscribed ---@type fun()?

function UpdateAboveFog(dt)
  intensity = math.lerpInvSat(FinalFog, 0.8, 1)
  if intensity == 0 then
    if subscribed then
      subscribed()
      subscribed = nil
    end
    return
  end
  if not subscribed then
    subscribed = RenderTrackSubscribe(render.PassID.Main, renderFog)
  end
end
