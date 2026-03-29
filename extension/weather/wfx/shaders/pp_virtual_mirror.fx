#include "pp_tonemapping.hlsl"

#ifndef BICUBIC_SAMPLER
  #define BICUBIC_SAMPLER samLinearBorder0
#endif

float4 cubic(float v){
    float4 n = float4(1, 2, 3, 4) - v;
    float4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4 * s.x;
    float z = s.z - 4 * s.y + 6 * s.x;
    float w = 6 - x - y - z;
    return float4(x, y, z, w);
}

float4 sampleBicubic(Texture2D tex, float2 texCoords, float level, float2 dim){
  texCoords = texCoords * dim - 0.5;  
  float2 fxy = frac(texCoords);
  float4 xcubic = cubic(fxy.x);
  float4 ycubic = cubic(fxy.y);
  float4 c = (texCoords - fxy).xxyy + float2(-0.5, 1.5).xyxy;    
  float4 s = float4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
  float4 offset = (c + float4(xcubic.yw, ycubic.yw) / s) / dim.xxyy;  
  float4 sample0 = tex.SampleLevel(BICUBIC_SAMPLER, offset.xz, level);
  float4 sample1 = tex.SampleLevel(BICUBIC_SAMPLER, offset.yz, level);
  float4 sample2 = tex.SampleLevel(BICUBIC_SAMPLER, offset.xw, level);
  float4 sample3 = tex.SampleLevel(BICUBIC_SAMPLER, offset.yw, level);
  float sx = s.x / (s.x + s.y);
  float sy = s.z / (s.z + s.w);
  return lerp(lerp(sample3, sample2, sx), lerp(sample1, sample0, sx), sy);
}

float3 __wfxfn_toSrgb(float3 linearRGB) {  
	bool3 cutoff = linearRGB < 0.0031308;
	float3 higher = 1.055 * pow(max(linearRGB, 0), 1. / 2.4) - 0.055;
	float3 lower = linearRGB * 12.92;
	return lerp(higher, lower, cutoff ? 1 : 0);
}

float4 sampleBicubic(Texture2D tex, float2 texCoords, float level){
  uint2 dim;
  uint sampleCount; 
  tex.GetDimensions(level, dim.x, dim.y, sampleCount); 
  return sampleBicubic(tex, texCoords, level, (float2)dim);
}

float4 main(float4 col, float2 uv) {
  if (FEATURE_USE_GLARE) {
    uint2 dim;
    uint sampleCount; 
    txInput.GetDimensions(0, dim.x, dim.y, sampleCount); 

    dim /= 4;
    float level = 2;
    while (dim.y > 2) {
      float3 glare = sampleBicubic(txInput, uv, level, (float2)dim).rgb;
      col.rgb += 0.00001 * glare;
      ++level;
      dim /= 2;
    }
  }

  if (USE_LINEAR_COLOR_SPACE) {
    col.rgb = __wfxfn_toSrgb(col.rgb * gGammaFixBrightnessOffset);
  }

  float4 adj = mul(float4(col.rgb, 1), gMatHDR);
  col.rgb = max(0, adj.rgb / adj.w);
  col.rgb *= gExposure; 
  col.rgb = __wfxfn_applyTonemapping(col.rgb, 0);
  col.rgb = pow(max(col.rgb, 0), gGamma);
  col.rgb = mul(float4(col.rgb, 1), gMatLDR).rgb;
  // col.rgb = 1 - col.rgb;
  return col;
}