//
//  Shader.metal
//  ShaderPlayground
//
//  Created by TakatsuYouichi on 2018/04/15.
//  Copyright © 2018年 TakatsuYouichi. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 pos [[position]];
};

vertex VertexOut vertexShader(
  const device packed_float2* vertex_array [[ buffer(0) ]],
  unsigned int vid [[ vertex_id ]])
{
  VertexOut v;
  v.pos = float4(vertex_array[vid], 1.0, 1.0);
  return v;
}

float circle(float2 p)
{
  float c = length(p) - 0.5;
  return c;
}

float star(float2 p, int waves, float time, float amp)
{
  float2 c = p - 0.5;
  float a = atan2(c.y, c.x) + time;
  return step(length(c) + amp*sin(waves*a) + 0.1, 0.5);
}

fragment half4 fragmentShader(
  VertexOut fragmentIn [[stage_in]],
  constant float2 &res[[buffer(0)]],
  constant float &time[[buffer(1)]],
  constant float &vol[[buffer(2)]],
  constant packed_float3 &accel[[buffer(3)]])
{
  float2 p = fragmentIn.pos.xy/min(res.x, res.y);
    p.x += sin(p.y * 20.0) * 0.015;
    float2 p1 = p + float2(accel[0], -accel[1]);
  float size = 0.1 * vol;
  return half4(star(p1, 3, time, size),
               star(p1, 5, sin(time) + vol, size),
               star(p1, 7, 1.7*time - vol, size),
               1.0);
}
