float4 main(PS_IN pin){
  const float2 cOffsets[13] = {
    float2(-1.f, 1.f), float2(1.f, 1.f),
    float2(-1.f, -1.f), float2(1.f, -1.f),
    float2(-2.f, 2.f), float2(0.f, 2.f), float2(2.f, 2.f),
    float2(-2.f, 0.f), float2(0.f, 0.f), float2(2.f, 0.f),
    float2(-2.f, -2.f), float2(0.f, -2.f), float2(2.f, -2.f)
  };

  const float cWeights[13] = {
    0.125f, 0.125f,
    0.125f, 0.125f,
    0.0555555f, 0.0555555f, 0.0555555f,
    0.0555555f, 0.0555555f, 0.0555555f,
    0.0555555f, 0.0555555f, 0.0555555f
  };

  float3 ret = 0;
  #if PASS_INDEX == 1 
    float limit = txLimit.SampleLevel(samLinear, pin.Tex, 0);
  #endif

  for (int i = 0; i < 13; i++) {
    float3 s = txInput.SampleLevel(samLinearBorder0, pin.Tex + cOffsets[i] * gTexSizeInv, 0).rgb;
    #if PASS_INDEX == 1 
      float x = max(s.r, max(s.g, s.b));
      if (x > limit) {
        s *= limit / x;
      }
    #endif
    ret += s * cWeights[i];
  }
  return float4(ret, 1);
}
