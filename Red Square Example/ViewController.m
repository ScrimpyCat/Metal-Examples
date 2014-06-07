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
    
    
    id <MTLRenderPipelineState>colourPipeline;
    
    id <MTLBuffer>rect;
    id <MTLBuffer>modelViewProjection;
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    
    device = MTLCreateSystemDefaultDevice();
    
    commandQueue = [device newCommandQueue];
    defaultLibrary = [device newDefaultLibrary];
    
    
    MTLRenderPipelineDescriptor *ColourPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    ColourPipelineDescriptor.label = @"ColourPipeline";
    [ColourPipelineDescriptor setPixelFormat: MTLPixelFormatBGRA8Unorm atIndex: MTLFramebufferAttachmentIndexColor0];
    [ColourPipelineDescriptor setVertexFunction: [defaultLibrary newFunctionWithName: @"ColourVertex"]];
    [ColourPipelineDescriptor setFragmentFunction: [defaultLibrary newFunctionWithName: @"ColourFragment"]];
    colourPipeline = [device newRenderPipelineStateWithDescriptor: ColourPipelineDescriptor error: NULL];
    
    
    const CGSize Size = self.view.bounds.size;
    GLKMatrix4 Mat = GLKMatrix4MakeOrtho(0.0f, Size.width, 0.0f, Size.height, -1.0f, 1.0f);
    modelViewProjection = [device newBufferWithBytes: &Mat length: sizeof(GLKMatrix4) options: MTLResourceOptionCPUCacheModeDefault];

    
    rect = [device newBufferWithBytes: &(VertexData[4]){ { 0.0f, 0.0f }, { 100.0f, 0.0f }, { 0.0f, 100.0f }, { 100.0f, 100.0f } } length: sizeof(VertexData[4]) options: MTLResourceOptionCPUCacheModeDefault];
    rect.label = @"Square";
    
    
    renderLayer = [CAMetalLayer layer];
    renderLayer.device = device;
    renderLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    renderLayer.framebufferOnly = YES;
    renderLayer.frame = self.view.layer.frame;
    
    const float ContentScale = [UIScreen mainScreen].scale;
    renderLayer.drawableSize = CGSizeMake(Size.width * ContentScale, Size.height * ContentScale);
    
    [self.view.layer addSublayer: renderLayer];
    
    self.view.opaque = YES;
    self.view.contentScaleFactor = ContentScale;
    
    
    displayLink = [CADisplayLink displayLinkWithTarget: self selector: @selector(render)];
    [displayLink addToRunLoop: [NSRunLoop currentRunLoop] forMode: NSDefaultRunLoopMode];
}

-(BOOL) prefersStatusBarHidden
{
    return YES;
}

-(void) render
{
    id <MTLCommandBuffer>CommandBuffer = [commandQueue commandBuffer];
    CommandBuffer.label = @"RenderFrameCommandBuffer";
    
    id <MTLRenderCommandEncoder>RenderCommand = [CommandBuffer renderCommandEncoderWithFramebuffer: [self currentFramebuffer]];
    [RenderCommand pushDebugGroup: @"Draw square"];
    [RenderCommand setViewport: (MTLViewport){ 0.0, 0.0, renderLayer.drawableSize.width, renderLayer.drawableSize.height, 0.0, 1.0 }];
    [RenderCommand setRenderPipelineState: colourPipeline];
    [RenderCommand setVertexBuffer: rect offset: 0 atIndex: 0];
    [RenderCommand setVertexBuffer: modelViewProjection offset: 0 atIndex: 1];
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
