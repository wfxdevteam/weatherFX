float henyey_greenstein(float cosTheta, float g) {
  float g2 = g * g;
  return (1 - g2) / (4 * 3.14159 * pow(max(0, 1 + g2 - 2 * g * cosTheta), 1.5));
}

// #define MAX_LENGTH 500

float2 main(PS_IN pin) {
  float dither = frac(sin(dot(pin.Tex, float2(12.9898, 78.233)) + gSeed) * 43758.5453);

  float depthValue = pin.GetDepth();
  float4 pixelCameraPos = mul(float4(pin.Tex, depthValue, 1), gTexToCamera);
  pixelCameraPos.xyz /= pixelCameraPos.w;

  float4 prevUV = mul(float4(pixelCameraPos.xyz, 1), gPreviousCameraToTex);
  prevUV.xyz /= prevUV.w; 
  
  float baseDistance = linearizeDepth(depthValue);
  if (baseDistance < 4) return 0;

  float distanceToCamera = length(pixelCameraPos);

  float MAX_LENGTH = lerp(500, 50, saturate(pixelCameraPos.y / distanceToCamera));
  if (distanceToCamera > MAX_LENGTH) {
    pixelCameraPos.xyz *= MAX_LENGTH / distanceToCamera;
    distanceToCamera = MAX_LENGTH;
  }

  float STEPS_COUNT = clamp(ceil(distanceToCamera / 2), 4, 40);
  // STEPS_COUNT = 10;
  // STEPS_COUNT = 40;

  float3 cameraPos = gCameraShiftedPosition;
  float3 pixelWorldPos = pixelCameraPos.xyz + gCameraShiftedPosition;
  
  float density = 0.008;
  float stepLen = distanceToCamera / STEPS_COUNT;
  float transmittance = 1.0;
  float scatteredLight = 0;

  float cosTheta = dot(pixelCameraPos.xyz, -gLightDirection) / distanceToCamera;
  float phaseFunction = henyey_greenstein(cosTheta, 0.5);

  float cloudShadow0 = getCloudShadow(cameraPos);
  float cloudShadow1 = getCloudShadow(pixelWorldPos.xyz);

  for (int i = 0; i < STEPS_COUNT; ++i) {
    float t = (i + dither) / (float)(STEPS_COUNT + 1);
    float3 samplePos = lerp(cameraPos, pixelWorldPos.xyz, t);
    
    float localDensity = density;
    float shadow = getApproximateSceneShadow(samplePos, false) * lerp(cloudShadow0, cloudShadow1, t);    
    float extinction = localDensity * stepLen;
    float inScattering = shadow * localDensity * phaseFunction;
    
    scatteredLight += transmittance * inScattering * stepLen;
    transmittance *= exp(-extinction);
    
    if (transmittance < 0.01) break;
  }

  distanceToCamera = max(distanceToCamera, 1);
  
  float2 cur = float2(scatteredLight * smoothstep(0, 1, saturate(baseDistance / 4 - 1)), distanceToCamera);
  float2 prev = txPrev.SampleLevel(samLinearBorder0, prevUV.xy, 0); 
  if (prev.y && prev.x >= 0) {
    float curWeight = 0;
    curWeight = lerp(curWeight, 1, saturate(1 - cur.x * 1e3));
    curWeight = lerp(curWeight, 1, saturate(length(prevUV.xy - pin.Tex) * 100));
    curWeight = lerp(curWeight, 1, saturate(abs(prev.y - cur.y) / (distanceToCamera * 0.002) - 1));
    cur = lerp(prev, cur, 0.4 + curWeight * 0.6);
  }

  if (!(cur.x > 0)) {
    return 0;
  }

  return cur;
}