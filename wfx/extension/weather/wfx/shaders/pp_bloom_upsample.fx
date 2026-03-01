float4 main(PS_IN pin){
  const float2 cOffsets[9] = {
    float2(-1, 1), float2(0, 1), float2(1, 1),
    float2(-1, 0), float2(0, 0), float2(1, 0),
    float2(-1, -1), float2(0, -1), float2(1, -1)
  };

  const float cWeights[9] = {
    0.0625, 0.125, 0.0625,
    0.125, 0.25, 0.125,
    0.0625, 0.125, 0.0625
  };

  float3 ret = 0;
  for (int i = 0; i < 9; i++) {
    ret += cWeights[i] * txInput.SampleLevel(samLinearClamp, pin.Tex + cOffsets[i] * gTexSizeInv, 0).rgb;
  }
  // return 0;
  return float4(ret, 0);
}
