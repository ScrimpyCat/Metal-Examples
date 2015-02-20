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


kernel void CheckerKernel(texture2d<half, access::write> Tex [[texture(0)]], constant float2 &RectScale [[buffer(0)]], const uint2 Index [[thread_position_in_grid]])
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
