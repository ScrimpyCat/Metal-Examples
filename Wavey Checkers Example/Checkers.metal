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

fragment half4 CheckerFragment(VertexOut in [[stage_in]], constant float2 &RectScale [[buffer(0)]])
{
    float2 pos = step(fract(in.posCoord / RectScale), 0.5);
    pos -= pos.x * pos.y;
    
    half3 check = pos.x + pos.y;
    
    return half4(check, 1.0);
}
