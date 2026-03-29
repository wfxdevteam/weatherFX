-- Example accessor, not really doing anything
local WeatherBitIoAccessor = class('WeatherBitIoAccessor')

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
  [200] = ac.WeatherType.LightThunderstorm,  -- ThunderstormWithLightRain
  [201] = ac.WeatherType.Thunderstorm,       -- ThunderstormWithRain
  [202] = ac.WeatherType.HeavyThunderstorm,  -- ThunderstormWithHeavyRain
  [230] = ac.WeatherType.LightThunderstorm,  -- ThunderstormWithLightDrizzle
  [231] = ac.WeatherType.Thunderstorm,       -- ThunderstormWithDrizzle
  [232] = ac.WeatherType.HeavyThunderstorm,  -- ThunderstormWithHeavyDrizzle
  [233] = ac.WeatherType.HeavyThunderstorm,  -- ThunderstormWithHail
  [300] = ac.WeatherType.LightDrizzle,       -- LightDrizzle
  [301] = ac.WeatherType.Drizzle,            -- Drizzle
  [302] = ac.WeatherType.HeavyDrizzle,       -- HeavyDrizzle
  [500] = ac.WeatherType.LightRain,          -- LightRain
  [501] = ac.WeatherType.Rain,               -- ModerateRain
  [502] = ac.WeatherType.HeavyRain,          -- HeavyRain
  [511] = ac.WeatherType.Rain,               -- FreezingRain
  [520] = ac.WeatherType.LightRain,          -- LightShowerRain
  [521] = ac.WeatherType.LightRain,          -- ShowerRain
  [522] = ac.WeatherType.Rain,               -- HeavyShowerRain
  [600] = ac.WeatherType.LightSnow,          -- LightSnow
  [601] = ac.WeatherType.Snow,               -- Snow
  [602] = ac.WeatherType.HeavySnow,          -- HeavySnow
  [610] = ac.WeatherType.Rain,               -- MixSnow/rain
  [611] = ac.WeatherType.LightSleet,         -- Sleet
  [612] = ac.WeatherType.Sleet,              -- HeavySleet
  [621] = ac.WeatherType.HeavySleet,         -- SnowShower
  [622] = ac.WeatherType.HeavySleet,         -- HeavySnowShower
  [623] = ac.WeatherType.Squalls,            -- Flurries
  [700] = ac.WeatherType.Mist,               -- Mist
  [711] = ac.WeatherType.Smoke,              -- Smoke
  [721] = ac.WeatherType.Haze,               -- Haze
  [731] = ac.WeatherType.Sand,               -- Sand/dust
  [741] = ac.WeatherType.Fog,                -- Fog
  [751] = ac.WeatherType.Fog,                -- FreezingFog
  [800] = ac.WeatherType.Clear,              -- ClearSky
  [801] = ac.WeatherType.FewClouds,          -- FewClouds
  [802] = ac.WeatherType.ScatteredClouds,    -- ScatteredClouds
  [803] = ac.WeatherType.BrokenClouds,       -- BrokenClouds
  [804] = ac.WeatherType.OvercastClouds,     -- OvercastClouds
}

function WeatherBitIoAccessor:initialize(apiKey)
  self.apiKey = apiKey
end

function WeatherBitIoAccessor:load(coordinates, callback)
  local url = 'https://api.weatherbit.io/v2.0/current?key='..self.apiKey..'&lat='..coordinates.x..'&lon='..coordinates.y
  web.get(url, function (err, ret)
    -- If failed to load and got an error, pass it along
    if err ~= nil then
      callback(err)
    end

    -- Preparing a reply
    local response = try(function ()
      -- Parsing data loaded from API
      local data = JSON.parse(ret.body).data[1]

      -- Extracting required values (and throwing an error if any are missing)
      local weatherID = data.weather.code or error('Weather code is missing')
      local temperature = data.temp or error('Temperature is missing')
      local pressure = data.pres or error('Pressure is missing')
      local humidity = data.rh or error('Humidity is missing')
      local windSpeed = data.wind_spd or error('Wind speed is missing')
      local windDirection = data.wind_dir or error('Wind direction is missing')

      -- Converting data to units expected by AC
      return {
        weatherType = typeConversionMap[weatherID] or ac.WeatherType.Clear,
        temperature = temperature,      -- C° is fine
        pressure = pressure * 100,      -- mb to required pascals
        humidity = humidity / 100,      -- percents to required 0 to 1
        windSpeed = windSpeed * 3.6,    -- from m/s to km/h
        windDirection = windDirection,  -- regular degrees
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

return WeatherBitIoAccessor