float3 toSrgb(float3 linearRGB) {  
	bool3 cutoff = linearRGB < 0.0031308;
	float3 higher = 1.055 * pow(max(linearRGB, 0), 1. / 2.4) - 0.055;
	float3 lower = linearRGB * 12.92;
	return lerp(higher, lower, cutoff ? 1 : 0);
}

float4 main(PS_IN pin) {
	float3 colLinear = txHDR.SampleLevel(samLinear, pin.Tex, 0).rgb;
	float3 col = toSrgb(colLinear * gBrightness);
	// if (gBrightness == 0) col = colLinear;
	// if (any(colLinear > 5e3)) {
	// 	col = float3(1, 0, 0);
	// }
  // col.rgb *= 1 + max(0, col.rgb - 1); 
	// if (any(col > 10)) {
	// 	col = float3(1, 0, 0);
	// } else if (any(col > 5)) {
	// 	col = float3(0, 1, 0);
	// }
  return float4(col, 1);
}