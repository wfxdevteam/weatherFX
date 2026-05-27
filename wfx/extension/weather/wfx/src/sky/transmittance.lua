--#region Types

---@class conditions.CurrentState
---@field humidity number|nil
---@field fog number|nil
---@field rain number|nil

--#endregion

local atmos = require 'src/atmosphere'
local _out = rgb()


---Calculates atmospheric turbidity based on current weather conditions.
---@param cc conditions.CurrentState Current weather conditions state.
---@return number @Calculated turbidity coefficient.
local function turbidity(cc)
  return math.lerp(1.5, 4.0, cc.humidity or 0)
      + (cc.fog or 0) ^ 2 * 8.0
      + (cc.rain or 0) * 3.0
end

---Computes transmittance using a plane-parallel atmosphere model (accurate above ~5 degrees elevation).
---@param elevationDegree number Sun's elevation in degrees.
---@param turb number|nil Turbidity coefficient (defaults to 1 if nil).
---@return rgb @Atmospheric transmittance color.
local function compute(elevationDegree, turb)
  local cosZ = math.max(math.sin(math.rad(elevationDegree)), 0.035)
  local airmass = math.min(1.0 / cosZ, 38.0)

  local tauRx = atmos.rayleighBeta.x * atmos.rayleighH * airmass
  local tauRy = atmos.rayleighBeta.y * atmos.rayleighH * airmass
  local tauRz = atmos.rayleighBeta.z * atmos.rayleighH * airmass
  local tauM = (atmos.mieBeta / atmos.mieAlbedo) * (turb or 1) * atmos.mieH * airmass

  _out.r = math.exp(-(tauRx + tauM))
  _out.g = math.exp(-(tauRy + tauM))
  _out.b = math.exp(-(tauRz + tauM))
  return _out
end

return {
  compute = compute,
  turbidity = turbidity,
  atmos = atmos
}
