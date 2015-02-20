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

#import "ViewController.h"
#if __has_feature(modules)
@import Metal;
@import QuartzCore.CAMetalLayer;
@import GLKit.GLKMath;
#else
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <GLKit/GLKMath.h>
#endif


#define RESOURCE_COUNT 3

typedef struct {
    GLKVector2 position;
    GLKVector2 texCoord;
} __attribute__((packed)) VertexData;

typedef struct {
    VertexData _Alignas(16) rect[4];
    GLKVector2 _Alignas(16) rectScale;
    float _Alignas(16) time[RESOURCE_COUNT];
} BufferData;

@interface ViewController ()

-(void) generateCheckerTexture;

@end

@implementation ViewController
{
    id <MTLDevice>device;
    id <MTLCommandQueue>commandQueue;
    id <MTLLibrary>defaultLibrary;
    CAMetalLayer *renderLayer;
    
    MTLRenderPassDescriptor *renderPass;
    id <CAMetalDrawable>drawable;
    
    CADisplayLink *displayLink;
    
    
    id <MTLRenderPipelineState>colourPipeline;
    id <MTLComputePipelineState> checkerPipeline;
    
    id <MTLBuffer>data;
    id <MTLTexture>checkerTexture;
    
    CFTimeInterval previousTime;
    float time;
    
    dispatch_semaphore_t resourceSemaphore;
    unsigned int resourceIndex;
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    
    device = MTLCreateSystemDefaultDevice();
    
    commandQueue = [device newCommandQueue];
    defaultLibrary = [device newDefaultLibrary];
    
    
    MTLVertexDescriptor *RectDescriptor = [MTLVertexDescriptor vertexDescriptor];
    
    MTLVertexAttributeDescriptor *PositionDescriptor = [MTLVertexAttributeDescriptor new];
    PositionDescriptor.format = MTLVertexFormatFloat2;
    PositionDescriptor.offset = offsetof(VertexData, position);
    PositionDescriptor.bufferIndex = 0;
    [RectDescriptor.attributes setObject: PositionDescriptor atIndexedSubscript: 0];
    
    MTLVertexAttributeDescriptor *TexCoordDescriptor = [MTLVertexAttributeDescriptor new];
    TexCoordDescriptor.format = MTLVertexFormatFloat2;
    TexCoordDescriptor.offset = offsetof(VertexData, texCoord);
    TexCoordDescriptor.bufferIndex = 0;
    [RectDescriptor.attributes setObject: TexCoordDescriptor atIndexedSubscript: 1];
    
    MTLVertexBufferLayoutDescriptor *LayoutDescriptor = [MTLVertexBufferLayoutDescriptor new];
    LayoutDescriptor.stride = sizeof(VertexData);
    LayoutDescriptor.stepFunction = MTLVertexStepFunctionPerVertex;
    LayoutDescriptor.stepRate = 1;
    [RectDescriptor.layouts setObject: LayoutDescriptor atIndexedSubscript: 0];
    
    
    MTLRenderPipelineDescriptor *ColourPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    ColourPipelineDescriptor.label = @"ColourPipeline";
    ColourPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    [ColourPipelineDescriptor setVertexFunction: [defaultLibrary newFunctionWithName: @"ColourVertex"]];
    [ColourPipelineDescriptor setFragmentFunction: [defaultLibrary newFunctionWithName: @"ColourFragment"]];
    ColourPipelineDescriptor.vertexDescriptor = RectDescriptor;
    colourPipeline = [device newRenderPipelineStateWithDescriptor: ColourPipelineDescriptor error: NULL];
    
    checkerPipeline = [device newComputePipelineStateWithFunction: [defaultLibrary newFunctionWithName: @"CheckerKernel"] error: NULL];
    
    data = [device newBufferWithLength: sizeof(BufferData) options: MTLResourceOptionCPUCacheModeDefault];
    
    const CGSize Size = self.view.bounds.size;
    const float Scale = 63.8f;
    
    BufferData *Data = [data contents];
    *Data = (BufferData){
        .rect = { { { -1.0f, -1.0f }, { 0.0f, 0.0f } }, { { 1.0f, -1.0f }, { 1.0f, 0.0f } }, { { -1.0f, 1.0f }, { 0.0f, 1.0f } }, { { 1.0f, 1.0f }, { 1.0f, 1.0f } } },
        .rectScale = { Scale / Size.width, Scale / Size.height }
    };
    
    
    const float ContentScale = [UIScreen mainScreen].scale;
    checkerTexture = [device newTextureWithDescriptor: [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm width: Size.width * ContentScale height: Size.height * ContentScale mipmapped: NO]];
    
    [self generateCheckerTexture];
    
    renderLayer = [CAMetalLayer layer];
    renderLayer.device = device;
    renderLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    renderLayer.framebufferOnly = YES;
    renderLayer.frame = self.view.layer.frame;
    
    renderLayer.drawableSize = CGSizeMake(Size.width * ContentScale, Size.height * ContentScale);
    
    [self.view.layer addSublayer: renderLayer];
    
    self.view.opaque = YES;
    self.view.contentScaleFactor = ContentScale;
    
    resourceSemaphore = dispatch_semaphore_create(RESOURCE_COUNT);
    
    previousTime = CACurrentMediaTime();
    
    displayLink = [CADisplayLink displayLinkWithTarget: self selector: @selector(render)];
    [displayLink addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
}

-(BOOL) prefersStatusBarHidden
{
    return YES;
}

-(void) generateCheckerTexture
{
    id <MTLCommandBuffer>CommandBuffer = [commandQueue commandBuffer];
    CommandBuffer.label = @"CreateCheckerTextureCommandBuffer";
    
    MTLSize WorkGroupSize = MTLSizeMake(16, 16, 1);
    MTLSize WorkGroupCount = MTLSizeMake(checkerTexture.width / 16 / 4, checkerTexture.height / 16, 1);
    id <MTLComputeCommandEncoder>ComputeCommand = [CommandBuffer computeCommandEncoder];
    [ComputeCommand pushDebugGroup: @"Create checker texture"];
    [ComputeCommand setComputePipelineState: checkerPipeline];
    [ComputeCommand setBuffer: data offset: offsetof(BufferData, rectScale) atIndex: 0];
    [ComputeCommand setTexture: checkerTexture atIndex: 0];
    [ComputeCommand dispatchThreadgroups: WorkGroupCount threadsPerThreadgroup: WorkGroupSize];
    
    [ComputeCommand popDebugGroup];
    [ComputeCommand endEncoding];
    
    [CommandBuffer commit];
}

-(void) render
{
    dispatch_semaphore_wait(resourceSemaphore, DISPATCH_TIME_FOREVER);
    resourceIndex = (resourceIndex + 1) % RESOURCE_COUNT;
    
    CFTimeInterval Current = CACurrentMediaTime();
    CFTimeInterval DeltaTime = Current - previousTime;
    previousTime = Current;
    
    BufferData *Data = [data contents];
    time += 0.2f * DeltaTime;
    Data->time[resourceIndex] = time;
    
    id <MTLCommandBuffer>CommandBuffer = [commandQueue commandBuffer];
    CommandBuffer.label = @"RenderFrameCommandBuffer";
    
    id <MTLRenderCommandEncoder>RenderCommand = [CommandBuffer renderCommandEncoderWithDescriptor: [self currentFramebuffer]];
    [RenderCommand pushDebugGroup: @"Apply wave"];
    [RenderCommand setViewport: (MTLViewport){ 0.0, 0.0, renderLayer.drawableSize.width, renderLayer.drawableSize.height, 0.0, 1.0 }];
    [RenderCommand setRenderPipelineState: colourPipeline];
    [RenderCommand setVertexBuffer: data offset: offsetof(BufferData, rect) atIndex: 0];
    [RenderCommand setFragmentTexture: checkerTexture atIndex: 0];
    [RenderCommand setFragmentBuffer: data offset: offsetof(BufferData, time[resourceIndex]) atIndex: 0];
    [RenderCommand drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];
    
    [RenderCommand popDebugGroup];
    [RenderCommand endEncoding];
    
    [CommandBuffer presentDrawable: [self currentDrawable]];
    
    __block dispatch_semaphore_t Semaphore = resourceSemaphore;
    [CommandBuffer addCompletedHandler: ^(id <MTLCommandBuffer>commandBuffer){
        dispatch_semaphore_signal(Semaphore);
    }];
    [CommandBuffer commit];
    
    renderPass = nil;
    drawable = nil;
}

-(MTLRenderPassDescriptor*) currentFramebuffer
{
    if (!renderPass)
    {
        id <CAMetalDrawable>Drawable = [self currentDrawable];
        if (Drawable)
        {
            renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
            renderPass.colorAttachments[0].texture = Drawable.texture;
            renderPass.colorAttachments[0].loadAction = MTLLoadActionDontCare;
            renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        }
    }
    
    return renderPass;
}

-(id<CAMetalDrawable>) currentDrawable
{
    while (!drawable) drawable = [renderLayer nextDrawable];
    return drawable;
}

-(void) dealloc
{
    [displayLink invalidate];
}

@end
