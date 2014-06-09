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

vertex VertexOut ColourVertex(VertexData Vertices [[stage_in]], constant float4x4 &ModelViewProjection [[buffer(1)]])
{
    VertexOut out;
    out.position = ModelViewProjection * float4(Vertices.position, 0.0, 1.0);
    out.texCoord = Vertices.texCoord;
    return out;
}

fragment half4 ColourFragment(VertexOut in [[stage_in]], texture2d<half> Texture [[texture(0)]])
{
    constexpr sampler s;
    return Texture.sample(s, in.texCoord);
}
