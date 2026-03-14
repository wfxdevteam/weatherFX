--[[
  context builder
  gathers all sim data and computes shared modifiers (like sun angle, eclipse, altitude)
  once per frame, eliminating need for global vars
]]

local ctx = {
  sunDir = vec3(),
  moonDir = vec3(),
  spaceLook = 0,
  cloudsMult = 0,
  realNightK = 0,
  nightK = 0,
  eclipseK = 0,
  eclipseFullK = 0,
  sunsetK = 0,
  horizonK = 0,
  finalFog = 0,

  -- wind, pollution
  windSpeedSmoothed = -1,
  baseCityPollution = 0,
  totalPollution = 0,

  -- camera occlusion
  cameraOcclusion = 1,

  -- fog range
  fogRangeMult = 1,

  -- track state across frames
  _recentlyJumped = 0
}

local vec3Up = vec3(0, 1, 0)
local Context = {}
Context.ctx = ctx

--[[
builds and returns read-only ctx table for current frame
]]
function Context.build(dt, sim, currentConditions)
  ac.getSunDirectionTo(ctx.sunDir)
  ac.getMoonDirectionTo(ctx.moonDir)


  -- alt modifiers
  ctx.spaceLook = math.saturateN(ac.getAltitude() / 5e4 - 1)
  ctx.cloudsMult = math.saturateN(2 - ac.getAltitude() / 2e3)


  -- base night calc
  ctx.realNightK = math.lerpInvSat(ctx.sunDir.y, 0.05, -0.2)



  -- eclipse
  local sunMoonAngle = ac.getSunMoonAngle()
  ctx.eclipseK = math.lerpInvSat(sunMoonAngle, 0.0077, 0.0005) * (1 - ctx.realNightK)
  ctx.eclipseFullK = math.lerpInvSat(sunMoonAngle, 0.00032, 0.00021) * (1 - ctx.realNightK)



  -- space look overrides for eclipse/night
  if ctx.spaceLook > 0 then
    ctx.realNightK = math.lerp(ctx.realNightK, 0, ctx.spaceLook)
    ctx.eclipseK = math.lerp(ctx.eclipseK, 0, ctx.spaceLook)
    ctx.eclipseFullK = math.lerp(ctx.eclipseFullK, 0, ctx.spaceLook)
  end



  -- lcs fix for night
  ctx.nightK = ctx.realNightK



  -- fog
  ctx.finalFog = math.pow(currentConditions.fog, 1 - 0.5 * ctx.nightK)



  if ctx.eclipseFullK > 0 then
    ctx.nightK = math.lerp(ctx.nightK, 1, ctx.eclipseFullK)
  end



  -- fog range from altitude and earth curvature
  local earthR = 6371e3
  local cameraR = earthR + math.max(1, ac.getAltitude())
  local n = cameraR * cameraR - earthR * earthR
  local x = n / cameraR
  local d = math.sqrt(n - x * x)
  ctx.fogRangeMult = 1 + x / d




  -- sunset/horizon modifiers
  ctx.sunsetK = math.lerpInvSat(math.max(0, ctx.sunDir.y), 0.12, 0)
  ctx.horizonK = math.lerpInvSat(math.abs(ctx.sunDir.y), 0.4, 0.12)
  if ctx.spaceLook > 0 then
    ctx.sunsetK = math.lerp(ctx.sunsetK, 0, ctx.spaceLook)
    ctx.horizonK = math.lerp(ctx.horizonK, 0, ctx.spaceLook)
    ctx.nightK = math.lerp(ctx.nightK, 0, ctx.spaceLook)
    ctx.finalFog = math.lerp(ctx.finalFog, 0, ctx.spaceLook)
  end


  -- wind, pollution
  --[[ RELIES ON GLOBAL LIGHT POLLUTION VAL, UNTIL WE MIGRATE IT OUT OF GLOBALS ]]
  ctx.windSpeedSmoothed =
      ctx.windSpeedSmoothed < 0
      and currentConditions.windSpeed
      or math.applyLag(ctx.windSpeedSmoothed, currentConditions.windSpeed, 0.99, dt)
  ctx.baseCityPollution =
      (LightPollutionValue or 0)
      * (1 - 0.3 * math.min(ctx.windSpeedSmoothed / 10, 1))
      * math.saturateN(0.2 + sim.ambientTemperature / 60)
  ctx.totalPollution = math.lerp(ctx.baseCityPollution * 0.5, 1, currentConditions.pollution)



  -- occlusion tracking
  if sim.cameraJumped then
    ctx._recentlyJumped = 5
  elseif ctx._recentlyJumped > 0 then
    ctx._recentlyJumped = ctx._recentlyJumped - 1
  end
  --[[]]
  local aoNow = math.lerp(ac.getCameraLookOcclusion(), ac.getCameraOcclusion(vec3Up), 0.5)
  ctx.cameraOcclusion =
      math.applyLag(ctx.cameraOcclusion, aoNow, ctx._recentlyJumped > 0 and 0 or 0.95, dt)



  return ctx
end

return Context
