//
//  Colour.metal
//  Metal Example
//
//  Created by Stefan Johnson on 4/06/2014.
//  Copyright (c) 2014 Stefan Johnson. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;


typedef struct {
    float2 position [[attribute(0)]];
} VertexData;

typedef struct {
    float4 position [[position]];
    float2 posCoord;
} VertexOut;

vertex VertexOut CheckerVertex(VertexData Vertices [[stage_in]])
{
    VertexOut out;
    out.position = float4(Vertices.position, 0.0, 1.0);
    out.posCoord = (out.position.xy + 1.0) / 2.0;
    return out;
}

fragment half4 CheckerFragment(VertexOut in [[stage_in]], const global float2 *RectScale [[buffer(0)]])
{
    float2 pos = step(fract(in.posCoord / *RectScale), 0.5);
    pos -= pos.x * pos.y;
    
    half3 check = pos.x + pos.y;
    
    return half4(check, 1.0);
}
