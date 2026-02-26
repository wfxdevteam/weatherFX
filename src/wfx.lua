-- change the name of this file to the name of the weatherfx we decide on
-- change the name of the buffer table to the name of the weatherfx we decide on

[[
local wfx = {
  -- store data for current frame
  state = {
    light = {
      color = rgb(0,0,0),
      direction = vec3(0,1,0),
      specularColor = rgb(0,0,0),
      specularMult = 1.0
    },
    ambient = {
      color = rgb(1, 1, 1),
      extraColor = rgb(0, 0, 0),
      extraDirection = vec3(0, 1, 0)
    },
    fog = {
      color = rgb(.5,.5,.5),
      density = 0.0,
      falloff = 0.0,
      distance = 0.0,
      blend = 0.0,
      sunScattering = 0.0
    }
  }
}

function wfx.applyStateToEngine()
  local s = wfx.state

  --- light
  ac.setLightDirection(s.light.direction)
  ac.setLightColor(s.light.color)
  ac.setSpecularColor(s.light.specularColor)
  ac.setSunSpecularMultiplier(s.light.specularMult)

  --- ambient
  ac.setAmbientColor(s.ambient.color)
  ac.setExtraAmbientColor(s.ambient.extraColor)
  ac.setExtraAmbientDirection(s.ambient.extraDirection)

  --- fog
  ac.setFogColor(s.fog.color)
  ac.setFogDistance(s.fog.distance)
  ac.setFogBlend(s.fog.blend)
end

return wfx -- or name of wfx
]]