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
#else
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#endif

@interface ViewController ()


@end

@implementation ViewController
{
    id <MTLDevice>device;
    id <MTLCommandQueue>commandQueue;
    CAMetalLayer *renderLayer;
    
    MTLRenderPassDescriptor *renderPass;
    id <CAMetalDrawable>drawable;
    
    CADisplayLink *displayLink;
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    
    device = MTLCreateSystemDefaultDevice();
    
    commandQueue = [device newCommandQueue];
    
    renderLayer = [CAMetalLayer layer];
    renderLayer.device = device;
    renderLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    renderLayer.framebufferOnly = YES;
    renderLayer.frame = self.view.layer.frame;
    
    const CGSize Size = self.view.bounds.size;
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
