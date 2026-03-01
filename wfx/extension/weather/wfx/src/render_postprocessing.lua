--[[
  Lightweight post-processing alternative. Meant to do a single full-res pass, so it could run as fast as possible, while
  also being compatible with YEBIS where possible.

  Features:
  • Color corrections;
  • Color grading;
  • Tonemapping (sensitometric and logarithmic aren’t entirely precise though);
  • Vignette (apart from FOV parameter at the moment);
  • Auto-exposure (simpler version because I couldn’t figure out original behaviour);
  • Lens distortion (alternative stupid version which might be somewhat more usable);
  • Chromatic aberration (without extra samples to keep things fast, but respects other settings);
  • Sun rays (alternative version, ignores settings);
  • Glare (very basic glow which shouldn’t flicker as much, ignores settings);
  • DOF (experimental single-pass effect ignoring most settings).
]]

local buffersCache = {}

table.insert(OnResolutionChange, function ()
  table.clear(buffersCache)
end)

local function bloomHelper(resolution)
  local inSize = resolution:clone()
  local steps = math.floor(math.log(math.min(inSize.x, inSize.y), 2) - 1)
  if steps < 2 then
    return function() return 'color::#000000' end
  end
  local threshold1 = ui.ExtraCanvas(vec2(math.ceil(inSize.x / 16), inSize.y), 1, render.AntialiasingMode.None, render.TextureFormat.R16.Float)
  local threshold2 = ui.ExtraCanvas(vec2(math.ceil(inSize.x / 16), math.ceil(inSize.y / 16)), 1, render.AntialiasingMode.None, render.TextureFormat.R16.Float)
  local thresholdB = ui.ExtraCanvas(vec2(math.ceil(inSize.x / 16), math.ceil(inSize.y / 16)), 1, render.AntialiasingMode.None, render.TextureFormat.R16.Float)
  local thresholdPass1 = {
    textures = { txInput = '' },
    values = { gBrightnessMult = 1 },
    defines = { PASS = 1 },
    cacheKey = 1,
    shader = 'shaders/pp_bloom_threshold.fx',
    async = true,
    directValuesExchange = true,
  }
  local thresholdPass2 = {
    textures = { ['txInput.1'] = threshold1 },
    values = { gBrightnessMult = 1 },
    defines = { PASS = 2 },
    cacheKey = 2,
    shader = 'shaders/pp_bloom_threshold.fx',
    async = true,
    directValuesExchange = true,
  }
  local list = {} ---@type {tex: ui.ExtraCanvas, pass1: table, pass2: table}[]
  local appliedQuality = -1
  do
    for i = 1, steps do
      resolution = vec2(math.ceil(resolution.x / 2), math.ceil(resolution.y / 2))
      list[i] = {
        tex = ui.ExtraCanvas(resolution, 1, render.AntialiasingMode.None, render.TextureFormat.R11G11B10.Float),
        pass1 = {
          textures = i == 1 and { txInput = '', ['txLimit.1'] = thresholdB } or { txInput = list[i - 1].tex },
          values = { gTexSizeInv = i == 1 and 1 / inSize or 1 / list[i - 1].tex:size() },
          defines = i == 1 and { PASS_INDEX = i } or {},
          cacheKey = i,
          directValuesExchange = true,
          async = true,
          shader = 'shaders/pp_bloom_downsample.fx'
        }
      }
    end
    for i = 1, steps - 1 do
      list[i].pass2 = {
        blendMode = render.BlendMode.BlendPremultiplied,
        textures = {
          txInput = list[i + 1].tex
        },
        values = {
          gTexSizeInv = 1 / list[i + 1].tex:size()
        },
        defines = {},
        cacheKey = i,
        shader = 'shaders/pp_bloom_upsample.fx',
        directValuesExchange = true,
        async = true,
      }
    end
  end
  local quality1
  return function (input, quality)
    if quality == 1 then
      if not quality1 then
        quality1 = { tex = ui.ExtraCanvas(list[2].tex:size(), 1, render.AntialiasingMode.None, render.TextureFormat.R11G11B10.Float), pass = {
          textures = { txInput = '' },
          values = { gTexSizeInv = 1 / list[2].tex:size(), gLimit = 1 },
          shader = 'shaders/pp_bloom_quality1.fx',
          directValuesExchange = true,
          async = true,
        } }
      end
      quality1.pass.textures.txInput = input
      quality1.pass.values.gLimit = GammaFixBrightnessOffset * 1600
      quality1.tex:updateWithShader(quality1.pass)
      list[2].tex:gaussianBlurFrom(quality1.tex, 15)
      return list[2].tex
    end
    if quality ~= appliedQuality then
      appliedQuality = quality
      if quality <= 2 then
        thresholdB:clear(rgbm(GammaFixBrightnessOffset * 1600))
      end
      for i = 1, steps do
        list[i].pass1.defines.QUALITY = quality
        if list[i].pass2 then list[i].pass2.defines.QUALITY = quality end
      end
    end
    if quality > 2 then
      thresholdPass1.textures.txInput = input
      thresholdPass1.values.gBrightnessMult = UseGammaFix and 0.01 / GammaFixBrightnessOffset or 1
      thresholdPass2.values.gBrightnessMult = UseGammaFix and GammaFixBrightnessOffset or 1
      threshold1:updateWithShader(thresholdPass1)
      threshold2:updateWithShader(thresholdPass2)
      thresholdB:gaussianBlurFrom(threshold2, 15)
    end
    list[1].pass1.textures.txInput = input
    for i = 1, steps do
      if not list[i].tex:updateWithShader(list[i].pass1) then return 'color::#000000' end
    end
    for i = steps - 1, 1, -1 do
      if not list[i].tex:updateWithShader(list[i].pass2) then return 'color::#000000' end
    end
    return list[1].tex
  end
end

---@param resolution vec2
local function createPPData(resolution)
  local bloom = bloomHelper(resolution)
  local sunRaysFormat = ScriptSettings.LINEAR_COLOR_SPACE.ENABLED 
    and render.TextureFormat.R16.Float 
    or render.TextureFormat.R8.UNorm
  resolution = resolution:clone():scale(0.5)
  local skyMask = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, render.TextureFormat.R8.UNorm) --:setName('skyMask')
  local sunRays1 = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, sunRaysFormat) --:setName('sunRays1')
  local sunRays2 = ui.ExtraCanvas(resolution, 1,
    render.AntialiasingMode.None, sunRaysFormat) --:setName('sunRays2')
  return {
    skyMask = skyMask, 
    sunRays1 = sunRays1, 
    sunRays2 = sunRays2, 
    bloom = bloom,
    passSkyMaskParams = {
      async = true,
      textures = {
        ['txHDR'] = 'dynamic::pp::hdr',
        ['txDepth.1'] = 'dynamic::pp::depth',
      },
      values = {
        gBrightnessMult = 0.65
      },
      shader = [[float4 main(PS_IN pin) {
        return dot(txDepth.GatherRed(samLinearBorder0, pin.Tex) == 1, 0.25) 
          * saturate(txHDR.SampleLevel(samLinearBorder0, pin.Tex, 0).b * gBrightnessMult - 0.5);
      }]]
    },
    passSun1Params = {
      async = true,
      textures = {
        ['txNoise'] = 'dynamic::noise',
        ['txMask.1'] = skyMask,
      },
      values = {
        gSunPosition = vec2()
      },
      shader = [[float4 main(PS_IN pin) {
        float m = 0;
        float2 d = gSunPosition - pin.Tex;
        // d *= min(1, min(d.x > 0 ? (1 - pin.Tex.x) / d.x  : pin.Tex.x / -d.x, d.y > 0 ? (1 - pin.Tex.y) / d.y  : pin.Tex.y / -d.y)) / 10;
        d /= 10;
        float2 s = pin.Tex + d * txNoise.Load(int3(pin.PosH.xy % 32, 0)).x;
        for (int i = 0; i < 10; ++i){
          m += txMask.SampleLevel(samLinearBorder0, s, 0);
          s += d;
        }
        return m / 10;
      }]]
    },
    passSun2Params = {
      async = true,
      textures = {
        ['txIn.1'] = sunRays1,
      },
      values = {
        gSunPosition = vec2()
      },
      shader = [[float4 main(PS_IN pin) {
        float m = 0;
        float2 dir = gSunPosition - pin.Tex;
        for (int i = -1; i < 9; ++i) m += txIn.SampleLevel(samLinearClamp, pin.Tex + dir * (i / 25.), 0);
        return m / 10;
      }]]
    },
    passSun3Params = {
      async = true,
      textures = {
        ['txIn.1'] = sunRays2,
      },
      values = {
        gSunPosition = vec2()
      },
      shader = [[float4 main(PS_IN pin) {
        float m = 0;
        float2 dir = gSunPosition - pin.Tex;
        for (int i = -1; i < 9; ++i) m += txIn.SampleLevel(samLinearClamp, pin.Tex + dir * (i / 100.), 0);
        return m / 10;
      }]]
    },
    pass2Params = {
      blendMode = render.BlendMode.Opaque,
      depthMode = render.DepthMode.Off,
      textures = {
        txInput = 'dynamic::pp::hdr',
        txBlur2 = 'color::#000000',
        ['txMask.1'] = skyMask,
        ['txSunRaysMask.1'] = sunRays1,
        txColorGrading = 'dynamic::pp::colorGrading3D',
        txDirty = 'color::#000000',
        txGrain = 'color::#000000'
      },
      values = {
        FEATURE_USE_SUN_RAYS = false,
        FEATURE_USE_GLARE = false,
        FEATURE_USE_COLOR_GRADING = false,
        FEATURE_USE_VIGNETTE = false,
        FEATURE_USE_LENS_DISTORTION = false,
        FEATURE_USE_CHROMATIC_ABERRATION = false,
        FEATURE_USE_FILM_GRAIN = false,
        FEATURE_USE_GLARE_CHROMATIC_ABERRATION = ScriptSettings.POSTPROCESSING.GLARE_CHROMATIC_ABERRATION,
        gMatHDR = mat4x4(),
        gMatLDR = mat4x4(),
        gColorGrading = 0,
        gVignette = 0,
        gVignetteRatio = vec2(1, 1),
        gExposure = 1,
        gGamma = 1,
        gMappingFactor = 32,
        gMappingData = vec4(),
        gGlareLuminance = 1,
        gLensDistortion = 0,
        gLensDistortionRoundness = 0,
        gLensDistortionSmoothness = 0,
        gSunPosition = vec2(),
        gSunColor = rgb(),
        gChromaticAberrationLateral = vec2(),
        gChromaticAberrationUniform = vec2(),
        gTime = 0,
        gGammaFixBrightnessOffset = 0,
        gDirty = math.clampN(ScriptSettings.POSTPROCESSING.LENS_DIRT * 2, 0, 1),
        gFilmGrain = ScriptSettings.POSTPROCESSING.FILM_GRAIN * 0.5,
      },
      defines = {
        TONEMAP_FN = -1,
      },
      cacheKey = 0,
      directValuesExchange = true,
      compileValuesMask = '{ FEATURE_? }', --[[ this option will force CSP to recompile specialized shaders when these values would change. Do
        not use this thing for values such as decimals: each combination seen will be stored in memory and cached on disk. ]]
      shader = 'shaders/pp_final.fx'
    },
    useDof = false
  } 
end

local aeMeasure1 = ui.ExtraCanvas(256, 8, render.TextureFormat.R16.Float)
local aeMeasure2 = ui.ExtraCanvas(vec2(4, 256), 8, render.TextureFormat.R16.Float)
local aeMeasure3 = ui.ExtraCanvas(4, 4, render.TextureFormat.R16.Float)
local aeMeasured = 0
local aeCurrent = tonumber(ac.load('wfx.base.ae')) or 1
if not math.isfinite(aeCurrent) then aeCurrent = 1 end

table.insert(OnGammaFixChange, function ()
  aeCurrent = 1
end)

local aePass1 = {
  textures = {
    txInput = 'dynamic::pp::hdr',
  },
  values = {
    gGammaFixBrightnessOffset = 1,
    gMappingFactor = 32,
    gMappingData = vec4(),
    gAreaSize = vec2(),
    gAreaOffset = vec2(),
  },
  defines = {},
  cacheKey = 0,
  shader = 'shaders/pp_ae_1.fx'
}

local aePass2 = {
  textures = {
    ['txInput.1'] = aeMeasure1,
  },
  shader = [[float main(PS_IN pin) {
    float r = 0;
    for (int i = 0; i < 64; ++i) {
      r += txInput.Load(int3((int)pin.PosH.x * 64 + i, (int)pin.PosH.y, 0));
    }
    return r / 64;
  }]]
}

local aePass3 = {
  textures = {
    ['txInput.1'] = aeMeasure2,
  },
  shader = [[float main(PS_IN pin) {
    float r = 0;
    for (int i = 0; i < 64; ++i) {
      r += txInput.Load(int3((int)pin.PosH.x, (int)pin.PosH.y * 64 + i, 0));
    }
    return r / 64;
  }]]
}

---@param data ui.ExtraCanvasData
local function autoExposureDataCallback(err, data)
  if data then
    local v = 0
    for y = 0, 3 do
      for x = 0, 3 do
        v = v + data:floatValue(x, y)
      end
    end
    aeMeasured = math.exp(v / 16)
    data:dispose()
  else
    aeMeasured = 0
  end
end

SunRaysCustom = true

local function createDevPPData(resolution)
  return {
    canvas = ui.ExtraCanvas(resolution, 1, render.TextureFormat.R16G16B16A16.Float),
    params = {
      blendMode = render.BlendMode.Opaque,
      depthMode = render.DepthMode.Off,
      textures = {
        ['txHDR'] = 'dynamic::pp::hdr'
      },
      values = {
        gBrightness = 1
      },
      directValuesExchange = true,
      cacheKey = 0,
      shader = 'shaders/pp_gamma.fx'
    }
  }
end

---@param params ac.PostProcessingParameters
---@param finalExposure number
local function configureAutoExposure(passParams, params, finalExposure, limited)
  local tonemap = params.tonemapFunction < 0 and 2 or params.tonemapFunction
  if limited and tonemap > 6 then
    tonemap = 2
  end
  passParams.values.gExposure = finalExposure
  passParams.values.gGamma = 1 / params.tonemapGamma
  passParams.values.gMappingFactor = params.tonemapMappingFactor
  if tonemap == 2 then
    passParams.values.gMappingData.x = math.lerp(1.4, 3.2, params.filmicContrast ^ 0.6)
    passParams.values.gMappingData.y = math.lerp(0.1, 0.9, params.filmicContrast ^ 0.6)
  elseif tonemap == 3 or tonemap == 4 then
    passParams.values.gMappingData.x = 1 / (params.tonemapMappingFactor * finalExposure) ^ 2
  elseif tonemap == 5 or tonemap == 6 then
    passParams.values.gMappingData.x = math.log(params.tonemapMappingFactor + 1) / 0.6931
    passParams.values.gMappingData.y = 1 / passParams.values.gMappingData.x
    passParams.values.gMappingData.z = 1 / (params.tonemapMappingFactor * finalExposure) ^ 2
  end

  local tonemappingFn = params.customTonemappingFunctionCode and ac.getCustomTonemappingFunctionCode() or nil
  if tonemappingFn ~= passParams.__prevCustomTonemappingFn then
    -- Wacky way to get custom tonemapping functions to work. If they use values named gSomething, it won’t work, but changes of collision should
    -- be lower due to __wfxfn_ prefix used in shaders now. 
    -- It would be a lot more compatible to just run the code in a separate shader, but there is a lot of performance gain from doing most of post-processing
    -- in a single pass.
    passParams.__prevCustomTonemappingFn = tonemappingFn
    passParams.defines.TONEMAP_FN_IMPL = tonemappingFn and tonemappingFn:reggsub([[//.+]], ''):reggsub([[\s+main\s*(?=\(float)]], ' __custom_tonemaping_main'):replace('\n', '\\\n') or nil
    passParams.cacheKey = bit.bor(bit.band(passParams.cacheKey, bit.bnot(0xffff00)), tonemappingFn and bit.band(ac.checksumXXH(tonemappingFn), 0xffff00) or 0)
  end
  if not tonemappingFn then
    if passParams.defines.TONEMAP_FN ~= tonemap then
      passParams.defines.TONEMAP_FN = tonemap
      passParams.cacheKey = bit.bor(bit.band(passParams.cacheKey, bit.bnot(127)), tonemap)
      -- key = tonemap | (key & ~127)
    end  
  end
end

local finalExposure = 1
local lastBrightnessMult = -1
ac.onPostProcessing(function (params, exposure, mainPass, updateExponent, rtSize)
  -- if mainPass then
  --   ac.debug('exposure', exposure)
  --   ac.debug('autoExposureTarget', params.autoExposureTarget)
  --   ac.debug('tonemapExposure', params.tonemapExposure)
  -- end
  if mainPass and ScriptSettings.LINEAR_COLOR_SPACE.DEV_MODE and Overrides.originalPostProcessing then
    if not UseGammaFix then
      return
    end
    local data = table.getOrCreate(buffersCache, 2e7 + rtSize.y * 10000 + rtSize.x, createDevPPData, rtSize)
    data.params.values.gBrightness = 0.45 / GammaFixBrightnessOffset
    data.canvas:updateWithShader(data.params)
    return data.canvas
  end

  local data = table.getOrCreate(buffersCache, (mainPass and 0 or 1e7) + rtSize.y * 10000 + rtSize.x, createPPData, rtSize)
  if Sim.isPreviewsGenerationMode then
    params.autoExposureEnabled = false
    params.godraysEnabled = false
    params.chromaticAberrationEnabled = false
    params.dofActive = false
    params.lensDistortionEnabled = false
    params.vignetteStrength = 0
  end

  if updateExponent and mainPass then
    -- We could add separate autoexposure to non-main views if we’d want to, but we don’t
    if params.autoExposureEnabled then
      aePass1.values.gGammaFixBrightnessOffset = UseGammaFix and 0.45 / GammaFixBrightnessOffset or 1
      aePass1.values.gAreaOffset:set(params.autoExposureAreaOffset)
      aePass1.values.gAreaSize:set(params.autoExposureAreaSize)
      configureAutoExposure(aePass1, params, 1, true)
      aeMeasure1:updateWithShader(aePass1)
      aeMeasure2:updateWithShader(aePass2)
      aeMeasure3:updateWithShader(aePass3)
      aeMeasure3:accessData(autoExposureDataCallback)
      -- local s = os.preciseClock()
      -- aeMeasure3:accessData(function (...)
      --   print('AE: %.2f ms' % ((os.preciseClock() - s) * 1e3))
      --   autoExposureDataCallback(...)
      -- end)
      if aeMeasured > 0 then
        local aeTarget = params.autoExposureTarget * exposure / aeMeasured
        if UseGammaFix then
          -- TODO: Find a better way?
          aeTarget = aeTarget * (Sim.isFocusedOnInterior and 0.35 or 0.6)
        end
        aeTarget = math.clamp(aeTarget, params.autoExposureMin, params.autoExposureMax)
        if lastBrightnessMult ~= -1 and BrightnessMultApplied > 0 then
          aeCurrent = aeCurrent * lastBrightnessMult / BrightnessMultApplied
        end
        lastBrightnessMult = BrightnessMultApplied
        aeCurrent = math.applyLag(aeCurrent, aeTarget, RecentlyJumped > 0 and 0 or 0.97, ac.getDeltaT())
        ac.store('wfx.base.ae', aeCurrent)
        finalExposure = aeCurrent
        -- ac.debug('aeTarget', aeTarget)
        -- ac.debug('aeCurrent', aeCurrent)
      end
      -- ac.debug('finalExposure', finalExposure)
    else
      finalExposure = params.tonemapExposure
    end
  end

  local useDof = mainPass and params.dofActive and params.dofActive and params.dofQuality >= 4
  if useDof ~= data.useDof then
    if not data.dofPrepared then
      data.dofPrepared = ui.ExtraCanvas(rtSize:clone():scale(0.5), 1, render.TextureFormat.R16G16B16A16.Float) --:setName('dofPrepared')
      data.dofOutput = ui.ExtraCanvas(rtSize, 1, render.TextureFormat.R16G16B16A16.Float) --:setName('dofOutput')
      data.passDofPrepare = {
        textures = {
          txInput = 'dynamic::pp::hdr',
          ['txDepth.1'] = 'dynamic::pp::depth',
        },
        shader = [[float4 main(PS_IN pin) {
          return float4(txInput.SampleLevel(samLinearSimple, pin.Tex, 0).rgb, txDepth.SampleLevel(samLinearSimple, pin.Tex, 0));
        }]]
      }
      data.passDofProcess = {
        textures = {
          txInput = 'dynamic::pp::hdr',
          ['txDepth.1'] = 'dynamic::pp::depth',
          txDOF = data.dofPrepared,
        },
        values = {
          focusPoint = 0,
          focusScale = 0,
          uPixelSize = 1 / rtSize,
        },
        directValuesExchange = true,
        shader = 'shaders/pp_dof.fx'
      }
    end
    data.useDof = useDof
    data.pass2Params.textures.txInput = useDof and data.dofOutput or 'dynamic::pp::hdr'
  end

  if useDof then
    local gNearPlane = params.cameraNearPlane
    local gFarPlane = params.cameraFarPlane
    local focusPoint = (gFarPlane + gNearPlane - 2 * gNearPlane * gFarPlane / params.dofFocusDistance) / (gFarPlane - gNearPlane) / 2 + 0.5
    data.passDofProcess.values.focusPoint = focusPoint
    data.passDofProcess.values.focusScale = (1 + focusPoint * 5) * 6 / params.dofApertureFNumber
    data.dofPrepared:updateWithShader(data.passDofPrepare)
    data.dofOutput:updateWithShader(data.passDofProcess)
  end

  data.pass2Params.values.gMatHDR:set(ac.getPostProcessingHDRColorMatrix())
  data.pass2Params.values.gMatHDR:transposeSelf() -- with `directValuesExchange` we need to transpose matrices manually

  data.pass2Params.values.gMatLDR:set(ac.getPostProcessingLDRColorMatrix())
  data.pass2Params.values.gMatLDR:transposeSelf() 

  local ratioHalf = (rtSize.x / rtSize.y + 0.5) / 2
  data.pass2Params.values.gVignetteRatio:set(ratioHalf, 1 / ratioHalf)

  configureAutoExposure(data.pass2Params, params, finalExposure)

  local useGlare = params.glareEnabled and params.glareLuminance > 0 and params.glareQuality > 0
  data.pass2Params.values.FEATURE_USE_GLARE = useGlare
  if useGlare then
    data.pass2Params.values.gGlareLuminance = params.glareLuminance * (UseGammaFix and 0.002 or 0.005)
    data.pass2Params.textures.txBlur2 = data.bloom(data.pass2Params.textures.txInput, params.glareQuality)
    data.pass2Params.textures.txDirty = ScriptSettings.POSTPROCESSING.LENS_DIRT > 0 and Sim.cameraMode ~= ac.CameraMode.Cockpit and 'res/dirt.jpg' or 'color::#000000'
  end

  if params.vignetteStrength ~= data.pass2Params.values.gVignette then
    data.pass2Params.values.FEATURE_USE_VIGNETTE = params.vignetteStrength ~= 0
    data.pass2Params.values.gVignette = params.vignetteStrength
  end

  local cg = ac.getPostProcessingColorGradingIntensity()
  if cg ~= data.pass2Params.values.gColorGrading then
    data.pass2Params.values.gColorGrading = cg
    data.pass2Params.values.FEATURE_USE_COLOR_GRADING = cg ~= 0
  end

  if data.pass2Params.values.FEATURE_USE_LENS_DISTORTION ~= params.lensDistortionEnabled then
    data.pass2Params.values.FEATURE_USE_LENS_DISTORTION = params.lensDistortionEnabled
  end
  if params.lensDistortionEnabled then
    data.pass2Params.values.gLensDistortion = math.tan(params.cameraVerticalFOVRad / 2)
    data.pass2Params.values.gLensDistortionRoundness = 1 / (0.01 + params.lensDistortionRoundness)
    data.pass2Params.values.gLensDistortionSmoothness = 1 / (0.01 + params.lensDistortionSmoothness)
  end

  local useSunRays = mainPass and params.godraysEnabled and params.godraysInCameraFustrum
    and params.godraysColor:value() > 1 and not Sim.isTripleFSRActive
  local sunRaysReady = false
  if useSunRays then
    data.passSun1Params.values.gSunPosition:set(params.godraysOrigin)
    data.passSun2Params.values.gSunPosition:set(params.godraysOrigin)
    data.passSun3Params.values.gSunPosition:set(params.godraysOrigin)
    data.passSkyMaskParams.values.gBrightnessMult = UseGammaFix and 1 / GammaFixBrightnessOffset or 1
    if data.skyMask:updateWithShader(data.passSkyMaskParams)
        and data.sunRays1:updateWithShader(data.passSun1Params)
        and data.sunRays2:updateWithShader(data.passSun2Params)
        and data.sunRays1:updateWithShader(data.passSun3Params) then
      data.pass2Params.values.gSunPosition:set(params.godraysOrigin)
      data.pass2Params.values.gSunColor:set(GodraysColor):scale(UseGammaFix and (10 * GammaFixBrightnessOffset / BrightnessMultApplied) or 1)
      sunRaysReady = true
    end
  end
  data.pass2Params.values.FEATURE_USE_SUN_RAYS = sunRaysReady

  local useChromaticAberration = params.chromaticAberrationEnabled and params.chromaticAberrationActive
  data.pass2Params.values.FEATURE_USE_CHROMATIC_ABERRATION = useChromaticAberration
  if useChromaticAberration then
    data.pass2Params.values.gChromaticAberrationLateral:set(params.chromaticAberrationLateralDisplacement):div(rtSize):scale(100)
    data.pass2Params.values.gChromaticAberrationUniform:set(params.chromaticAberrationUniformDisplacement):div(rtSize):scale(100)
  end

  local useFilmGrain = ScriptSettings.POSTPROCESSING.FILM_GRAIN and Sim.cameraMode ~= ac.CameraMode.Cockpit and not Sim.isPreviewsGenerationMode
  if data.pass2Params.values.FEATURE_USE_FILM_GRAIN ~= useFilmGrain then
    data.pass2Params.values.FEATURE_USE_FILM_GRAIN = useFilmGrain

    if useFilmGrain and data.pass2Params.textures.txGrain == 'color::#000000' then
      local noise = ui.ExtraCanvas(vec2(128, 2048))
      noise:updateWithShader({
        shader = [[
        float4 hash4(float2 p) {
          float4 q = float4(dot(p, float2(127.1, 311.7)), 
            dot(p, float2(269.5, 183.3)), 
            dot(p, float2(419.2, 371.9)), 
            dot(p, float2(381.2, 687.4)));
          return frac(sin(q) * 43758.5453);
        }
        float4 main(PS_IN pin) {
          float4 col = hash4(pin.Tex);
          col.rgb = lerp(col.rgb, dot(col.rgb, 0.33), 0.5);
          return col;
        }]]
      })
      data.pass2Params.textures.txGrain = noise or 'dynamic::noise'
    end
  end
  if useFilmGrain and not Sim.isMakingScreenshot then
    data.pass2Params.values.gTime = Sim.gameTime
  end

  if UseGammaFix then
    data.pass2Params.values.gGammaFixBrightnessOffset = 0.45 / GammaFixBrightnessOffset
  end
  render.fullscreenPass(data.pass2Params)
  return true
end)
