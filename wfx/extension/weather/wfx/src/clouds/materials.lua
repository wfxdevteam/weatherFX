local T = require 'src/sky/transmittance'
local state = require 'src/state'

local _skyColor = rgb()
local _sunColor = rgb()
local _up = vec3(0, 1, 0)

local function createMaterial(props)
  local m = ac.SkyCloudMaterial()
  m.baseColor = rgb(0.15, 0.15, 0.15)
  m.useSceneAmbient = false
  m.ambientConcentration = 0.35
  m.frontlitMultiplier = 1
  m.frontlitDiffuseConcentration = 0.45
  m.backlitMultiplier = 0
  m.backlitExponent = 30
  m.backlitOpacityMultiplier = 0.6
  m.backlitOpacityExponent = 1.7
  m.specularPower = 1
  m.specularExponent = 5
  m.alphaSmoothTransition = 1
  m.normalFacingExponent = 2
  m.fogMultiplier = 1
  if props then
    for k, v in pairs(props) do
      m[k] = v
    end
  end
  return m
end

local M = {}

M.main = createMaterial({
  contourExponent = 2,
  contourIntensity = 0.2,
  ambientConcentration = 0.1,
  frontlitDiffuseConcentration = 0.8,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0.5,
  backlitOpacityExponent = 1,
  backlitExponent = 20,
  specularExponent = 2,
  receiveShadowsOpacity = 0.9,
})
M.bottom = createMaterial({
  contourExponent = 4,
  contourIntensity = 0.1,
  ambientConcentration = 0.1,
  frontlitDiffuseConcentration = 0.5,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0.8,
  backlitOpacityExponent = 3,
  backlitExponent = 15,
  specularPower = 0,
  specularExponent = 1,
  receiveShadowsOpacity = 0.9,
})
M.hovering = createMaterial({
  frontlitDiffuseConcentration = 0.3,
  ambientConcentration = 0.1,
  backlitMultiplier = 2,
  backlitOpacityMultiplier = 0.8,
  backlitOpacityExponent = 3,
  backlitExponent = 20,
  specularPower = 0,
  specularExponent = 1,
})
M.spread = createMaterial({
  frontlitDiffuseConcentration = 0,
  ambientConcentration = 0,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0,
  backlitOpacityExponent = 1,
  backlitExponent = 20,
  specularPower = 0,
  specularExponent = 1,
})

local _all = { M.main, M.bottom, M.hovering, M.spread }

function M.update(cc)
  local density = cc.cloudsDensity
  local densityMultiplier = 1 - density * 0.8
  local sunsetK = math.lerpInvSat(math.max(0, state.sunDir.y), 0.12, 0)
  local turbidity = T.turbidity(cc)
  local elevationDegree = math.deg(math.asin(math.clamp(state.sunDir.y, -1, 1)))

  ac.calculateSkyColorTo(_skyColor, _up, false, false, false)

  local Tsun = T.compute(elevationDegree, turbidity)
  _sunColor:set(Tsun):scale(cc.clear)

  M.main.ambientColor:set(_skyColor):scale(3 * densityMultiplier)
  M.main.extraDownlit
      :setScaled(_sunColor, 0.03 * math.max(state.sunDir.y, 0) * densityMultiplier)
      :addScaled(state.lightPollutionColor, 0.5 * densityMultiplier)
  M.main.extraDownlit.r = M.main.extraDownlit.r * 0.9
  M.main.extraDownlit.b = M.main.extraDownlit.b * 0.8

  for _, m in ipairs(_all) do
    m.baseColor:set(0.3 * densityMultiplier)
    m.ambientConcentration = math.lerp(0.25, 0.45, density) * (0.5 + 0.5 * cc.clear)
    m.frontlitMultiplier = math.lerp(2.5, 1, sunsetK) * densityMultiplier
    m.frontlitDiffuseConcentration = math.lerp(0.5, 0.75, sunsetK)
    m.backlitMultiplier = 4 * densityMultiplier
    m.backlitExponent = 10
    m.backlitOpacityMultiplier = 0.5
    m.backlitOpacityExponent = 1
    m.specularPower = math.lerp(1, 8, sunsetK)
    m.specularExponent = 4
    m.contourIntensity = 0.2 * densityMultiplier
    m.contourExponent = 1
    m.alphaSmoothTransition = 1
    m.receiveShadowsOpacity = 0.9
  end

  for _, m in ipairs({ M.bottom, M.hovering, M.spread }) do
    m.ambientColor:set(M.main.ambientColor)
    m.extraDownlit:set(M.main.extraDownlit)
  end
  M.bottom.contourExponent = 2

  ac.setCloudsLight(state.sunDir, _sunColor, 6371e3)
  ac.setLightShadowOpacity(math.lerp(0, 0.6 + 0.3 * cc.clouds, cc.clear))
end

return M
