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
    
    id <MTLFramebuffer>framebuffer;
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
    
    id <MTLRenderCommandEncoder>RenderCommand = [CommandBuffer renderCommandEncoderWithFramebuffer: [self currentFramebuffer]];
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
