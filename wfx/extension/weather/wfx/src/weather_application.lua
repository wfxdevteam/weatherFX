--------
-- Most of weather stuff happens here: it sets lighting, fog, scene brightness and prepares a few globally defined
-- cloud materials.
--------

local Context = require 'src/context'
local ctx = Context.ctx

CloudsLightDirection = vec3()
CloudsLightColor = rgb()

--[[]]
Nova.registerModule('fog', {
  color       = { fn = ac.setFogColor, type = 'rgb' },
  distance    = { fn = ac.setFogDistance, type = 'num' },
  exponent    = { fn = ac.setFogExponent, type = 'num' },
  blend       = { fn = ac.setFogBlend, type = 'num' },
  atmosphere  = { fn = ac.setFogAtmosphere, type = 'num' },
  skyMult     = { fn = ac.setSkyFogMultiplier, type = 'num' },
  backlitExp  = { fn = ac.setFogBacklitExponent, type = 'num' },
  backlitMult = { fn = ac.setFogBacklitMultiplier, type = 'num' }
})
--[[]]

-- Various local variables, changing with each update, something easy to deal with things. There is
-- no need to edit any of those values if you want to change anything, please proceed further to
-- actual functions setting that stuff
local sunsetK = 0  -- grows when sun is at sunset stage
local horizonK = 0 -- grows when sun is near horizon
local eclipseK = 0 -- starts growing when moon touches sun, 1 at total eclipse
local belowHorizonCorrection = 0
local initialSet = 3
local sunColor = rgb(1, 1, 1)
local skyTopColor = rgb(1, 1, 1)
local skySunColor = rgb(1, 1, 1)
local lightDir = vec3(0, 1, 0)
local lightColor = rgb(0, 0, 0)
local realNightK = 0

-- Sky gradient covering everything, for sky-wide color correction
local skyGeneralMult = nil
skyGeneralMult = ac.SkyExtraGradient()
skyGeneralMult.isAdditive = false
skyGeneralMult.sizeFull = 2
skyGeneralMult.sizeStart = 2
skyGeneralMult.direction = vec3(0, 1, 0)
ac.addSkyExtraGradient(skyGeneralMult)

-- Another sky gradient for cloudy and foggy look
local skyCoverAddition = nil
skyCoverAddition = ac.SkyExtraGradient()
skyCoverAddition.isAdditive = true
skyCoverAddition.sizeFull = 2
skyCoverAddition.sizeStart = 2
skyCoverAddition.direction = vec3(0, 1, 0)
ac.addSkyExtraGradient(skyCoverAddition)

-- Gradient to boost brightness towards horizon
local skyHorizonAddition = nil
skyHorizonAddition = ac.SkyExtraGradient()
skyHorizonAddition.isAdditive = true
skyHorizonAddition.sizeFull = 0.8
skyHorizonAddition.sizeStart = 1.2
skyHorizonAddition.direction = vec3(0, -1, 0)
ac.addSkyExtraGradient(skyHorizonAddition)

-- Gradient to darken zenith during solar eclipse
local eclipseCover = ac.SkyExtraGradient()
eclipseCover.isAdditive = false
eclipseCover.sizeFull = 0
eclipseCover.sizeStart = 2
eclipseCover.exponent = 0.1
eclipseCover.direction = vec3(0, 1, 0)
eclipseCover.color = rgb(0, 0, 0)

-- Custom post-processing brightness adjustment
local ppBrightnessCorrection = ac.ColorCorrectionBrightness()
ac.addWeatherColorCorrection(ppBrightnessCorrection)

-- A bit of optimization to reduce garbage generated per frame
local vec3Up = vec3(0, 1, 0)

-- Cheap thunder effect
local thunderActiveFor = 0
local thunderFlashAdded = false
local thunderFlash = ac.SkyExtraGradient()
thunderFlash.direction = vec3(0, 1, 0)
thunderFlash.sizeFull = 0
thunderFlash.sizeStart = 1
thunderFlash.exponent = 1
thunderFlash.isIncludedInCalculate = false

-- Strong wind blows estimated city pollution away (estimation is done based on light pollution, specific weather
-- types can boost pollution further)
local windSpeedSmoothed = -1
local baseCityPollution = 0
local prevEclipseK = -1

-- Updates sky color
function ApplySky(dt)
  ac.getSunDirectionTo(SunDir)
  ac.getMoonDirectionTo(MoonDir)

  windSpeedSmoothed = windSpeedSmoothed < 0 and CurrentConditions.windSpeed or
      math.applyLag(windSpeedSmoothed, CurrentConditions.windSpeed, 0.99, dt)
  baseCityPollution = LightPollutionValue * (1 - 0.3 * math.min(windSpeedSmoothed / 10, 1)) *
      math.saturateN(0.2 + ac.getSim().ambientTemperature / 60)

  SpaceLook = math.saturateN(ac.getAltitude() / 5e4 - 1)
  CloudsMult = math.saturateN(2 - ac.getAltitude() / 2e3)
  realNightK = math.lerpInvSat(SunDir.y, 0.05, -0.2)

  -- Eclipse coefficients. Full eclipse happens on Brasov track on 08/11/1999:
  -- https://www.racedepartment.com/downloads/brasov-romania.28239/
  local sunMoonAngle = ac.getSunMoonAngle()
  local hadAnyFullEclipse = EclipseFullK > 0
  eclipseK = math.lerpInvSat(sunMoonAngle, 0.0077, 0.0005) * (1 - realNightK)
  EclipseFullK = math.lerpInvSat(sunMoonAngle, 0.00032, 0.00021) * (1 - realNightK)
  if hadAnyFullEclipse ~= (EclipseFullK > 0) then
    if hadAnyFullEclipse then
      ForceRapidUpdates = ForceRapidUpdates - 1
    else
      ForceRapidUpdates = ForceRapidUpdates + 1
    end
    UpdateEclipseGlare(EclipseFullK > 0)
  end

  if SpaceLook > 0 then
    realNightK = math.lerp(realNightK, 0, SpaceLook)
    eclipseK = math.lerp(eclipseK, 0, SpaceLook)
    EclipseFullK = math.lerp(EclipseFullK, 0, SpaceLook)
  end

  NightK = realNightK
  FinalFog = math.pow(CurrentConditions.fog, 1 - 0.5 * NightK)

  sunsetK = math.lerpInvSat(math.max(0, SunDir.y), 0.12, 0)
  horizonK = math.lerpInvSat(math.abs(SunDir.y), 0.4, 0.12)

  if EclipseFullK > 0 then
    NightK = math.lerp(NightK, 1, EclipseFullK)
  end

  if SpaceLook > 0 then
    sunsetK = math.lerp(sunsetK, 0, SpaceLook)
    horizonK = math.lerp(horizonK, 0, SpaceLook)
    NightK = math.lerp(NightK, 0, SpaceLook)
    FinalFog = math.lerp(FinalFog, 0, SpaceLook)
  end

  -- Generally the same:
  ac.setSkyV2MieKCoefficient(ac.SkyRegion.All, vec3(0.686, 0.678, 0.666))
  ac.setSkyV2NumMolecules(ac.SkyRegion.All, 2.542e25)
  ac.setSkyV2MieDirectionalG(ac.SkyRegion.All, 0.8)
  ac.setSkyV2DepolarizationFactor(ac.SkyRegion.All, 0.035)
  ac.setSkyV2MieV(ac.SkyRegion.All, 3.96)
  ac.setSkyV2MieZenithLength(ac.SkyRegion.All, 1.25e3)
  ac.setSkyV2SunIntensityFactor(ac.SkyRegion.All, 1000.0)
  ac.setSkyV2SunIntensityFalloffSteepness(ac.SkyRegion.All, 1.5)

  -- Few sky adjustments
  local purpleAdjustment = sunsetK -- slightly alter color for sunsets
  local skyVisibility = (1 - FinalFog) * CurrentConditions.clear

  -- Brightness adjustments:
  local refractiveIndex = math.lerp(1.000317, 1.00029, NightK) +
      0.0001 *
      purpleAdjustment -- TODO: Tie to pollution, make purple value dynamic
  ac.setSkyV2Primaries(ac.SkyRegion.All, vec3(6.8e-7, 5.5e-7, 4.5e-7))
  ac.setSkyV2Turbidity(ac.SkyRegion.All, 1.25 + sunsetK * (1 - NightK) * 3.45)
  ac.setSkyV2Rayleigh(ac.SkyRegion.Sun, 1 + sunsetK * 0.28)
  ac.setSkyV2RayleighZenithLength(ac.SkyRegion.All,
    (8400 - 6000 * sunsetK) * (1 - 0.5 * NightK) + baseCityPollution * math.lerp(8000, 4000, horizonK))

  ac.setSkyV2Luminance(ac.SkyRegion.All, 0.03)
  ac.setSkyV2Gamma(ac.SkyRegion.All, 1)

  ac.setSkyV2BackgroundLight(ac.SkyRegion.All, 0) -- what does this thing do?
  ac.setSkyV2SunShapeMult(ac.SkyRegion.All,
    3e4 * ((CurrentConditions.clear * (1 - FinalFog)) ^ 5) * (1 - EclipseFullK) ^ 8)
  ac.setSkyV2SunSaturation(ac.SkyRegion.All, 1)
  -- ac.setSkyV2Saturation(ac.SkyRegion.All, 1.2 - Sim.weatherConditions.humidity * 0.4)
  ac.setSkyV2Saturation(ac.SkyRegion.All, 1)

  local mieC = math.lerp(0.0065, 0.0045, sunsetK) * (1 - EclipseFullK) * CurrentConditions.clear
  refractiveIndex = refractiveIndex * math.lerp(0.99997, 1.00003, Sim.weatherConditions.humidity)
  if SpaceLook > 0 then
    refractiveIndex = math.lerp(refractiveIndex, 1, SpaceLook)
    mieC = math.lerp(mieC, 0, SpaceLook)
  end

  ac.setSkyV2RefractiveIndex(ac.SkyRegion.All, refractiveIndex)
  ac.setSkyV2MieCoefficient(ac.SkyRegion.All, mieC)

  -- Shifting sky using Earth radius and current altitude
  local earthR = 6371e3
  local cameraR = earthR + math.max(1, ac.getAltitude())
  local n = cameraR * cameraR - earthR * earthR
  local x = n / cameraR
  local d = math.sqrt(n - x * x)
  local fogRangeMult = 1 + x / d
  local shiftScale = 1 / fogRangeMult
  ac.setSkyV2YOffset(ac.SkyRegion.All, 1 - shiftScale)
  ac.setSkyV2YScale(ac.SkyRegion.All, shiftScale)


  ac.setSkyBrightnessMult(1)

  -- Boosting deep blue at nights
  local deepBlue = NightK ^ 2
  skyGeneralMult.color
      :set(math.lerp(1, 0.2, deepBlue), math.lerp(1, 0.8, math.max(horizonK * 0.5, deepBlue)),
        math.lerp(1, 1.6, deepBlue))
      :mul(CurrentConditions.tint)
      :scale(skyVisibility
        * (1 - math.smoothstep(realNightK) * 0.999))

  -- Covering layer
  ac.calculateSkyColorNoGradientsTo(skyTopColor, vec3Up, false, false, false)
  skyCoverAddition.color
      :set(math.lerp(1, 0.2, deepBlue), math.lerp(1, 0.8, deepBlue) * 1.1, math.lerp(1, 2, deepBlue) * 1.2)
      :scale((1 - NightK * 0.99) * (1 - CurrentConditions.cloudsDensity * 0.5))
      :mul(CurrentConditions.tint)
  skyHorizonAddition.exponent = 2
  skyCoverAddition.color:pow(2.2):scale(skyTopColor.b * 0.3 --[[ actually defines how dark nonclear weathers are ]] *
    (1 - skyVisibility))
  skyHorizonAddition.color:set(skyCoverAddition.color)
  skyHorizonAddition.direction.x = SunDir.x * 0.2
  skyHorizonAddition.direction.z = SunDir.z * 0.2

  if prevEclipseK ~= eclipseK then
    if (prevEclipseK > 0) ~= (eclipseK > 0) then
      if eclipseK > 0 then
        ac.addSkyExtraGradient(eclipseCover)
      else
        ac.skyExtraGradients:erase(eclipseCover)
      end
    end
    eclipseCover.color:set(1 - eclipseK * 0.9 - EclipseFullK * 0.1)
    eclipseCover.direction:set(SunDir)
    prevEclipseK = eclipseK
  end

  local rainbowIntensity = Overrides.rainbowIntensity or
      math.saturateN(CurrentConditions.rain * 50) * CurrentConditions.clear * math.lerpInvSat(SunDir.y, 0.02, 0.06)
  ac.setSkyV2Rainbow(rainbowIntensity)
  ac.setSkyV2RainbowSecondary(0.2 * rainbowIntensity)
  ac.setSkyV2RainbowDarkening(math.lerp(1, 0.4, rainbowIntensity))

  -- Getting a few colors from sky
  ac.calculateSkyColorTo(skyTopColor, vec3Up, false, false, false)
  ac.calculateSkyColorTo(skySunColor, vec3(SunDir.x, math.max(SunDir.y, 0.0), SunDir.z), false, false, true)

  -- Small adjustment for balancing
  skySunColor:scale(0.5)
  skyTopColor:scale(0.5)

  if SpaceLook > 0 then
    ac.setSkyV2Rainbow(rainbowIntensity * (1 - SpaceLook))
    skySunColor:setLerp(skySunColor, rgb.colors.white, SpaceLook)
    skyTopColor:setLerp(skyTopColor, rgb.colors.black, SpaceLook)
  end
end

---@param color rgb
function ApplyExtraVibe(color)
  local sunsetBlue = math.sin(ctx.nightK * math.pi)
  local intensity = 0.05 + 0.95 * CurrentConditions.clear
  color.r = color.r * (1 + (ctx.horizonK * 2 - sunsetBlue) * intensity)
  color.b = color.b * (1 + (ctx.sunsetK * 0.5 + sunsetBlue * 2) * intensity)
  color:normalize()
end

-- Updates main scene light: could be either sun or moon light, dims down with eclipses
local moonAbsorption = rgb()
local cloudLightColor = rgb()

function ApplyLight()
  local eclipseLightMult = (1 - ctx.eclipseK * 0.98) -- up to 80% general occlusion
      * (1 - ctx.eclipseFullK * 1)                   -- up to 98% occlusion for real full eclipse

  -- Calculating sun color based on sky absorption (boosted at horizon)
  ac.getSkyAbsorptionTo(sunColor, SunDir)
  sunColor:scale(SunIntensity * eclipseLightMult)

  -- Initially, it starts as a sun light
  lightColor:set(sunColor)

  -- If it’s deep night and moon is high enough, change it to moon light
  ac.getSkyAbsorptionTo(moonAbsorption, MoonDir)
  local sunThreshold = math.lerpInvSat(ctx.realNightK, 0.7, 0.5)
  local moonThreshold = math.lerpInvSat(ctx.realNightK, 0.7, 0.95)
  local moonLight = moonThreshold * math.lerpInvSat(MoonDir.y, 0, 0.12) * (1 - ctx.spaceLook)

  -- Calculate light direction, similar rules
  if moonLight > 0 then
    local moonPartialEclipseK = math.lerpInvSat(math.dot(SunDir, MoonDir), -0.99964, -0.99984)
    local moonEclipseK = math.lerpInvSat(math.dot(SunDir, MoonDir), -0.99996, -0.99985)
    local finalMoonEclipseMult = moonEclipseK * (0.8 + 0.2 * moonPartialEclipseK)
    finalMoonEclipseMult = finalMoonEclipseMult ^ 2
    moonLight = moonLight * finalMoonEclipseMult

    lightDir:set(MoonDir)
    lightColor:set(moonAbsorption):mul(MoonColor)
        :scale(MoonLightMult * LightPollutionSkyFeaturesMult * ac.getMoonFraction() * moonLight * CurrentConditions
          .clear)
  else
    lightDir:set(SunDir)
  end

  -- Adjust light color
  lightColor:scale(CurrentConditions.clear ^ 2)
      :adjustSaturation(CurrentConditions.saturation * (1.1 - Sim.weatherConditions.humidity * 0.2))

  -- Clouds have their own lighting, so sun would work even if it’s below the horizon
  local cloudSunLight = math.lerpInvSat(SunDir.y, -0.23, -0.115)
  cloudLightColor:set(sunColor):scale(cloudSunLight * sunThreshold)
  cloudLightColor:setLerp(cloudLightColor, lightColor, moonLight)
  cloudLightColor:scale(CurrentConditions.clear)
  cloudLightColor:adjustSaturation(CurrentConditions.saturation)
  cloudLightColor:mul(CurrentConditions.tint)
  ac.setCloudsLight(lightDir, cloudLightColor, 6371e3 / 20)

  -- Dim light if light source is very low
  lightColor:scale(math.lerpInvSat(lightDir.y, -0.03, 0) * SunLightIntensity)

  -- Dim godrays even more
  GodraysColor:set(lightColor):scale(math.lerpInvSat(lightDir.y, 0.01, 0.02) * (1 - ctx.finalFog ^ 2))

  if ctx.spaceLook > 0 then
    GodraysColor:scale(1 - ctx.spaceLook)
  end

  -- And godrays!
  if SunRaysCustom then
    ac.setGodraysCustomColor(GodraysColor)
    ac.setGodraysCustomDirection(lightDir)
    ac.setGodraysLength(0.3)
    ac.setGodraysGlareRatio(0)
    ac.setGodraysAngleAttenuation(1)
  else
    ac.setGodraysCustomColor(GodraysColor:scale(SunRaysIntensity))
    ac.setGodraysCustomDirection(lightDir)
  end

  -- Adjust light dir for case where sun is below horizon, but a bit is still visible
  belowHorizonCorrection = math.lerpInvSat(lightDir.y, 0.04, 0.01)
  if belowHorizonCorrection > 0 then
    lightColor:scale(math.lerpInvSat(lightDir.y, -0.01, 0.01))
    lightDir.y = math.lerp(lightDir.y, 0.02, belowHorizonCorrection ^ 2)
  end

  if ctx.spaceLook > 0 then
    lightDir:setLerp(lightDir, SunDir, ctx.spaceLook)
    lightColor:setLerp(lightColor, rgb.colors.white, ctx.spaceLook)
  elseif thunderFlashAdded and SunDir.y < 0 then
    lightDir:set(thunderFlash.direction)
    lightColor:setScaled(thunderFlash.color, 10)
  end

  -- Applying everything
  ac.setLightDirection(lightDir)
  ac.setLightColor(lightColor)
  ac.setSpecularColor(lightColor)
  ac.setSunSpecularMultiplier(CurrentConditions.clear ^ 2)

  ac.setCloudsLight(lightDir, lightColor, 6371e3)
  CloudsLightDirection:set(lightDir)
  CloudsLightColor:set(lightColor)
end

-- Updates ambient lighting based on sky color without taking sun or moon into account
local ambientBaseColor = rgb(1, 1, 1)
local ambientAdjColor = rgb(1, 1, 1)
local ambientDistantColor = rgb()
local ambientExtraColor = rgb()
local ambientExtraDirection = vec3()
local ambientLuminance = 1

function ApplyAmbient()
  -- Computing sky color on horizon 90° off sun direction
  local d = math.sqrt(SunDir.x ^ 2 + SunDir.z ^ 2)
  ambientExtraDirection.x = SunDir.z / d
  ambientExtraDirection.z = -SunDir.x / d
  ambientExtraDirection.y = 0.15 - 0.05 * ctx.sunsetK
  ac.calculateSkyColorV2To(ambientBaseColor, ambientExtraDirection, false, false, false)
  ambientBaseColor:scale(0.5 + 0.5 * CurrentConditions.clear)

  -- Syncing luminance with top sky point for more even lighting
  local targetLuminance = skyTopColor:luminance()
  ambientBaseColor:scale(targetLuminance / math.max(1e-9, ambientBaseColor:luminance()))

  -- If there are a lot of clouds around, desaturating ambient light and shifting it a bit closer to sun color
  local ambientDesaturate = math.lerp(Sim.weatherConditions.humidity ^ 2 * 0.25, 1, CurrentConditions.clouds)
  local ambientSaturate = (1 - ambientDesaturate) * CurrentConditions.saturation
  local sunColorSynced = ambientAdjColor:set(sunColor):scale(targetLuminance / math.max(1e-9, sunColor:luminance()))
  ambientBaseColor:adjustSaturation(ambientSaturate):mul(CurrentConditions.tint)

  local basicSunColorContribution = ac.isBouncedLightActive() and 0.1 or 0.2
  ambientBaseColor:setLerp(ambientBaseColor, sunColorSynced,
    (basicSunColorContribution + ambientDesaturate * 0.4) * (CurrentConditions.clear ^ 2))

  -- Ambient light is ready
  ac.setAmbientColor(ambientBaseColor)
  ambientLuminance = ambientBaseColor:luminance()

  -- Distant ambient lighting is a tiny bit more bluish because why not
  ac.setDistantAmbientColor(ambientDistantColor:set(0.95, 1, 1.05):mul(ambientBaseColor), 20e3)
  ambientExtraColor:set(skyTopColor):adjustSaturation(ambientSaturate):mul(CurrentConditions.tint)
  ambientExtraColor:setLerp(ambientExtraColor, sunColorSynced,
    (0.1 + ambientDesaturate * 0.4) * (CurrentConditions.clear ^ 2)):sub(ambientBaseColor)
  ambientExtraColor:add(LightPollutionColor)
  ac.setExtraAmbientColor(ambientExtraColor)
  ac.setExtraAmbientDirection(vec3Up)

  -- Adjusting fake shadows under cars
  ac.setWeatherFakeShadowOpacity(1 - ctx.spaceLook)
  ac.setWeatherFakeShadowConcentration(0)

  -- Adjusting vertex AO
  ac.adjustTrackVAO(1, 0, 1)
  ac.adjustDynamicAOSamples(1, 0, 1)
end

function ApplySceneTweaks(dt)
  local grassThrive = math.saturateN(Sim.ambientTemperature / 20) * Sim.weatherConditions.humidity
  ac.configureGrassShading(0.07 * (1 + ctx.sunsetK), 0.03 * (1 + ctx.sunsetK), grassThrive * 2, 0.25 + grassThrive)
  ac.setSnowMix(math.lerpInvSat(Sim.ambientTemperature, 1, 0))
end

-- Updates fog, fog color is based on ambient color, so sometimes this fog can get red with sunsets
local skyHorizonColor = rgb(1, 1, 1)
local secondaryFogColor = rgb(1, 1, 1)
local fogNoise = LowFrequency2DNoise:new { frequency = 0.003 }

function ApplyFog(dt)
  --[[
  TODO: composite call, needs tuple/struct type support in nova
  ]]
  ac.calculateSkyColorTo(
    skyHorizonColor,
    vec3(SunDir.z, 0, -SunDir.x),
    false, false
  )

  local ccFog = ctx.finalFog
  local occlusionMult = math.lerpInvSat(ctx.cameraOcclusion, 0.1, 1) ^ 2

  --
  -- write to nova
  skyHorizonColor:scale(SkyBrightness * occlusionMult * 0.5)
  Nova.state.fog.color:set(skyHorizonColor)

  local pressureMult = 101325 / Sim.weatherConditions.pressure
  local fogBlend = math.lerpInvSat(ac.getAltitude(), 10e3, 5e3)
  local fogDistance =
      math.lerp(28.58e3 * pressureMult * (1 - Sim.weatherConditions.humidity * 0.6), 1e3, ctx.totalPollution)
      * math.lerp(1, 0.1, math.lerp((1 - CurrentConditions.clear) * 0.5, 1, ccFog))

  Nova.state.fog.distance = fogDistance
  Nova.state.fog.exponent = 1 - CurrentConditions.pollution * 0.5
  Nova.state.fog.blend = fogBlend

  local atmosphereFade = math.lerp(ccFog, 1, math.max(CurrentConditions.clouds, 1 - CurrentConditions.clear))
  Nova.state.fog.atmosphere =
      fogDistance
      * (1 - atmosphereFade * 0.5) / (22.5e3 * pressureMult)
      * (0.45 + Sim.weatherConditions.humidity * 0.5)

  local distanceBoost = math.max(0, Sim.cameraPosition.y - GroundYAveraged) * math.lerp(4, 0.4, ctx.nightK)
  secondaryFogColor
      :set(ambientDistantColor)
      :addScaled(lightColor, lightDir.y):scale(1 - ctx.nightK)
      :addScaled(skyHorizonColor, ctx.nightK)
      :scale((0.05 + 0.95 * occlusionMult) * 2)

  --[[
  TODO: composite call, needs tuple/struct type support in nova
  ]]
  ac.setNearbyFog(
    secondaryFogColor,
    math.lerp(math.lerp(5e3, 1e3, ctx.nightK), math.lerp(50, 30, ctx.nightK), ccFog) + distanceBoost,
    math.lerp(-20, -10, ccFog),
    fogBlend * math.min(1, 1.2 * ccFog / (0.1 + ccFog)),
    math.lerp(0.9, 1.1, fogNoise:get(Sim.cameraPosition)) * (1 + ccFog ^ 2)
  )

  local horizonFog = math.min(1, 1.5 * ccFog / (0.5 + ccFog))
  Nova.state.fog.skyMult = horizonFog * 0.8
  --[[
  TODO: composite call, needs tuple/struct type support in nova
  ]]
  ac.setHorizonFogMultiplier(
    1, math.lerp(math.lerp(10, 4, ctx.horizonK), 0.5, horizonFog),
    ctx.fogRangeMult
  )

  Nova.state.fog.backlitExp = 12
  Nova.state.fog.backlitMult =
      math.lerp(4, 0.2, CurrentConditions.clouds)
      * (ctx.cameraOcclusion ^ 4)
end

-- Calculates heat factor for wobbling air above heated track and that wet road/mirage effect
function ApplyHeatFactor()
  local heatFactor = math.lerpInvSat(SunDir.y, 0.6, 0.7)
      * math.lerpInvSat(CurrentConditions.clear, 0.7, 0.9)
      * math.lerpInvSat(CurrentConditions.clouds, 0.6, 0.3)
      * math.lerpInvSat(CurrentConditions.windSpeed, 7, 3)
  ac.setTrackHeatFactor(heatFactor)
end

-- Updates stuff like moon, stars and planets
function ApplySkyFeatures()
  -- local brightness = ((0.25 / math.max(lightBrightness, 0.05)) ^ 2) * LightPollutionSkyFeaturesMult
  --   * (CurrentConditions.clear ^ 4) * 0.1

  local moonBrightness = math.lerp(50, 10 - CurrentConditions.clear * 9, ctx.nightK ^ 0.1)
  local moonOpacity = math.lerp(0.1, 1, ctx.nightK) * CurrentConditions.clear * LightPollutionSkyFeaturesMult
  local starsBrightness = 2

  local starsMultBase = CurrentConditions.clear * (1 - ctx.finalFog)
  starsMultBase = starsMultBase * (1 - AuroraIntensity * 0.3)

  local starsMult = starsMultBase * (1 - LightPollutionValue)
  moonOpacity = 0.005
  moonBrightness = 50 * starsMult
  starsBrightness = (1 + 9 * ctx.nightK) * starsMult
  ac.setSkyMoonBaseColor(MoonColor)

  ac.setSkyPlanetsBrightness(5)
  ac.setSkyPlanetsOpacity(ctx.nightK * starsMultBase)

  if ctx.spaceLook > 0 then
    moonBrightness = math.lerp(moonBrightness, 1, ctx.spaceLook)
    starsBrightness = math.lerp(starsBrightness, 1, ctx.spaceLook)
    moonOpacity = math.lerp(moonOpacity, 1, ctx.spaceLook)
  end

  ac.setSkyMoonMieMultiplier(0.00003 * (1 - CurrentConditions.clear) * (1 - ctx.finalFog))
  ac.setSkyMoonBrightness(moonBrightness)
  ac.setSkyMoonOpacity(moonOpacity)
  ac.setSkyMoonMieExp(120)
  ac.setSkyMoonDepthSkip(true)

  -- boosting stars brightness for low FOV for some extra movie magic
  starsBrightness = starsBrightness / math.clampN(math.atan(math.rad(Sim.cameraFOV)), 0.05, 1)

  ac.setSkyStarsColor(MoonColor)
  ac.setSkyStarsBrightness(starsBrightness * moonOpacity)
  StarsBrightness = starsBrightness * moonOpacity

  -- easiest way to take light pollution into account is
  -- to raise stars map in power: with stars map storing values from 0 to 1, it gets rid of dimmer stars only leaving
  -- brightest ones

  local augustK = math.lerpInvSat(math.abs(1 - ac.getDayOfTheYear() / 200), 0.2, 0.1)
  local pollutionK = LightPollutionValue
  pollutionK = math.lerp(pollutionK, 1, 1 - ctx.nightK)
  pollutionK = math.lerp(pollutionK, 1, math.lerpInvSat(ctx.moonDir.y, -0.1, 0.1) * 0.5)

  -- augustK = 1
  -- pollutionK = 0

  ac.setSkyStarsSaturation(math.lerp(0.3, 0.1, pollutionK) * CurrentConditions.saturation)
  ac.setSkyStarsExponent(math.lerp(4 - augustK, 12, pollutionK))

  -- ac.setSkyStarsBrightness(0.1)
  -- ac.setSkyStarsExponent(1)
  -- ac.setSkyStarsBrightness(1)
  -- ac.setSkyStarsExponent(2)

  ac.setSkyPlanetsSizeBase(1)
  ac.setSkyPlanetsSizeVariance(1)
  ac.setSkyPlanetsSizeMultiplier(1)
end

-- local function sunBehindHorizon(sunDir, distanceToCenter, earthRadius)
--   return (sunDir.y * distanceToCenter) ^ 2 + earthRadius ^ 2 > distanceToCenter ^ 2
-- end

-- Thing thing disables shadows if it’s too cloudy or light is not bright enough, or downsizes shadow map resolution
-- making shadows look blurry
function ApplyAdaptiveShadows()
  if lightColor:value() < 1e-5 then
    ac.setShadows(ac.ShadowsState.Off)
  elseif ctx.spaceLook > 0 then
    ac.resetShadowsResolution()
    ac.setShadows(ac.ShadowsState.On)
    -- if SunDir.y > 0 then
    --   ac.setShadows(ac.ShadowsState.On)
    -- elseif sunBehindHorizon(SunDir, ac.getAltitude() + 6400e3, 6400e3) then
    --   ac.setShadows(ac.ShadowsState.EverythingShadowed)
    -- else
    --   ac.setShadows(ac.ShadowsState.On)
    -- end
  elseif belowHorizonCorrection > 0 and BlurShadowsWhenSunIsLow then
    if belowHorizonCorrection > 0.8 then
      ac.setShadowsResolution(256)
    elseif belowHorizonCorrection > 0.6 then
      ac.setShadowsResolution(384)
    elseif belowHorizonCorrection > 0.4 then
      ac.setShadowsResolution(512)
    elseif belowHorizonCorrection > 0.2 then
      ac.setShadowsResolution(768)
    else
      ac.setShadowsResolution(1024)
    end
    ac.setShadows(ac.ShadowsState.On)
  elseif BlurShadowsWithFog then
    if ctx.finalFog > 0.96 then
      ac.setShadowsResolution(256)
    elseif ctx.finalFog > 0.92 then
      ac.setShadowsResolution(384)
    elseif ctx.finalFog > 0.88 then
      ac.setShadowsResolution(512)
    elseif ctx.finalFog > 0.84 then
      ac.setShadowsResolution(768)
    elseif ctx.finalFog > 0.8 then
      ac.setShadowsResolution(1024)
    else
      ac.resetShadowsResolution()
    end
    ac.setShadows(ac.ShadowsState.On)
  else
    ac.resetShadowsResolution()
    ac.setShadows(ac.ShadowsState.On)
  end
end

-- The idea here is to use scene brightness for adapting camera to darkness in tunnels
-- unlike auto-exposure approach, it would be smoother and wouldn’t jump as much if camera
-- simply rotates and, for example, looks down in car interior
ac.setCameraOcclusionDepthBoost(2.5)
local function getSceneBrightness(dt)
  return ctx.cameraOcclusion ^ 2
end

local brightnessMult = 1
function ApplyFakeExposure_postponed()
  -- New implementation taking auto-exposure from post-processing into account
  local currentExposure = _G.getFinalExposure and _G.getFinalExposure() or ac.getAutoExposure()
  ac.setWhiteReferencePoint(0.4 / brightnessMult / math.pow(currentExposure, 2.2))

  local delta = math.abs(brightnessMult - BrightnessMultApplied)
  if delta < 1e-5 then
    ac.adjustCubemapReprojectionBrightness(1)
    return false
  end

  local cubemapMult = BrightnessMultApplied <= 0 and 1 or brightnessMult / BrightnessMultApplied
  ac.adjustCubemapReprojectionBrightness(cubemapMult)

  BrightnessMultApplied = brightnessMult
  ac.setBrightnessMult(GammaFixBrightnessOffset * brightnessMult)

  ac.setHDRToLDRConversionHints(1 / (brightnessMult * GammaFixBrightnessOffset), 0.4545)
  ac.setOverallSkyBrightnessMult(1)
  ac.setSkyV2DitherScale(0)

  if ac.isPpActive() then
    ppBrightnessCorrection.value = 1
  end

  -- Lights can be pretty dark now
  local lightsMult = 0.004

  -- A funny trick: split multiplier into v1 and v2 since v1 is the one that can turn the lights
  -- off, so there could be a bit of extra optimization in a sunny day
  local v1LightsMult = 0.001 + 0.999 * math.lerpInvSat(brightnessMult, 2, 5)
  ac.setWeatherLightsMultiplier(math.pow(v1LightsMult, 1 / 2.2))
  ac.setWeatherLightsMultiplier2((lightsMult / v1LightsMult * GammaFixBrightnessOffset) * brightnessMult)
  ac.setBaseAmbientColor(rgb.tmp():set(0.00002))
  ac.setEmissiveMultiplier(ScriptSettings.LINEAR_COLOR_SPACE.DIM_EMISSIVES and 0.07 or 2.5 / brightnessMult) -- how bright are emissives
  ac.setTrueEmissiveMultiplier(3)                                                                            -- how bright are extrafx emissives
  ac.setGlowBrightness(1)                                                                                    -- how bright are those distant emissive glows
  ac.setWeatherTrackLightsMultiplierThreshold(0.01)

  -- No need to boost reflections here (and fresnel gamma wouldn’t even work anyway)
  ac.setFresnelGamma(1)
  ac.setReflectionEmissiveBoost(1)

  return delta > 0.01
end

-- There are two problems fake exposure solves:
-- 1. We need days to be much brighter than nights, to such an extend that lights wouldn’t be visible in sunny days.
--    That also hugely helps with performance.
-- 2. In dark tunnels, brightness should go up, revealing those lights and overexposing everything outside.
-- Ideally, HDR should’ve solved that task, but it introduces some other problems: for example, emissives go too dark,
-- or too bright during the day. That’s why instead this thing uses fake exposure, adjusting brightness a bit, but
-- also, adjusting intensity of all dynamic lights and emissives to make it seem like the difference is bigger.
function ApplyFakeExposure(dt)
  local envBrightness = ambientLuminance * 3 + lightColor:luminance() * math.saturate(lightDir.y * 20)
  local envMix = getSceneBrightness(dt)

  local localBrightness = math.lerp(0, envBrightness, envMix)
  localBrightness = (localBrightness ^ 2 + 1) ^ 0.5 -- soft max instead of basic math.max(localBrightness, 1)

  if ctx.spaceLook > 0 then
    localBrightness = math.lerp(localBrightness, 1, ctx.spaceLook)
  end

  local brightnessMultTarget = 50 / localBrightness
  if initialSet > 0 or RecentlyJumped > 0 then
    brightnessMult = brightnessMultTarget
    initialSet = initialSet - 1
  else
    brightnessMult = math.applyLag(brightnessMult, brightnessMultTarget, 0.98, dt)
  end

  local aiHeadlights = math.lerp(math.lerpInvSat(ambientLuminance, 0.05, 0.03), 1,
    math.max(ctx.finalFog, math.min(CurrentConditions.rain * 10, 1)))
  ac.setAiHeadlightsSuggestion(aiHeadlights, 0.3)
end

-- Creates generic cloud material
---@return ac.SkyCloudMaterial
local function createGenericCloudMaterial(props)
  local ret = ac.SkyCloudMaterial()
  ret.baseColor = rgb(0.15, 0.15, 0.15)
  ret.useSceneAmbient = false
  ret.ambientConcentration = 0.35
  ret.frontlitMultiplier = 1
  ret.frontlitDiffuseConcentration = 0.45
  ret.backlitMultiplier = 0
  ret.backlitExponent = 30
  ret.backlitOpacityMultiplier = 0.6
  ret.backlitOpacityExponent = 1.7
  ret.specularPower = 1
  ret.specularExponent = 5
  ret.alphaSmoothTransition = 1
  ret.normalFacingExponent = 2

  if props ~= nil then
    for k, v in pairs(props) do
      ret[k] = v
    end
  end

  return ret
end

-- Global cloud materials
CloudMaterials = {}

-- Initialization for some static values
CloudMaterials.Main = createGenericCloudMaterial({
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
  fogMultiplier = 1
})

CloudMaterials.Bottom = createGenericCloudMaterial({
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
  fogMultiplier = 1
})

CloudMaterials.Hovering = createGenericCloudMaterial({
  frontlitMultiplier = 1,
  frontlitDiffuseConcentration = 0.3,
  ambientConcentration = 0.1,
  backlitMultiplier = 2,
  backlitOpacityMultiplier = 0.8,
  backlitOpacityExponent = 3,
  backlitExponent = 20,
  specularPower = 0,
  specularExponent = 1,
  fogMultiplier = 1
})

CloudMaterials.Spread = createGenericCloudMaterial({
  frontlitMultiplier = 1,
  frontlitDiffuseConcentration = 0,
  ambientConcentration = 0,
  backlitMultiplier = 4,
  backlitOpacityMultiplier = 0,
  backlitOpacityExponent = 1,
  backlitExponent = 20,
  specularPower = 0,
  specularExponent = 1,
  fogMultiplier = 1
})

local cloudMateralsList = { CloudMaterials.Main, CloudMaterials.Bottom, CloudMaterials.Hovering, CloudMaterials.Spread }
local prevSunsetK = -1
local prevCloudDensityK = -1
local prevCloudClearK = -1

-- Update cloud materials for chanding lighting conditions
function UpdateCloudMaterials()
  ac.setLightShadowOpacity(math.lerp(0, 0.6 + 0.3 * CurrentConditions.clouds, CurrentConditions.clear))

  local main = CloudMaterials.Main
  local ccCloudsDensity = CurrentConditions.cloudsDensity
  local ccClear = CurrentConditions.clear

  local densityMult = 1 - ccCloudsDensity * 0.8
  main.ambientColor:setScaled(skyTopColor, 3 * densityMult)
  main.extraDownlit:setScaled(lightColor, 0.03 * lightDir.y * densityMult)
      :addScaled(LightPollutionColor, 0.5 * densityMult)
  main.extraDownlit.r, main.extraDownlit.b = main.extraDownlit.r * 0.9, main.extraDownlit.b * 0.8

  if math.abs(prevCloudDensityK - ccCloudsDensity) > 0.001
      or math.abs(prevCloudClearK - ccClear) > 0.001
      or math.abs(prevSunsetK - SunDir.y) > 0.001 then
    prevSunsetK = SunDir.y
    prevCloudDensityK = ccCloudsDensity
    prevCloudClearK = ccClear
    for _, v in ipairs(cloudMateralsList) do
      v.baseColor:set(0.3 * densityMult)
      v.ambientConcentration = math.lerp(0.25, 0.45, ccCloudsDensity) * (0.5 + 0.5 * ccClear)
      v.frontlitMultiplier = math.lerp(2.5, 1, ctx.horizonK) * densityMult
      v.frontlitDiffuseConcentration = math.lerp(0.5, 0.75, ctx.sunsetK)
      v.receiveShadowsOpacity = 0.9
      v.specularPower = math.lerp(1, 8, ctx.sunsetK)
      v.specularExponent = 4
      v.backlitMultiplier = 4 * densityMult
      v.backlitExponent = 10
      v.backlitOpacityMultiplier = 0.5
      v.backlitOpacityExponent = 1
      v.contourIntensity = 0.2 * densityMult
      v.contourExponent = 1
      v.fogMultiplier = 1
      v.alphaSmoothTransition = 1
    end
    CloudMaterials.Bottom.contourExponent = 2
  end

  CloudMaterials.Bottom.ambientColor:set(main.ambientColor)
  CloudMaterials.Bottom.extraDownlit:set(main.extraDownlit)
  CloudMaterials.Hovering.ambientColor:set(main.ambientColor)
  CloudMaterials.Hovering.extraDownlit:set(main.extraDownlit)
  CloudMaterials.Spread.ambientColor:set(main.ambientColor)
  CloudMaterials.Spread.extraDownlit:set(main.extraDownlit)
end

function ApplyThunder(dt)
  if dt == 0 then
    return false
  end

  local cc = CurrentConditions
  local chance = cc.thunder * cc.clouds
  if math.random() > math.lerp(1.03, 0.97, chance) and ctx.spaceLook == 0 then
    thunderActiveFor = 0.1 + math.random() * 0.3
  end

  local showFlash = false
  if thunderActiveFor > 0 then
    thunderActiveFor = thunderActiveFor - dt
    showFlash = math.random() > 0.95
  end

  if showFlash then
    if not thunderFlashAdded then
      thunderFlash.direction = vec3(
        math.random() - 0.5 - 0.1 * CurrentConditions.windDir.x, math.random() ^ 2,
        math.random() - 0.5 - 0.1 * CurrentConditions.windDir.y):normalize()

      local drawBolt = thunderFlash.direction.y < 0.4
      if drawBolt then
        AddVisualLightning(thunderFlash.direction:clone())
      end

      thunderFlash.exponent = 1
      thunderFlash.color = rgb(0.3, 0.3, 0.5):scale(1 + math.random()):scale(0.001)
      thunderFlashAdded = true
      ac.skyExtraGradients:push(thunderFlash)
      ac.pauseCubemapUpdates(true)
      return true
    end
  elseif thunderFlashAdded then
    thunderFlashAdded = false
    ac.skyExtraGradients:erase(thunderFlash)
    setTimeout(function()
      ac.pauseCubemapUpdates(false)
    end)
    return true
  end
end

local tornadoEffect

local function findNewTornadoPos()
  local distance = math.lerp(3e3, 12e3, math.random())
  local angle = math.random() * math.tau
  do
    return vec3(-5317.17, -19.31, -1253.33)
  end
  return vec3(Sim.cameraPosition.x + math.sin(angle) * distance, ac.getGroundYApproximation(),
    Sim.cameraPosition.z + math.cos(angle) * distance)
end

function ApplyTornado(intensity)
  if not tornadoEffect then
    if intensity == 0 then return end
    tornadoEffect = {
      intensity = 0,
      instances = {
        { pos = findNewTornadoPos(), size = 2e3 * (0.8 + 0.4 * math.random()), life = 1, start = os.preciseClock() + math.random() * 1e3 },
        -- { pos = findNewTornadoPos(), size = 2e3 * (0.8 + 0.4 * math.random()), life = 7, start = os.preciseClock() + math.random() * 1e3 },
      },
      update = function(s, intensity)
        if s.intensity == s then return end
        if (s.intensity > 0) ~= (intensity > 0) then
          if s.listener then
            s.listener()
          end
          if intensity > 0 then
            s.listener = render.on('main.track.transparent', function()
              for _, v in ipairs(s.instances) do
                local distanceMult = math.lerpInvSat(Sim.cameraPosition:distance(v.pos), 1e3, 2e3)
                local mult = tornadoEffect.intensity
                    * distanceMult
                    * math.lerpInvSat(v.life, 0, 2)
                    * math.lerpInvSat(v.life, 10, 8)
                if distanceMult < 0.99 and v.life < 8 then
                  v.life = math.max(8, 10 - v.life)
                end
                render.tornado(v.pos, v.size, mult, os.preciseClock() - v.start + 5e3)
              end
            end)
          end
        end
        for _, v in ipairs(s.instances) do
          v.life = v.life + Sim.dt * 0.05
          if v.life > 10 then
            v.life = 0
            v.pos = findNewTornadoPos()
            v.size = 2e3 * (0.8 + 0.4 * math.random())
            v.start = os.preciseClock() + math.random() * 1e3
          end
        end
        s.intensity = intensity
      end
    }
  end
  tornadoEffect:update(intensity)
end
