-- read ac weather conditions and map to physical model inputs
ac.WeatherType.NoClouds = 100

local M = {}
local state = require 'src/state'

local defaultConditions = {
  fog = 0,
  clear = 1,
  clouds = 0,
  cloudsDensity = 0,
  tint = rgb(1, 1, 1),
  saturation = 1,
  thunder = 0,
  pollution = 0,
  snow = 0
}

M.current = {
  fog = 0,
  clear = 1,
  clouds = 0,
  cloudsDensity = 0,

  tint = rgb(1, 1, 1),
  saturation = 1.0,

  --phenomena
  thunder = 0,
  pollution = 0,
  snow = 0,

  rain = 0,
  wetness = 0,
  water = 0,

  windDir = vec2(0, 0),
  windDirInstant = vec2(0, 0),
  windSpeed = 0,
  windSpeedInstant = 0,

  humidity = 0
}

local weatherDefinitions = {}
local function def(params)
  weatherDefinitions[params.type] = table.assign({}, defaultConditions, params)
end

-- literally the exact same thing as conditions_converter

def { type = ac.WeatherType.NoClouds, fog = 0, clear = 1, clouds = 0 }
def { type = ac.WeatherType.Clear, fog = 0, clear = 1, clouds = 0.01 }
def { type = ac.WeatherType.FewClouds, fog = 0, clear = 1, clouds = 0.25 }
def { type = ac.WeatherType.ScatteredClouds, fog = 0, clear = 1, clouds = 0.5 }
def { type = ac.WeatherType.BrokenClouds, fog = 0, clear = 0.9, clouds = 0.75 }
def { type = ac.WeatherType.OvercastClouds, fog = 0, clear = 0, clouds = 1 }
def { type = ac.WeatherType.Windy, fog = 0, clear = 0.8, clouds = 0.6, saturation = 0.0 }
def { type = ac.WeatherType.Cold, fog = 0.3, clear = 0.9, clouds = 0.4, saturation = 0.5, tint = rgb(0.8, 0.9, 1.0) }
def { type = ac.WeatherType.Hot, fog = 0.1, clear = 1, clouds = 0.1, saturation = 1.2, tint = rgb(1.0, 0.9, 0.8) }
def { type = ac.WeatherType.Fog, fog = 1, clear = 0.1, clouds = 0 }
def { type = ac.WeatherType.Mist, fog = 0.4, clear = 0.6, clouds = 0.2, tint = rgb(0.8, 0.9, 1.0) }
def { type = ac.WeatherType.Haze, fog = 0.3, clear = 0.5, clouds = 0.2, tint = rgb(1, 0.92, 0.9), saturation = 0.8, pollution = 0.25 }
def { type = ac.WeatherType.Dust, fog = 0.5, clear = 0.9, clouds = 0.2, tint = rgb(1, 0.85, 0.8), saturation = 0.8, pollution = 0.5 }
def { type = ac.WeatherType.Smoke, fog = 0.7, clear = 0.9, clouds = 0.8, tint = rgb(0.8, 0.7, 0.9):scale(0.4), saturation = 0.4, pollution = 0.75 }
def { type = ac.WeatherType.Sand, fog = 0.9, clear = 0.2, clouds = 0.9, tint = rgb(1, 0.6, 0.4):scale(0.7), pollution = 1 }
def { type = ac.WeatherType.LightDrizzle, fog = 0.1, clear = 0.9, clouds = 0.7, cloudsDensity = 0.2, saturation = 0.5 }
def { type = ac.WeatherType.Drizzle, fog = 0.3, clear = 0.7, clouds = 0.8, cloudsDensity = 0.4, tint = rgb(0.9, 0.95, 1.0) }
def { type = ac.WeatherType.HeavyDrizzle, fog = 0.5, clear = 0.5, clouds = 0.9, cloudsDensity = 0.6, tint = rgb(0.8, 0.9, 1.0), thunder = 0.1 }
def { type = ac.WeatherType.LightRain, fog = 0.1, clear = 0.9, clouds = 0.5, cloudsDensity = 0.3 }
def { type = ac.WeatherType.Rain, fog = 0.25, clear = 0.3, clouds = 0.7, cloudsDensity = 0.4 }
def { type = ac.WeatherType.HeavyRain, fog = 0.5, clear = 0, clouds = 0.9, cloudsDensity = 0.5 }
def { type = ac.WeatherType.LightThunderstorm, fog = 0.6, clear = 0.1, clouds = 0.9, cloudsDensity = 0.8, thunder = 0.4 }
def { type = ac.WeatherType.Thunderstorm, fog = 0.8, clear = 0, clouds = 1, cloudsDensity = 0.9, tint = rgb.new(0.6), thunder = 0.6 }
def { type = ac.WeatherType.HeavyThunderstorm, fog = 0.9, clear = 0, clouds = 1, cloudsDensity = 1.0, tint = rgb.new(0.4), thunder = 0.8 }
def { type = ac.WeatherType.LightSnow, fog = 0.2, clear = 0.8, clouds = 0.4, cloudsDensity = 0.3, tint = rgb(0.8, 0.9, 1.0), snow = 0.2 }
def { type = ac.WeatherType.Snow, fog = 0.4, clear = 0.05, clouds = 0.6, cloudsDensity = 0.5, tint = rgb(0.6, 0.8, 1.0), snow = 0.5 }
def { type = ac.WeatherType.HeavySnow, fog = 1, clear = 0, clouds = 0.8, cloudsDensity = 0.8, tint = rgb(0.4, 0.7, 1.0), snow = 1 }
def { type = ac.WeatherType.LightSleet, fog = 0.1, clear = 0.9, clouds = 0.7, cloudsDensity = 0.2, tint = rgb(0.6, 0.8, 1.0), saturation = 0.25, snow = 0.01 }
def { type = ac.WeatherType.Sleet, fog = 0.3, clear = 0.7, clouds = 0.8, cloudsDensity = 0.4, tint = rgb(0.6, 0.8, 1.0), saturation = 0.12, snow = 0.03 }
def { type = ac.WeatherType.HeavySleet, fog = 0.5, clear = 0.5, clouds = 0.9, cloudsDensity = 0.6, tint = rgb(0.6, 0.8, 1.0), saturation = 0.0, snow = 0.05 }
def { type = ac.WeatherType.Squalls, fog = 0.1, clear = 1, clouds = 1, saturation = 1.2 }
def { type = ac.WeatherType.Tornado, fog = 0.05, clear = 0, clouds = 1, cloudsDensity = 0.95, tint = rgb(1, 0.98, 0.9) }
def { type = ac.WeatherType.Hurricane, fog = 0.8, clear = 0, clouds = 1, tint = rgb(0.28, 0.24, 0.3):adjustSaturation(0.5), thunder = 1 }
def { type = ac.WeatherType.Hail, fog = 0.5, clear = 0, clouds = 1, tint = rgb(0.3, 0.24, 0.28):adjustSaturation(0.5), thunder = 1 }

local conditionsState = ac.getConditionsSet()
local previousType = nil
local tintSmoothed = rgb(1, 1, 1)

local function uniqueModifier(s, weatherType)
  return math.lerp(
    s.currentType == weatherType and 1 or 0,
    s.upcomingType == weatherType and 1 or 0,
    s.transition)
end

function M.read(dt)
  local s = conditionsState
  local sim = ac.getSim()

  ac.getConditionsSetTo(s)

  if s.currentType ~= previousType then
    previousType = s.currentType
    state.keepForceUpdates = 1
  end

  -- wind
  local cc = M.current
  local dir = s.wind.direction * math.pi / 180
      + math.perlin(sim.timestamp / 1.04e5, 3) * 2
  cc.windDirInstant:set(-math.sin(dir), math.cos(dir))
  cc.windSpeedInstant = (s.wind.speedFrom + s.wind.speedTo) / (2 * 3.6)

  local smooth = (os.preciseClock() < 1) and 0 or 0.95
  local lag = math.lagMult(smooth, dt)
  local vc = weatherDefinitions[s.currentType] or defaultConditions
  local vu = weatherDefinitions[s.upcomingType] or defaultConditions

  --?????????????????
  ---Helper function to blend weather properties.
  ---@param key string The weather property key to blend (e.g., 'fog', 'snow').
  ---@return number @The blended numeric value.
  local function blend(key)
    return math.lerp(vc[key], vu[key], s.transition)
  end

  cc.fog = cc.fog + (blend('fog') - cc.fog) * lag
  cc.clear = cc.clear + (blend('clear') - cc.clear) * lag
  cc.clouds = cc.clouds + (blend('clouds') - cc.clouds) * lag
  cc.cloudsDensity = cc.cloudsDensity + (blend('cloudsDensity') - cc.cloudsDensity) * lag
  cc.saturation = cc.saturation + (blend('saturation') - cc.saturation) * lag
  cc.thunder = cc.thunder + (blend('thunder') - cc.thunder) * lag
  cc.pollution = cc.pollution + (blend('pollution') - cc.pollution) * lag
  cc.rain = cc.rain + (s.rainIntensity - cc.rain) * lag
  cc.wetness = cc.wetness + (s.rainWetness - cc.wetness) * lag
  cc.water = cc.water + (s.rainWater - cc.water) * lag
  cc.humidity = cc.humidity + (s.humidity - cc.humidity) * lag

  local tv = rgb(
    math.lerp(vc.tint.r, vu.tint.r, s.transition),
    math.lerp(vc.tint.g, vu.tint.g, s.transition),
    math.lerp(vc.tint.b, vu.tint.b, s.transition))
  tintSmoothed.r = tintSmoothed.r + (tv.r - tintSmoothed.r) * lag
  tintSmoothed.g = tintSmoothed.g + (tv.g - tintSmoothed.g) * lag
  tintSmoothed.b = tintSmoothed.b + (tv.b - tintSmoothed.b) * lag

  cc.tint:set(tintSmoothed)

  local rawSnow = math.max(0,
    blend('snow') - math.lerpInvSat(sim.ambientTemperature, 0, 5) * 0.05)
  cc.snow = cc.snow + (rawSnow - cc.snow) * lag

  ac.setWeatherParticles('ash', uniqueModifier(s, ac.WeatherType.Smoke) * 0.1, 0)
  ac.setWeatherParticles('snow', cc.snow, cc.snow ^ 2)
  ac.setSnowMix(math.lerpInvSat(sim.ambientTemperature, 1, 0))
end

return M
