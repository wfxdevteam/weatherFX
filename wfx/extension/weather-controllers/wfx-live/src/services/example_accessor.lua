-- Example accessor, not really doing anything
local ExampleAccessor = class('ExampleAccessor')

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
  [0] = ac.WeatherType.Clear
}

function ExampleAccessor:initialize(apiKey)
  self.apiKey = apiKey
end

function ExampleAccessor:load(coordinates, callback)
  local url = 'https://non-existant-server.whoops/api?key='..self.apiKey..'&lat='..coordinates.x..'&lon='..coordinates.y
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
      local weatherID = data.weatherCode or error('Weather code is missing')
      local temperature = data.temperature or error('Temperature is missing')
      local pressure = data.pressure or error('Pressure is missing')
      local humidity = data.humidity or error('Humidity is missing')
      local windSpeed = data.windSpeed or error('Wind speed is missing')
      local windDirection = data.windDirection or error('Wind direction is missing')

      -- Converting data to units expected by AC
      return {
        weatherType = typeConversionMap[weatherID] or ac.WeatherType.Clear,
        temperature = temperature,      -- C° is fine
        pressure = pressure * 100,      -- in to required pascals
        humidity = humidity / 100,      -- percents to required 0 to 1
        windSpeed = windSpeed,          -- km/h
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

return ExampleAccessor