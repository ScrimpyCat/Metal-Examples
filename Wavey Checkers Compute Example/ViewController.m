//
//  ViewController.m
//  Metal Example
//
//  Created by Stefan Johnson on 4/06/2014.
//  Copyright (c) 2014 Stefan Johnson. All rights reserved.
//

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
    
    id <MTLFramebuffer>framebuffer;
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
    [RectDescriptor setVertexFormat: MTLVertexFormatFloat2 offset: offsetof(VertexData, position) vertexBufferIndex: 0 atAttributeIndex: 0];
    [RectDescriptor setVertexFormat: MTLVertexFormatFloat2 offset: offsetof(VertexData, texCoord) vertexBufferIndex: 0 atAttributeIndex: 1];
    [RectDescriptor setStride: sizeof(VertexData) instanceStepRate: 0 atVertexBufferIndex: 0];
    
    
    MTLRenderPipelineDescriptor *ColourPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    ColourPipelineDescriptor.label = @"ColourPipeline";
    [ColourPipelineDescriptor setPixelFormat: MTLPixelFormatBGRA8Unorm atIndex: MTLFramebufferAttachmentIndexColor0];
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
    [ComputeCommand executeKernelWithWorkGroupSize: WorkGroupSize workGroupCount: WorkGroupCount];
    
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
    
    id <MTLRenderCommandEncoder>RenderCommand = [CommandBuffer renderCommandEncoderWithFramebuffer: [self currentFramebuffer]];
    [RenderCommand pushDebugGroup: @"Apply wave"];
    [RenderCommand setViewport: (MTLViewport){ 0.0, 0.0, renderLayer.drawableSize.width, renderLayer.drawableSize.height, 0.0, 1.0 }];
    [RenderCommand setRenderPipelineState: colourPipeline];
    [RenderCommand setVertexBuffer: data offset: offsetof(BufferData, rect) atIndex: 0];
    [RenderCommand setFragmentTexture: checkerTexture atIndex: 0];
    [RenderCommand setFragmentBuffer: data offset: offsetof(BufferData, time[resourceIndex]) atIndex: 0];
    [RenderCommand drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];
    
    [RenderCommand popDebugGroup];
    [RenderCommand endEncoding];
    
    [CommandBuffer addScheduledPresent: [self currentDrawable]];
    
    __block dispatch_semaphore_t Semaphore = resourceSemaphore;
    [CommandBuffer addCompletedHandler: ^(id <MTLCommandBuffer>commandBuffer){
        dispatch_semaphore_signal(Semaphore);
    }];
    [CommandBuffer commit];
    
    framebuffer = nil;
    drawable = nil;
}

-(id<MTLFramebuffer>) currentFramebuffer
{
    if (!framebuffer)
    {
        id <CAMetalDrawable>Drawable = [self currentDrawable];
        if (Drawable)
        {
            MTLAttachmentDescriptor *ColourAttachment = [MTLAttachmentDescriptor attachmentDescriptorWithTexture: Drawable.texture];
            ColourAttachment.loadAction = MTLLoadActionClear;
            ColourAttachment.clearValue = MTLClearValueMakeColor(0.0, 0.0, 1.0, 1.0);
            ColourAttachment.storeAction = MTLStoreActionStore;
            
            MTLFramebufferDescriptor *Descriptor = [MTLFramebufferDescriptor framebufferDescriptorWithColorAttachment: ColourAttachment];
            
            framebuffer = [device newFramebufferWithDescriptor: Descriptor];
            framebuffer.label = @"DisplayedFramebuffer";
        }
    }
    
    return framebuffer;
}

-(id<CAMetalDrawable>) currentDrawable
{
    while (!drawable) drawable = [renderLayer newDrawable];
    return drawable;
}

-(void) dealloc
{
    [displayLink invalidate];
}

@end
