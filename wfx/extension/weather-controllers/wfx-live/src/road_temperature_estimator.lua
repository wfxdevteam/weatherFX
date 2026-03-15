--------
-- Some helper functions
--------

local function buildWeatherCoefficientMap()
  -- Values are taken from Sol weathers
  local ret = {}
  ret[ac.WeatherType.Clear] =              1.0
  ret[ac.WeatherType.FewClouds] =          1.0
  ret[ac.WeatherType.ScatteredClouds] =    0.8
  ret[ac.WeatherType.BrokenClouds] =       0.1
  ret[ac.WeatherType.OvercastClouds] =     0.01
  ret[ac.WeatherType.Windy] =              0.3
  ret[ac.WeatherType.Fog] =               -0.3
  ret[ac.WeatherType.Mist] =              -0.2
  ret[ac.WeatherType.Haze] =               0.9
  ret[ac.WeatherType.Dust] =               1.0
  ret[ac.WeatherType.Smoke] =             -0.2
  ret[ac.WeatherType.Sand] =               1.0
  ret[ac.WeatherType.LightDrizzle] =       0.1
  ret[ac.WeatherType.Drizzle] =           -0.1
  ret[ac.WeatherType.HeavyDrizzle] =      -0.3
  ret[ac.WeatherType.LightRain] =          0.01
  ret[ac.WeatherType.Rain] =              -0.2
  ret[ac.WeatherType.HeavyRain] =         -0.5
  ret[ac.WeatherType.LightThunderstorm] =  0.7
  ret[ac.WeatherType.Thunderstorm] =       0.2
  ret[ac.WeatherType.HeavyThunderstorm] = -0.2
  ret[ac.WeatherType.Squalls] =           -0.5
  ret[ac.WeatherType.Tornado] =           -0.3
  ret[ac.WeatherType.Hurricane] =         -0.7
  ret[ac.WeatherType.LightSnow] =         -0.7
  ret[ac.WeatherType.Snow] =              -0.8
  ret[ac.WeatherType.HeavySnow] =         -0.9
  ret[ac.WeatherType.LightSleet] =        -1.0
  ret[ac.WeatherType.Sleet] =             -1.0
  ret[ac.WeatherType.HeavySleet] =        -1.0
  ret[ac.WeatherType.Hail] =              -1.0
  return ret
end

local RoadTemperatureEstimator = class('RoadTemperatureEstimator')

function RoadTemperatureEstimator:initialize()
  self.map = buildWeatherCoefficientMap()
end

function RoadTemperatureEstimator:estimate(weatherType, ambientTemperature, daySeconds)
  -- Based on a formula used by original AC Server Manager
  local weatherCoefficient = self.map[weatherType] or 1
  local time = math.clamp((daySeconds / 3600 - 7) / 24, 0, 0.5) * math.lerpInvSat(daySeconds / 3600, 24, 18)
  return ambientTemperature * (1 + 5.33332 * weatherCoefficient * (1 - time) *
      (math.exp(-6 * time) * math.sin(6 * time) + 0.25) * math.sin(0.9 * time))
end

function RoadTemperatureEstimator:setTo(conditions)
  local daySeconds = ac.getDaySeconds()
  local current = self:estimate(conditions.currentType, conditions.temperatures.ambient, daySeconds)
  local upcoming = self:estimate(conditions.upcomingType, conditions.temperatures.ambient, daySeconds)
  conditions.temperatures.road = math.lerp(current, upcoming, conditions.transition)
end

return RoadTemperatureEstimator