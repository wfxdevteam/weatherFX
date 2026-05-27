local state = require 'src/state'

-- preallocated sample directions and scratch
local _dirs = {
  vec3(0, 1, 0),         -- zenith
  vec3(0.707, 0.5, 0),   -- NE low
  vec3(-0.707, 0.5, 0),  -- NW low
  vec3(0, 0.5, 0.707),   -- N low
  vec3(0, 0.5, -0.707),  -- S low
  vec3(0.5, 0.1, 0.5),   -- NE ground
  vec3(-0.5, 0.1, -0.5), -- SW ground
}
local _weights = { 0.25, 0.10, 0.10, 0.10, 0.10, 0.075, 0.075 }
local _sample = rgb()
local _ambient = rgb()
local _extra = rgb()
local _up = vec3(0, 1, 0)

local _ambientLuminance = 0

local function update(cc)
  _ambient:set(0, 0, 0)

  for i = 1, #_dirs do
    ac.calculateSkyColorTo(_sample, _dirs[i], false, false, false)
    _ambient:addScaled(_sample, _weights[i])
  end

  _ambient:adjustSaturation(cc.saturation):mul(cc.tint)
  ac.setAmbientColor(_ambient)

  _ambientLuminance = _ambient:luminance()

  _extra:set(_ambient):scale(0.3)
  ac.setExtraAmbientColor(_extra)
  ac.setExtraAmbientDirection(_up)

  ac.setWeatherFakeShadowOpacity(1 - state.spaceLook)
  ac.setWeatherFakeShadowConcentration(0)

  ac.adjustTrackVAO(1, 0, 1)
  ac.adjustDynamicAOSamples(1, 0, 1)
end

return {
  update = update,
  luminance = function() return _ambientLuminance end
}
