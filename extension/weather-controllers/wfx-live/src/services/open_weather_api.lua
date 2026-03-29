--------
-- Actual accessor to OpenWeatherAPI
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
local function buildTypeConversionMap()
  local openWeatherAPIType = {
    ThunderstormWithLightRain = 200,
    ThunderstormWithRain = 201,
    ThunderstormWithHeavyRain = 202,
    LightThunderstorm = 210,
    Thunderstorm = 211,
    HeavyThunderstorm = 212,
    RaggedThunderstorm = 221,
    ThunderstormWithLightDrizzle = 230,
    ThunderstormWithDrizzle = 231,
    ThunderstormWithHeavyDrizzle = 232,
    LightIntensityDrizzle = 300,
    Drizzle = 301,
    HeavyIntensityDrizzle = 302,
    LightIntensityDrizzleRain = 310,
    DrizzleRain = 311,
    HeavyIntensityDrizzleRain = 312,
    ShowerRainAndDrizzle = 313,
    HeavyShowerRainAndDrizzle = 314,
    ShowerDrizzle = 321,
    LightRain = 500,
    ModerateRain = 501,
    HeavyIntensityRain = 502,
    VeryHeavyRain = 503,
    ExtremeRain = 504,
    FreezingRain = 511,
    LightIntensityShowerRain = 520,
    ShowerRain = 521,
    HeavyIntensityShowerRain = 522,
    RaggedShowerRain = 531,
    LightSnow = 600,
    Snow = 601,
    HeavySnow = 602,
    Sleet = 611,
    ShowerSleet = 612,
    LightRainAndSnow = 615,
    RainAndSnow = 616,
    LightShowerSnow = 620,
    ShowerSnow = 621,
    HeavyShowerSnow = 622,
    Mist = 701,
    Smoke = 711,
    Haze = 721,
    SandAndDustWhirls = 731,
    Fog = 741,
    Sand = 751,
    Dust = 761,
    VolcanicAsh = 762,
    Squalls = 771,
    Tornado = 781,
    ClearSky = 800,
    FewClouds = 801,
    ScatteredClouds = 802,
    BrokenClouds = 803,
    OvercastClouds = 804,
    TornadoExtreme = 900,
    TropicalStorm = 901,
    Hurricane = 902,
    Cold = 903,
    Hot = 904,
    Windy = 905,
    Hail = 906,
    Calm = 951,
    LightBreeze = 952,
    GentleBreeze = 953,
    ModerateBreeze = 954,
    FreshBreeze = 955,
    StrongBreeze = 956,
    HighWind = 957,
    Gale = 958,
    SevereGale = 959,
    Storm = 960,
    ViolentStorm = 961,
    HurricaneAdditional = 962,
  }

  local ret = {}
  ret[openWeatherAPIType.RaggedThunderstorm] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.Thunderstorm] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.ThunderstormWithLightRain] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.ThunderstormWithRain] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.ThunderstormWithHeavyRain] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.ThunderstormWithLightDrizzle] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.ThunderstormWithDrizzle] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.ThunderstormWithHeavyDrizzle] = ac.WeatherType.Thunderstorm
  ret[openWeatherAPIType.LightThunderstorm] = ac.WeatherType.LightThunderstorm
  ret[openWeatherAPIType.HeavyThunderstorm] = ac.WeatherType.HeavyThunderstorm
  ret[openWeatherAPIType.TropicalStorm] = ac.WeatherType.HeavyThunderstorm
  ret[openWeatherAPIType.LightIntensityDrizzle] = ac.WeatherType.LightDrizzle
  ret[openWeatherAPIType.LightIntensityDrizzleRain] = ac.WeatherType.LightDrizzle
  ret[openWeatherAPIType.Drizzle] = ac.WeatherType.Drizzle
  ret[openWeatherAPIType.DrizzleRain] = ac.WeatherType.Drizzle
  ret[openWeatherAPIType.ShowerDrizzle] = ac.WeatherType.Drizzle
  ret[openWeatherAPIType.HeavyIntensityDrizzle] = ac.WeatherType.HeavyDrizzle
  ret[openWeatherAPIType.HeavyIntensityDrizzleRain] = ac.WeatherType.HeavyDrizzle
  ret[openWeatherAPIType.LightRain] = ac.WeatherType.LightRain
  ret[openWeatherAPIType.LightIntensityShowerRain] = ac.WeatherType.LightRain
  ret[openWeatherAPIType.ModerateRain] = ac.WeatherType.Rain
  ret[openWeatherAPIType.FreezingRain] = ac.WeatherType.Rain
  ret[openWeatherAPIType.ShowerRainAndDrizzle] = ac.WeatherType.Rain
  ret[openWeatherAPIType.ShowerRain] = ac.WeatherType.Rain
  ret[openWeatherAPIType.RaggedShowerRain] = ac.WeatherType.Rain
  ret[openWeatherAPIType.HeavyIntensityRain] = ac.WeatherType.HeavyRain
  ret[openWeatherAPIType.VeryHeavyRain] = ac.WeatherType.HeavyRain
  ret[openWeatherAPIType.ExtremeRain] = ac.WeatherType.HeavyRain
  ret[openWeatherAPIType.HeavyShowerRainAndDrizzle] = ac.WeatherType.HeavyRain
  ret[openWeatherAPIType.HeavyIntensityShowerRain] = ac.WeatherType.HeavyRain
  ret[openWeatherAPIType.LightSnow] = ac.WeatherType.LightSnow
  ret[openWeatherAPIType.LightShowerSnow] = ac.WeatherType.LightSnow
  ret[openWeatherAPIType.Snow] = ac.WeatherType.Snow
  ret[openWeatherAPIType.ShowerSnow] = ac.WeatherType.Snow
  ret[openWeatherAPIType.HeavySnow] = ac.WeatherType.HeavySnow
  ret[openWeatherAPIType.HeavyShowerSnow] = ac.WeatherType.HeavySnow
  ret[openWeatherAPIType.LightRainAndSnow] = ac.WeatherType.LightSleet
  ret[openWeatherAPIType.RainAndSnow] = ac.WeatherType.Sleet
  ret[openWeatherAPIType.Sleet] = ac.WeatherType.Sleet
  ret[openWeatherAPIType.ShowerSleet] = ac.WeatherType.HeavySleet
  ret[openWeatherAPIType.Mist] = ac.WeatherType.Mist
  ret[openWeatherAPIType.Smoke] = ac.WeatherType.Smoke
  ret[openWeatherAPIType.Haze] = ac.WeatherType.Haze
  ret[openWeatherAPIType.Sand] = ac.WeatherType.Sand
  ret[openWeatherAPIType.SandAndDustWhirls] = ac.WeatherType.Sand
  ret[openWeatherAPIType.Dust] = ac.WeatherType.Dust
  ret[openWeatherAPIType.VolcanicAsh] = ac.WeatherType.Dust
  ret[openWeatherAPIType.Fog] = ac.WeatherType.Fog
  ret[openWeatherAPIType.Squalls] = ac.WeatherType.Squalls
  ret[openWeatherAPIType.Tornado] = ac.WeatherType.Tornado
  ret[openWeatherAPIType.TornadoExtreme] = ac.WeatherType.Tornado
  ret[openWeatherAPIType.ClearSky] = ac.WeatherType.Clear
  ret[openWeatherAPIType.Calm] = ac.WeatherType.Clear
  ret[openWeatherAPIType.LightBreeze] = ac.WeatherType.Clear
  ret[openWeatherAPIType.FewClouds] = ac.WeatherType.FewClouds
  ret[openWeatherAPIType.GentleBreeze] = ac.WeatherType.FewClouds
  ret[openWeatherAPIType.ModerateBreeze] = ac.WeatherType.FewClouds
  ret[openWeatherAPIType.ScatteredClouds] = ac.WeatherType.ScatteredClouds
  ret[openWeatherAPIType.BrokenClouds] = ac.WeatherType.BrokenClouds
  ret[openWeatherAPIType.OvercastClouds] = ac.WeatherType.OvercastClouds
  ret[openWeatherAPIType.Hurricane] = ac.WeatherType.Hurricane
  ret[openWeatherAPIType.Gale] = ac.WeatherType.Hurricane
  ret[openWeatherAPIType.SevereGale] = ac.WeatherType.Hurricane
  ret[openWeatherAPIType.Storm] = ac.WeatherType.Hurricane
  ret[openWeatherAPIType.ViolentStorm] = ac.WeatherType.Hurricane
  ret[openWeatherAPIType.HurricaneAdditional] = ac.WeatherType.Hurricane
  ret[openWeatherAPIType.Cold] = ac.WeatherType.Cold
  ret[openWeatherAPIType.Hot] = ac.WeatherType.Hot
  ret[openWeatherAPIType.Windy] = ac.WeatherType.Windy
  ret[openWeatherAPIType.FreshBreeze] = ac.WeatherType.Windy
  ret[openWeatherAPIType.StrongBreeze] = ac.WeatherType.Windy
  ret[openWeatherAPIType.HighWind] = ac.WeatherType.Windy
  ret[openWeatherAPIType.Hail] = ac.WeatherType.Hail
  return ret
end

local typeConversionMap = buildTypeConversionMap()

-- Actual accessor:
local OpenWeatherAPIAccessor = class('OpenWeatherAPIAccessor')

function OpenWeatherAPIAccessor:initialize(apiKey)
  self.apiKey = apiKey
end

function OpenWeatherAPIAccessor:load(coordinates, callback)
  local url = 'https://api.openweathermap.org/data/2.5/weather?lat='..coordinates.x..'&lon='..coordinates.y..'&appid='..self.apiKey..'&units=metric'
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
      local weatherID = data.weather[1].id or error('Weather ID is missing')
      local temperature = data.main.temp or error('Temperature is missing')
      local pressure = data.main.pressure or error('Pressure is missing')
      local humidity = data.main.humidity or error('Humidity is missing')
      local windSpeed = data.wind.speed or error('Wind speed is missing')
      local windDirection = data.wind.deg or error('Wind direction is missing')

      -- Converting data to units expected by AC
      return {
        weatherType = typeConversionMap[weatherID] or ac.WeatherType.Clear,
        temperature = temperature,      -- C° is fine
        pressure = pressure * 100,      -- hpa to required pascals
        humidity = humidity / 100,      -- percents to required 0 to 1
        windSpeed = windSpeed * 3.6,    -- m/s to required km/h
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

return OpenWeatherAPIAccessor
