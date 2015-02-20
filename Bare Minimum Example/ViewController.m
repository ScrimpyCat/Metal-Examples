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
            renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 1.0, 1.0);
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
