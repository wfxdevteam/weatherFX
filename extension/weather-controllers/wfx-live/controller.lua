--------
-- Basic controller which uses real time weather. Look in createAccessor() function to see supported services
-- and some info about API keys.
--------

local cfg = ac.INIConfig.scriptSettings():mapSection('SETTINGS', {
  PROVIDER = 'OPENWEATHER',
  REAL_TEMPERATURE = true,
  REAL_WIND = true,
  REAL_RAIN = true,
})

-- Refresh period (do not set it too low, or it would not change smoothly)
local refreshPeriodSeconds = 10 * 60

-- Shared library for some extra functions (can be found in “extension/internal/lua-shared/sim”)
local weatherUtils = require('shared/sim/weather')

-- First of all, need to load input parameters and set them as conditions in case internet is down or something like that:
local conditions = ac.ConditionsSet()
conditions.currentType = ac.WeatherType.Clear
conditions.upcomingType = ac.WeatherType.Clear
conditions.temperatures = ac.getInputTemperatures()  -- { ambient = 23, road = 15 }
conditions.wind = ac.getInputWind()                  -- { direction = 300, speedFrom = 10, speedTo = 15 }
conditions.trackState = ac.getInputTrackState()      -- { sessionStart = 95, sessionTransfer = 90, randomness = 2, lapGain = 132 }
weatherUtils.setRainIntensity(conditions, true)
weatherUtils.setRoadTemperature(conditions)
ac.setConditionsSet2(conditions)

-- Creating an accessor which will handle access to weather API
local function createAccessor()
  -- You can protect your API keys with ac.debug('key', web.encryptKey('ACTUAL_KEY')) and using resulting value
  -- instead. This way, it would only work for the controller with the same ID. Nothing serious, of course,
  -- but it should at least help with forks.
  -- And, yeah, if you’d want to fork this one, please do so, but please consider getting your own key. That’s
  -- a very simple thing to do, you can start here, for example: https://home.openweathermap.org/users/sign_up.
  -- This way, there would be less chance of people using it to run into rate limits.
  if web.encryptKey('TestingPhrase') ~= '6YYCvny0LG0DeAoq2XrdcqyBXJkUYK1711' then
    ac.debug('Warning', 'If you’re forking this script, you might need to update API keys. The ones that come with it are linked to this script.')
  end

  -- return (require 'src/services/example_accessor')('')
  if cfg.PROVIDER == 'WEATHERAPICOM' then
    return (require 'src/services/weather_api_com')('6YYCvny0DmZ8Zdfv2CH8M6RALzxoDyg0PbGmPVS2GGGmMPdnJxkUYK1711 OPlnJAnkUYK1711')
  elseif cfg.PROVIDER == 'WEATHERBITIO' then
    return (require 'src/services/weatherbit_io')('6YYCvny0CmR9OdTWPfKnZXxALzu8EBBfRvf OVfjGZCoZfG8KTPkUYK1711')
  elseif cfg.PROVIDER == 'OPENMETEO' then
    return (require 'src/services/weatherbit_io')('6YYCvny0CmR9OdTWPfKnZXxALzu8EBBfRvf OVfjGZCoZfG8KTPkUYK1711')
  else
    return (require 'src/services/open_weather_api')('6YYCvny0CG3BPNTtPizbOX7nMzBnPuEu2yLaOIO3GZX OPlnJAnkUYK1711')
  end
end

local apiAccessor = createAccessor()
local trackCoordinates = ac.getTrackCoordinatesDeg()  -- have to know a point to get weather at

-- Weather state: current, upcoming
local currentWeatherState = nil  -- { weatherType, temperature, windDirection, windSpeed, humidity, pressure }
local upcomingWeatherState = nil
local upcomingTimePassed = 0
local updatingNow = false
local debugAwareActive
local requiresReset = false

-- Initial weather loading
local function applyWeatherState(current, upcoming, transition, dt)
  conditions.currentType = current.weatherType
  conditions.upcomingType = upcoming.weatherType
  conditions.transition = current.weatherType ~= upcoming.weatherType and transition or 0
  conditions.humidity = math.lerp(current.humidity, upcoming.humidity, transition)
  conditions.pressure = math.lerp(current.pressure, upcoming.pressure, transition)
  if cfg.REAL_TEMPERATURE then
    conditions.temperatures.ambient = math.lerp(current.temperature, upcoming.temperature, transition)
    conditions.temperatures.road = math.lerp(current.temperature, upcoming.temperature, transition) -- TODO
  elseif requiresReset then
    conditions.temperatures = ac.getInputTemperatures()
  end
  if cfg.REAL_WIND then
    conditions.wind.direction = math.lerp(current.windDirection, upcoming.windDirection, transition)
    conditions.wind.speedFrom = math.lerp(current.windSpeed, upcoming.windSpeed, transition)
    conditions.wind.speedTo = math.lerp(current.windSpeed, upcoming.windSpeed, transition)
  elseif requiresReset then
    conditions.wind = ac.getInputWind()
  end
  if cfg.REAL_RAIN then
    if current.rainIntensity and upcoming.rainIntensity then
      conditions.rainIntensity = math.lerp(current.rainIntensity, upcoming.rainIntensity, transition)
      conditions.rainWetness = conditions.rainIntensity
    else
      weatherUtils.setRainIntensity(conditions, false)
    end
    weatherUtils.setRoadTemperature(conditions)
    conditions.rainWater = math.applyLag(conditions.rainWater, math.pow(conditions.rainIntensity, 0.1), 0.9999, dt)
  elseif requiresReset then
    conditions.rainIntensity = 0
    conditions.rainWetness = 0
    conditions.rainWater = 0
  end
  if weatherUtils.debugAware(conditions, 1) then
    debugAwareActive = true
  elseif debugAwareActive then
    debugAwareActive = false
    requiresReset = true
  else
    requiresReset = false
  end
  ac.setConditionsSet2(conditions)

  ac.debug('state', updatingNow and 'updating…' or string.format('%.1f%%', transition * 100))
  ac.debug('weather: type', string.format('%d -> %d (%.1f%%)', conditions.currentType, conditions.upcomingType, conditions.transition * 100))
  ac.debug('weather: temperature', string.format('ambient: %.1f °C, road: %.1f °C', conditions.temperatures.ambient, conditions.temperatures.road))
  ac.debug('weather: wind', string.format('%.1f km/h, %.0f°', conditions.wind.speedFrom, conditions.wind.direction))
  ac.debug('weather: humidity', string.format('%.0f%%', conditions.humidity * 100))
  ac.debug('weather: pressure', string.format('%.0f hPa', conditions.pressure / 100)) -- hectopascals are pascals divided by 100
end

-- Initial weather refresh
apiAccessor:load(trackCoordinates, function (err, data)
  if err ~= nil then
    -- if initial synchronization has failed, we will not do anything in this session
    ac.debug("error", err)
    return
  end 

  currentWeatherState = data
  upcomingWeatherState = data
  upcomingTimePassed = 0
end)

-- Weather update
local function refreshWeather()
  updatingNow = true
  apiAccessor:load(trackCoordinates, function (err, data)
    updatingNow = false
    upcomingTimePassed = 0

    if err ~= nil then
      -- if update has failed, ignore, next update might work
      ac.debug("error", err)
      return
    end
  
    currentWeatherState = upcomingWeatherState
    upcomingWeatherState = data
  end)
end

-- We don’t need to do anything frame by frame, might even delete this function
function script.update(dt)
  if currentWeatherState == nil then
    -- Until some data would arrive, do nothing
    return 
  end

  -- Updating amount of time passed since last update
  upcomingTimePassed = upcomingTimePassed + dt
  if not updatingNow and upcomingTimePassed > refreshPeriodSeconds then
    -- Need to refresh weather if too much time has passed
    refreshWeather()
  end

  -- Applying weather state for smooth transitions (smoothstep helps to make transitions better)
  applyWeatherState(currentWeatherState, upcomingWeatherState, math.smoothstep(math.saturate(upcomingTimePassed / refreshPeriodSeconds)), dt)
end
