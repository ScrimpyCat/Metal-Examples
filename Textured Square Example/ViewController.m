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
    
    MTLRenderPassDescriptor *renderPass;
    id <CAMetalDrawable>drawable;
    
    CADisplayLink *displayLink;
    
    
    id <MTLRenderPipelineState>colourPipeline;
    
    id <MTLBuffer>rect;
    id <MTLBuffer>modelViewProjection;
    id <MTLTexture>texture;
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    
    device = MTLCreateSystemDefaultDevice();
    
    commandQueue = [device newCommandQueue];
    defaultLibrary = [device newDefaultLibrary];
    
    
    MTLRenderPipelineDescriptor *ColourPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    ColourPipelineDescriptor.label = @"ColourPipeline";
    ColourPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    [ColourPipelineDescriptor setVertexFunction: [defaultLibrary newFunctionWithName: @"ColourVertex"]];
    [ColourPipelineDescriptor setFragmentFunction: [defaultLibrary newFunctionWithName: @"ColourFragment"]];
    colourPipeline = [device newRenderPipelineStateWithDescriptor: ColourPipelineDescriptor error: NULL];
    
    
    const CGSize Size = self.view.bounds.size;
    GLKMatrix4 Mat = GLKMatrix4MakeOrtho(0.0f, Size.width, 0.0f, Size.height, -1.0f, 1.0f);
    modelViewProjection = [device newBufferWithBytes: &Mat length: sizeof(GLKMatrix4) options: MTLResourceOptionCPUCacheModeDefault];

    
    rect = [device newBufferWithBytes: &(VertexData[4]){ { { 0.0f, 0.0f }, { 0.0f, 0.0f } }, { { 100.0f, 0.0f }, { 1.0f, 0.0f } }, { { 0.0f, 100.0f }, { 0.0f, 1.0f } }, { { 100.0f, 100.0f }, { 1.0f, 1.0f } } } length: sizeof(VertexData[4]) options: MTLResourceOptionCPUCacheModeDefault];
    rect.label = @"Square";
    
    
    MTLTextureDescriptor *TextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatRGBA8Unorm width: 2 height: 2 mipmapped: NO];
    texture = [device newTextureWithDescriptor: TextureDescriptor];
    [texture replaceRegion: MTLTextureRegionMake2D(0, 0, 2, 2) mipmapLevel: 0 withBytes: (uint8_t[]){
        255,0,0,255,    0,255,0,255,
        0,0,255,255,    0,0,0,255
    } bytesPerRow: 8];
    
    
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
    
    id <MTLRenderCommandEncoder>RenderCommand = [CommandBuffer renderCommandEncoderWithDescriptor: [self currentFramebuffer]];
    [RenderCommand pushDebugGroup: @"Draw square"];
    [RenderCommand setViewport: (MTLViewport){ 0.0, 0.0, renderLayer.drawableSize.width, renderLayer.drawableSize.height, 0.0, 1.0 }];
    [RenderCommand setRenderPipelineState: colourPipeline];
    [RenderCommand setVertexBuffer: rect offset: 0 atIndex: 0];
    [RenderCommand setVertexBuffer: modelViewProjection offset: 0 atIndex: 1];
    [RenderCommand setFragmentTexture: texture atIndex: 0];
    [RenderCommand drawPrimitives: MTLPrimitiveTypeTriangleStrip vertexStart: 0 vertexCount: 4];
    
    [RenderCommand popDebugGroup];
    [RenderCommand endEncoding];
    
    [CommandBuffer presentDrawable: [self currentDrawable]];
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
            renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
            renderPass.colorAttachments[0].clearValue = MTLClearValueMakeColor(0.0, 0.0, 1.0, 1.0);
            renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        }
    }
    
    return renderPass;
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
