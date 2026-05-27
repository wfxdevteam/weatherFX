float gatherBase(float2 uv){
  return txBase.SampleLevel(samLinearBorder0, uv, 0).x;
}

float computeWeight(float refDistance, float sampleDistance) {
  float relDif = abs(refDistance - sampleDistance);
  return 1 / (0.2 + relDif);
}

float gatherSmooth(float2 uv, float depth) {  
  float4 pixelCameraPos = mul(float4(uv, 1, depth), gTexToCamera);
  pixelCameraPos.xyz /= pixelCameraPos.w;

  float distanceToCamera = length(pixelCameraPos);
  if (distanceToCamera < 4) return 0;

  float MAX_LENGTH = lerp(500, 50, saturate(pixelCameraPos.y / distanceToCamera));
  pixelCameraPos.xyz -= gLightDirection * distanceToCamera;
  float4 lightUV = mul(float4(pixelCameraPos.xyz, 1), gCameraToTex);
  lightUV.xyz /= lightUV.w; 

  distanceToCamera = min(distanceToCamera, MAX_LENGTH);  
  float2 m = 0;
  float steps = 5;
  float2 d = normalize(lightUV.xy - uv) * gScale * (5. / steps);
  float2 s = uv - d * ((steps - 1) / 2);
  for (int i = 0; i < steps; ++i){
    float2 sampleValue = txBase.SampleLevel(samLinearBorder0, s, 0);
    m += float2(sampleValue.x, 1) * computeWeight(distanceToCamera, sampleValue.y);
    s += d;
  }
  return m.x / m.y;
}

float4 main(PS_IN pin) {
  float mult = 1;
  #ifdef USE_RAIN
    mult = 1 + txRain.SampleLevel(samLinearBorder0, pin.Tex, 0);
  #endif
  // return float4(gLightColor, gatherBase(pin.Tex) * mult * gIntensity);
  return float4(gLightColor, gatherSmooth(pin.Tex, pin.GetDepth()) * mult * gIntensity);
}
