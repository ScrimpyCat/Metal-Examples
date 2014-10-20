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
    float2 position;
} VertexData;

typedef struct {
    float4 position [[position]];
} VertexOut;

vertex VertexOut ColourVertex(const device VertexData *Vertices [[buffer(0)]], constant float4x4 &ModelViewProjection [[buffer(1)]], const uint index [[vertex_id]])
{
    VertexOut out;
    out.position = ModelViewProjection * float4(Vertices[index].position, 0.0, 1.0);
    return out;
}

fragment half4 ColourFragment(void)
{
    return half4(1.0, 0.0, 0.0, 1.0);
}
