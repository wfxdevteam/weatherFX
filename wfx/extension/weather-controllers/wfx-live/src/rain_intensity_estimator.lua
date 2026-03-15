--------
-- Some helper functions
--------

local function buildRainIntensityMap()
  local ret = {}
  ret[ac.WeatherType.Clear] =             0
  ret[ac.WeatherType.FewClouds] =         0
  ret[ac.WeatherType.ScatteredClouds] =   0
  ret[ac.WeatherType.BrokenClouds] =      0
  ret[ac.WeatherType.OvercastClouds] =    0
  ret[ac.WeatherType.Windy] =             0
  ret[ac.WeatherType.Fog] =               0
  ret[ac.WeatherType.Mist] =              0
  ret[ac.WeatherType.Haze] =              0
  ret[ac.WeatherType.Dust] =              0
  ret[ac.WeatherType.Smoke] =             0
  ret[ac.WeatherType.Sand] =              0
  ret[ac.WeatherType.LightDrizzle] =      0.1
  ret[ac.WeatherType.Drizzle] =           0.2
  ret[ac.WeatherType.HeavyDrizzle] =      0.3
  ret[ac.WeatherType.LightRain] =         0.4
  ret[ac.WeatherType.Rain] =              0.5
  ret[ac.WeatherType.HeavyRain] =         0.6
  ret[ac.WeatherType.LightThunderstorm] = 0.7
  ret[ac.WeatherType.Thunderstorm] =      0.8
  ret[ac.WeatherType.HeavyThunderstorm] = 0.9
  ret[ac.WeatherType.Squalls] =           0
  ret[ac.WeatherType.Tornado] =           1.0
  ret[ac.WeatherType.Hurricane] =         1.0
  ret[ac.WeatherType.LightSnow] =         0
  ret[ac.WeatherType.Snow] =              0
  ret[ac.WeatherType.HeavySnow] =         0
  ret[ac.WeatherType.LightSleet] =        0
  ret[ac.WeatherType.Sleet] =             0.1
  ret[ac.WeatherType.HeavySleet] =        0.2
  ret[ac.WeatherType.Hail] =              0.3
  return ret
end

local RainIntensityEstimator = class('RainIntensityEstimator')

function RainIntensityEstimator:initialize()
  self.map = buildRainIntensityMap()
end

function RainIntensityEstimator:estimate(weatherType)
  return self.map[weatherType] or 0
end

function RainIntensityEstimator:setTo(conditions)
  local currentRain = self:estimate(conditions.currentType)
  local upcomingRain = self:estimate(conditions.upcomingType)
  conditions.rainIntensity = math.lerp(currentRain, upcomingRain, conditions.transition)
  conditions.rainWetness = conditions.rainIntensity > 0 and 1 or 0
  conditions.rainWater = conditions.rainIntensity
end

return RainIntensityEstimator