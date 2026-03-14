--------
-- Some general constant values, should not be changed real-time.
--------

TimelapsyCloudSpeed = true      -- change to false to stop clouds from moving all fast if time goes faster
SmoothTransition = true         -- smooth transition between weather types (even if change was sudden)
BlurShadowsWhenSunIsLow = false -- reduce shadows resolution for when sun is low
BlurShadowsWithFog = true       -- reduce shadows resolution with thick fog
UseLambertGammaFix = true       -- fixes darker surfaces when sun is low

SunRaysCustom = false           -- use fully custom sun ray parameters instead of SunRaysIntensity
SunRaysIntensity = 0.02         -- some good PP-filters expode with sun rays at full strength for some reason

GammaFixBrightnessOffset = 0.01
GammaFixLightsDivisor = 100

SceneBrightnessMultNoPP = 2  -- without post-processing active: brightness multiplier for the whole scene
SceneBrightnessMultPP = 3    -- with post-processing active: brightness multiplier for the scene (in most cases, gets compensated by auto-exposure)
FilterBrightnessMultPP = 1.0 -- with post-processing active: brightness adjustment applied after auto-exposure

function InitializeConsts()
  ac.useLinearColorSpace(true, GammaFixLightsDivisor)
  ac.setWeatherLightsMultiplier(1)
  ac.setWeatherLightsMultiplier2(1)
  ac.setWeatherLightsRangeFactor(1)
  ac.setWeatherBouncedLightMultiplier(rgb.new(0.45))

  SunIntensity = 12
  SunLightIntensity = 1
  AmbientLightIntensity = 5
  FogBacklitIntensity = 1
  MoonLightMult = 0.005
  SkyBrightness = 1

  AdaptationSpeed = 10
  SunColor = rgb(1, 1, 1)
  MoonColor = rgb(1, 1.5, 2)
  LightPollutionBrightness = 0.003
end

InitializeConsts()

CloudUseAtlas = true
CloudSpawnScale = 0.5
CloudCellSize = 4000
CloudCellDistance = 3

CloudDistanceShiftStart = 7000
CloudDistanceShiftEnd = 17000

CloudFadeNearby = 1000
DynCloudsMinHeight = 400
DynCloudsMaxHeight = 1200
DynCloudsDistantHeight = 200
HoveringMinHeight = 1200
HoveringMaxHeight = 1600

CloudShapeShiftingSpeed = 0.005
CloudShapeMovingSpeed = 0.5
