--------
-- Actual accessor to https://www.weatherapi.com/
--------

--[[ Need to convert weather type from API scheme to the scheme CSP uses. Known types:
  ac.WeatherType.Clear              ac.WeatherType.FewClouds          ac.WeatherType.Windy
  ac.WeatherType.ScatteredClouds    ac.WeatherType.BrokenClouds       ac.WeatherType.OvercastClouds
  ac.WeatherType.Fog                ac.WeatherType.Mist               ac.WeatherType.Smoke
  ac.WeatherType.Haze               ac.WeatherType.Sand               ac.WeatherType.Dust
  ac.WeatherType.LightRain          ac.WeatherType.Rain               ac.WeatherType.HeavyRain
  ac.WeatherType.LightDrizzle       ac.WeatherType.Drizzle            ac.WeatherType.HeavyDrizzle
  ac.WeatherType.LightThunderstorm  ac.WeatherType.Thunderstorm       ac.WeatherType.HeavyThunderstorm
  ac.WeatherType.LightSleet         ac.WeatherType.Sleet              ac.WeatherType.HeavySleet
  ac.WeatherType.LightSnow          ac.WeatherType.Snow               ac.WeatherType.HeavySnow
  ac.WeatherType.Cold               ac.WeatherType.Hot                ac.WeatherType.Hail
  ac.WeatherType.Squalls            ac.WeatherType.Tornado            ac.WeatherType.Hurricane
]]
local typeConversionMap = {
  [1000] = ac.WeatherType.Clear,
  [1003] = ac.WeatherType.ScatteredClouds,    -- PartlyCloudy
  [1006] = ac.WeatherType.BrokenClouds,       -- Cloudy
  [1009] = ac.WeatherType.OvercastClouds,     -- Overcast
  [1030] = ac.WeatherType.Mist,               -- Mist
  [1063] = ac.WeatherType.Rain,               -- PatchyRainNearby
  [1066] = ac.WeatherType.Snow,               -- PatchySnowNearby
  [1069] = ac.WeatherType.Sleet,              -- PatchySleetNearby
  [1072] = ac.WeatherType.Drizzle,            -- PatchyFreezingDrizzleNearby
  [1087] = ac.WeatherType.LightThunderstorm,  -- ThunderyOutbreaksInNearby
  [1114] = ac.WeatherType.HeavySnow,          -- BlowingSnow
  [1117] = ac.WeatherType.HeavySnow,          -- Blizzard
  [1135] = ac.WeatherType.Fog,                -- Fog
  [1147] = ac.WeatherType.Mist,               -- FreezingFog
  [1150] = ac.WeatherType.LightDrizzle,       -- PatchyLightDrizzle
  [1153] = ac.WeatherType.LightDrizzle,       -- LightDrizzle
  [1168] = ac.WeatherType.Drizzle,            -- FreezingDrizzle
  [1171] = ac.WeatherType.HeavyDrizzle,       -- HeavyFreezingDrizzle
  [1180] = ac.WeatherType.LightRain,          -- PatchyLightRain
  [1183] = ac.WeatherType.LightRain,          -- LightRain
  [1186] = ac.WeatherType.Rain,               -- ModerateRainAtTimes
  [1189] = ac.WeatherType.Rain,               -- ModerateRain
  [1192] = ac.WeatherType.Rain,               -- HeavyRainAtTimes
  [1195] = ac.WeatherType.HeavyRain,          -- HeavyRain
  [1198] = ac.WeatherType.LightRain,          -- LightFreezingRain
  [1201] = ac.WeatherType.Rain,               -- ModerateOrHeavyFreezingRain
  [1204] = ac.WeatherType.LightSleet,         -- LightSleet
  [1207] = ac.WeatherType.Sleet,              -- ModerateOrHeavySleet
  [1210] = ac.WeatherType.HeavySleet,         -- PatchyLightSnow
  [1213] = ac.WeatherType.LightSnow,          -- LightSnow
  [1216] = ac.WeatherType.Snow,               -- PatchyModerateSnow
  [1219] = ac.WeatherType.Snow,               -- ModerateSnow
  [1222] = ac.WeatherType.Snow,               -- PatchyHeavySnow
  [1225] = ac.WeatherType.HeavySnow,          -- HeavySnow
  [1237] = ac.WeatherType.Hail,               -- IcePellets
  [1240] = ac.WeatherType.LightRain,          -- LightRainShower
  [1243] = ac.WeatherType.Rain,               -- ModerateOrHeavyRainShower
  [1246] = ac.WeatherType.HeavyRain,          -- TorrentialRainShower
  [1249] = ac.WeatherType.LightSleet,         -- LightSleetShowers
  [1252] = ac.WeatherType.Sleet,              -- ModerateOrHeavySleetShowers
  [1255] = ac.WeatherType.HeavySleet,         -- LightSnowShowers
  [1258] = ac.WeatherType.HeavySleet,         -- ModerateOrHeavySnowShowers
  [1261] = ac.WeatherType.Hail,               -- LightShowersOfIcePellets
  [1264] = ac.WeatherType.Hail,               -- ModerateOrHeavyShowersOfIcePellets
  [1273] = ac.WeatherType.LightThunderstorm,  -- PatchyLightRainInAreaWithThunder
  [1276] = ac.WeatherType.Thunderstorm,       -- ModerateOrHeavyRainInAreaWithThunder
  [1279] = ac.WeatherType.Thunderstorm,       -- PatchyLightSnowInAreaWithThunder
  [1282] = ac.WeatherType.Squalls,            -- ModerateOrHeavySnowInAreaWithThunder
}

-- Actual accessor:
local WeatherAPIComAccessor = class('WeatherAPIComAccessor')

function WeatherAPIComAccessor:initialize(apiKey)
  self.apiKey = apiKey
end

function WeatherAPIComAccessor:load(coordinates, callback)
  local url = 'https://api.weatherapi.com/v1/current.json?aqi=no&key='..self.apiKey..'&q='..coordinates.x..','..coordinates.y
  web.get(url, function (err, ret)
    -- If failed to load and got an error, pass it along
    if err ~= nil then 
      callback(err) 
    end

    -- Preparing a reply
    local response = try(function ()
      -- Parsing data loaded from API
      local data = JSON.parse(ret.body)

      -- Extracting required values (and throwing an error if any are missing)
      local weatherID = data.current.condition.code or error('Weather code is missing')
      local temperature = data.current.temp_c or error('Temperature is missing')
      local pressure = data.current.pressure_mb or error('Pressure is missing')
      local humidity = data.current.humidity or error('Humidity is missing')
      local windSpeed = data.current.wind_kph or error('Wind speed is missing')
      local windDirection = data.current.wind_degree or error('Wind direction is missing')

      -- Converting data to units expected by AC
      return {
        weatherType = typeConversionMap[weatherID] or ac.WeatherType.Clear,
        temperature = temperature,      -- C° is fine
        pressure = pressure * 100,      -- mb to pascals
        humidity = humidity / 100,      -- percents to required 0 to 1
        windSpeed = windSpeed,          -- km/h
        windDirection = windDirection,              -- regular degrees
      }
    end, function (err)
      -- If failed to prepare, pass an error
      callback(err)
      ac.debug('response', ret.body)
    end)
    
    if response ~= nil then
      -- No error, so returning the actual data
      callback(nil, response)
    end
  end)
end

return WeatherAPIComAccessor
