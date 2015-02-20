/*
 *  Copyright (c) 2014, Stefan Johnson
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice, this list
 *     of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice, this
 *     list of conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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

fragment half4 ColourFragment(VertexOut in [[stage_in]], texture2d<half> Texture [[texture(0)]], constant float &Time [[buffer(0)]])
{
    constexpr sampler s(address::repeat);
    
    float2 texCoord = in.texCoord;
    texCoord += sin((texCoord.yx + Time) * 6.58) * 0.04;
    
    return Texture.sample(s, texCoord);
}
