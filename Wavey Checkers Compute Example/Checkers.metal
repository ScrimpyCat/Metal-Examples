//
//  Colour.metal
//  Metal Example
//
//  Created by Stefan Johnson on 4/06/2014.
//  Copyright (c) 2014 Stefan Johnson. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;


kernel void CheckerKernel(texture2d<float, access::write> Tex [[texture(0)]], constant float2 &RectScale [[buffer(0)]], const uint2 Index [[global_id]])
{
    const float4 texSize = float2(Tex.get_width(), Tex.get_height()).xyxy, scale = RectScale.xyxy;
    const uint CountX = 4;
    
    for (uint LoopX = 0; LoopX < CountX; LoopX += 2)
    {
        const uint4 i = uint4((Index.x * CountX) + LoopX, Index.y, (Index.x * CountX) + LoopX + 1, Index.y);
        const float4 posCoord = float4(i) / texSize;
        float4 pos = step(fract(posCoord / scale), 0.5);
        pos -= pos * pos.yxwz;
        
        const half3 check1 = pos.x + pos.y;
        const half3 check2 = pos.z + pos.w;
        
        Tex.write(half4(check1, 1.0), i.xy);
        Tex.write(half4(check2, 1.0), i.zw);
    }
}
