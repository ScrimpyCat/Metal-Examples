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


typedef struct {
    GLKVector2 position;
    GLKVector2 texCoord;
} __attribute__((packed)) VertexData;

@interface ViewController ()
            

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
    
    
    id <MTLRenderPipelineState>colourPipeline, checkerPipeline;
    
    id <MTLBuffer>rect, rectScale, time;
    id <MTLFramebuffer>createTextureFramebuffer;
    id <MTLTexture>checkerTexture;
    
    CFTimeInterval previousTime;
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
    
    MTLRenderPipelineDescriptor *CheckerPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    CheckerPipelineDescriptor.label = @"CheckerPipeline";
    [CheckerPipelineDescriptor setPixelFormat: MTLPixelFormatBGRA8Unorm atIndex: MTLFramebufferAttachmentIndexColor0];
    [CheckerPipelineDescriptor setVertexFunction: [defaultLibrary newFunctionWithName: @"CheckerVertex"]];
    [CheckerPipelineDescriptor setFragmentFunction: [defaultLibrary newFunctionWithName: @"CheckerFragment"]];
    CheckerPipelineDescriptor.vertexDescriptor = RectDescriptor;
    checkerPipeline = [device newRenderPipelineStateWithDescriptor: CheckerPipelineDescriptor error: NULL];
    
    
    rect = [device newBufferWithBytes: &(VertexData[4]){ { { -1.0f, -1.0f }, { 0.0f, 0.0f } }, { { 1.0f, -1.0f }, { 1.0f, 0.0f } }, { { -1.0f, 1.0f }, { 0.0f, 1.0f } }, { { 1.0f, 1.0f }, { 1.0f, 1.0f } } } length: sizeof(VertexData[4]) options: MTLResourceOptionCPUCacheModeDefault];
    rect.label = @"FullScreen";
    
    time = [device newBufferWithLength: sizeof(float) options: MTLResourceOptionCPUCacheModeDefault];
    
    const CGSize Size = self.view.bounds.size;
    const float Scale = 63.8f;
    rectScale = [device newBufferWithBytes: &(GLKVector2){ Scale / Size.width, Scale / Size.height } length: sizeof(GLKVector2) options: MTLResourceOptionCPUCacheModeDefault];
    rectScale.label = @"RectScale";
    
    
    const float ContentScale = [UIScreen mainScreen].scale;
    checkerTexture = [device newTextureWithDescriptor: [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm width: Size.width * ContentScale height: Size.height * ContentScale mipmapped: NO]];
    
    MTLAttachmentDescriptor *ColourAttachment = [MTLAttachmentDescriptor attachmentDescriptorWithTexture: checkerTexture];
    ColourAttachment.loadAction = MTLLoadActionClear;
    ColourAttachment.clearValue = MTLClearValueMakeColor(0.0, 0.0, 1.0, 1.0);
    ColourAttachment.storeAction = MTLStoreActionStore;
    
    MTLFramebufferDescriptor *Descriptor = [MTLFramebufferDescriptor framebufferDescriptorWithColorAttachment: ColourAttachment];
    
    createTextureFramebuffer = [device newFramebufferWithDescriptor: Descriptor];
    
    
    
    renderLayer = [CAMetalLayer layer];
    renderLayer.device = device;
    renderLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    renderLayer.framebufferOnly = YES;
    renderLayer.frame = self.view.layer.frame;
    
    renderLayer.drawableSize = CGSizeMake(Size.width * ContentScale, Size.height * ContentScale);
    
    [self.view.layer addSublayer: renderLayer];
    
    self.view.opaque = YES;
    self.view.contentScaleFactor = ContentScale;
    
    previousTime = CACurrentMediaTime();
    
    displayLink = [CADisplayLink displayLinkWithTarget: self selector: @selector(render)];
    [displayLink addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
}

-(BOOL) prefersStatusBarHidden
{
    return YES;
}

-(void) render
{
    CFTimeInterval Current = CACurrentMediaTime();
    CFTimeInterval DeltaTime = Current - previousTime;
    previousTime = Current;
    
    float *Time = [time contents];
    *Time += 0.2f * DeltaTime;
    
    id <MTLCommandBuffer>CommandBuffer = [commandQueue commandBuffer];
    CommandBuffer.label = @"RenderFrameCommandBuffer";
    
    id <MTLRenderCommandEncoder>RenderCommand = [CommandBuffer renderCommandEncoderWithFramebuffer: createTextureFramebuffer];
    [RenderCommand pushDebugGroup: @"Create checker texture"];
    [RenderCommand setViewport: (MTLViewport){ 0.0, 0.0, renderLayer.drawableSize.width, renderLayer.drawableSize.height, 0.0, 1.0 }];
    [RenderCommand setRenderPipelineState: checkerPipeline];
    [RenderCommand setVertexBuffer: rect offset: 0 atIndex: 0];
    [RenderCommand setFragmentBuffer: rectScale offset: 0 atIndex: 0];
    [RenderCommand drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];
    
    [RenderCommand popDebugGroup];
    [RenderCommand endEncoding];
    
    RenderCommand = [CommandBuffer renderCommandEncoderWithFramebuffer: [self currentFramebuffer]];
    [RenderCommand pushDebugGroup: @"Apply wave"];
    [RenderCommand setViewport: (MTLViewport){ 0.0, 0.0, renderLayer.drawableSize.width, renderLayer.drawableSize.height, 0.0, 1.0 }];
    [RenderCommand setRenderPipelineState: colourPipeline];
    [RenderCommand setVertexBuffer: rect offset: 0 atIndex: 0];
    [RenderCommand setFragmentTexture: checkerTexture atIndex: 0];
    [RenderCommand setFragmentBuffer: time offset: 0 atIndex: 0];
    [RenderCommand drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];
    
    [RenderCommand popDebugGroup];
    [RenderCommand endEncoding];
    
    [CommandBuffer addScheduledPresent: [self currentDrawable]];
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
