local T = require 'src/sky/transmittance'
local atmos = T.atmos

local function update(cc, cameraAltitude)
  local turbidity = T.turbidity(cc)

  ac.setSkyV2NumMolecules(ac.SkyRegion.All, 2.542e25)
  ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, 1.000293)
  ac.setSkyV2DepolarizationFactor(ac.SkyRegion.All, 0.035)
  ac.setSkyV2Primaries(ac.SkyRegion.All, vec3(6.8e-7, 5.5e-7, 4.5e-7))
  ac.setSkyV2MieKCoefficient(ac.SkyRegion.All, vec3(0.686, 0.678, 0.666))
  ac.setSkyV2MieV(ac.SkyRegion.All, 3.96)

  ac.setSkyV2Rayleigh(ac.SkyRegion.All, 1.0)
  ac.setSkyV2RayleighZenithLength(ac.SkyRegion.All, atmos.rayleighH)

  ac.setSkyV2MieCoefficient(ac.SkyRegion.All, 0.005 * (turbidity / 2.0) * cc.clear)
  ac.setSkyV2MieZenithLength(ac.SkyRegion.All, atmos.mieH)
  ac.setSkyV2MieDirectionalG(ac.SkyRegion.All, atmos.mieG)
  ac.setSkyV2Turbidity(ac.SkyRegion.All, turbidity)

  ac.setSkyV2SunIntensityFactor(ac.SkyRegion.All, 1000.0)
  ac.setSkyV2SunIntensityFalloffSteepness(ac.SkyRegion.All, 1.5)
  ac.setSkyV2SunShapeMult(ac.SkyRegion.All, 3e4 * cc.clear ^ 5)
  ac.setSkyV2SunSaturation(ac.SkyRegion.All, 1.0)
  ac.setSkyV2BackgroundLight(ac.SkyRegion.All, 0.0)
  ac.setSkyV2Luminance(ac.SkyRegion.All, 0.03)
  ac.setSkyV2Saturation(ac.SkyRegion.All, 1.0)
  ac.setSkyV2Gamma(ac.SkyRegion.All, 1.0)
  ac.setSkyBrightnessMult(1)

  -- altitude correction
  local r = atmos.earthRadius + math.max(1, cameraAltitude)
  local n = r * r - atmos.earthRadius * atmos.earthRadius
  local x = n / r
  local scale = math.sqrt(math.max(0, n - x * x)) / (x + math.sqrt(math.max(0, n - x * x)))
  ac.setSkyV2YOffset(ac.SkyRegion.All, 1.0 - scale)
  ac.setSkyV2YScale(ac.SkyRegion.All, scale)
end

return {
  update = update
}
