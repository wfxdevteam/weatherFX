float gatherBase(float2 uv){
  return txBase.SampleLevel(samLinearBorder0, uv, 0).x;
}

float4 main(PS_IN pin) {  
  return float4(gFogColor, 0.1 * gatherBase(pin.Tex));
}
