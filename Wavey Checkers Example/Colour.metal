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
    float2 texCoord [[attribute(1)]];
} VertexData;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} VertexOut;

vertex VertexOut ColourVertex(VertexData Vertices [[stage_in]])
{
    VertexOut out;
    out.position = float4(Vertices.position, 0.0, 1.0);
    out.texCoord = Vertices.texCoord;
    return out;
}

fragment half4 ColourFragment(VertexOut in [[stage_in]], texture2d<half> Texture [[texture(0)]], const global float *Time [[buffer(0)]])
{
    constexpr sampler s(address::repeat);
    
    float2 texCoord = in.texCoord;
    texCoord += sin((texCoord.yx + *Time) * 6.58) * 0.04;
    
    return Texture.sample(s, texCoord);
}
