//
// visual improvements that can be made:
// - when calculating sun lighting along ray, check if point is in shadow (quite expensive)
// - currently fog only reacts to sun. possibly add contribution of other light sources in the scene
//
//

float4 main(PS_IN pin) {
  float depthValue = pin.GetDepth();
  float4 posW = mul(float4(pin.Tex, depthValue, 1), gTexToCamera);
  posW.xyz /= posW.w;

  //
  // figure out ray distance, direction, and origin
  // relative to track sea level
  float t = length(posW.xyz);
  float3 rd = posW.xyz / t;
  float3 ro = gCameraPosition - float3(0.0, gHeightOffset, 0.0);

  float a = gDensity;
  float b = gFalloff;
  float fogAmount = 0.0;

  //
  // see: https://iquilezles.org/articles/fog/
  // calculates integral of density along ray
  // avoid division by zero when ray is parallel to ground plane
  if (abs(rd.y) < 0.001) {
      fogAmount = a * exp(-ro.y * b) * t;
  } else {
      fogAmount = (a / b) * exp(-ro.y * b) * (1.0 - exp(-t * rd.y * b)) / rd.y;
  }

  // see: https://en.wikipedia.org/wiki/Beer%E2%80%93Lambert_law
  // light decays exponentially as it travels through a volume
  float alpha = saturate(1.0 - exp(-fogAmount * gIntensity));

  // also from https://iquilezles.org/articles/fog/
  // directional in-scattering
  // additively blends sun's color based on how closely we are looking at it to fake mie scattering
  float sunAmount = max(dot(rd, gSunDirection), 0.0);
  float3 baseFogColor = pin.GetFogColor();
  float3 fogColor = baseFogColor + (gSunColor * pow(sunAmount, gSunScattering));

  //
  // clip pixels with very low alpha
  // avoids unnecessary overdraw and can save some performance
  if (USE_LINEAR_COLOR_SPACE) {
    alpha = toLinearColorSpace(alpha).r;
    clip(depthValue == 1.0 ? -1.0 : alpha - 0.001);
  } else {
    clip(alpha - 0.001);
  }

  return float4(fogColor, alpha);
}