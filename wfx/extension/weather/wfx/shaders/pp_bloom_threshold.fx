#if PASS == 1
  float threshold(float v) {
    return saturate(v * gBrightnessMult - 1);
  }
#endif

float main(PS_IN pin){
  float r = 0;
  [unroll]
  for (int i = 0; i < 16; i++) {
    float v;
    #if PASS == 1
      v = threshold(dot(txInput.SampleLevel(samLinearBorder0, pin.Tex, 0, int2(i - 8, 0)).rgb, 1/3.));
    #else
      v = txInput.SampleLevel(samLinearBorder0, pin.Tex, 0, int2(0, i - 8));
    #endif
    r += v;
  }
  #if PASS == 2
    return (10 + 100 * r.x) * gBrightnessMult;
  #endif
  return r.x;
}
