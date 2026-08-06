//
//  JXLSystemImage.mm
//  JxclCoder [https://github.com/awxkee/jxl-coder-swift]
//
//  Created by Radzivon Bartoshyk on 27/08/2023.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#import "JXLSystemImage.hpp"
#import <Accelerate/Accelerate.h>

@implementation JXLSystemImage (JXLColorData)

-(bool)unpremultiply:(nonnull unsigned char*)data width:(NSInteger)width height:(NSInteger)height {
    vImage_Buffer src = {
        .data = (void*)data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4)
    };

    vImage_Buffer dest = {
        .data = data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4)
    };
    vImage_Error vEerror = vImageUnpremultiplyData_RGBA8888(&src, &dest, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }
    return true;
}

-(bool)unpremultiply16:(nonnull uint16_t*)data width:(NSInteger)width height:(NSInteger)height {
    vImage_Buffer src = {
        .data = (void*)data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4 * sizeof(uint16_t))
    };

    vImage_Buffer dest = {
        .data = (void*)data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4 * sizeof(uint16_t))
    };
    vImage_Error vEerror = vImageUnpremultiplyData_RGBA16U(&src, &dest, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }
    return true;
}

-(bool)unpremultiplyFloat16:(nonnull uint16_t*)data width:(NSInteger)width height:(NSInteger)height {
    vImage_Buffer src = {
        .data = (void*)data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4 * sizeof(uint16_t))
    };

    vImage_Buffer dest = {
        .data = (void*)data,
        .width = static_cast<vImagePixelCount>(width),
        .height = static_cast<vImagePixelCount>(height),
        .rowBytes = static_cast<vImagePixelCount>(width * 4 * sizeof(uint16_t))
    };
    vImage_Error vEerror = vImageUnpremultiplyData_RGBA16F(&src, &dest, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        return false;
    }
    return true;
}

#if TARGET_OS_OSX

-(nullable CGImageRef)makeCGImage {
    CGImageRef imageRef = [self CGImageForProposedRect:nil context:nil hints:nil];
    return imageRef;
}

- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize bitsPerSample:(nonnull int*)bitsPerSample {
    bool dummyFloat = false;
    return [self jxlRGBAPixels:buffer width:xSize height:ySize bitsPerSample:bitsPerSample isFloat:&dummyFloat];
}

- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize bitsPerSample:(nonnull int*)bitsPerSample isFloat:(nonnull bool*)isFloat {
    std::vector<uint8_t> dummyIcc;
    return [self jxlRGBAPixels:buffer width:xSize height:ySize bitsPerSample:bitsPerSample isFloat:isFloat iccProfile:&dummyIcc];
}

- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize bitsPerSample:(nonnull int*)bitsPerSample isFloat:(nonnull bool*)isFloat iccProfile:(nonnull std::vector<uint8_t>*)iccProfile {
    *isFloat = false;
    *bitsPerSample = 8;
    iccProfile->clear();
    return [self jxlRGBAPixels:buffer width:xSize height:ySize];
}

- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize {
    CGImageRef imageRef = [self makeCGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    int stride = (int)4 * (int)width * sizeof(uint8_t);
    buffer.resize(stride * height);
    *xSize = (int)width;
    *ySize = (int)height;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = (int)kCGImageAlphaPremultipliedLast | (int)kCGImageByteOrderDefault;

    CGContextRef targetContext = CGBitmapContextCreate(buffer.data(), width, height, 8, stride, colorSpace, bitmapInfo);

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext: [NSGraphicsContext graphicsContextWithCGContext:targetContext flipped:FALSE]];

    [self drawInRect: NSMakeRect(0, 0, width, height)
            fromRect: NSZeroRect
           operation: NSCompositingOperationCopy
            fraction: 1.0];

    [NSGraphicsContext restoreGraphicsState];

    CGContextRelease(targetContext);
    CGColorSpaceRelease(colorSpace);

    if (![self unpremultiply:buffer.data() width:width height:height]) {
        return false;
    }

    return true;
}
#else
- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize bitsPerSample:(nonnull int*)bitsPerSample {
    bool dummyFloat = false;
    return [self jxlRGBAPixels:buffer width:xSize height:ySize bitsPerSample:bitsPerSample isFloat:&dummyFloat];
}

- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize bitsPerSample:(nonnull int*)bitsPerSample isFloat:(nonnull bool*)isFloatRes {
    std::vector<uint8_t> dummyIcc;
    return [self jxlRGBAPixels:buffer width:xSize height:ySize bitsPerSample:bitsPerSample isFloat:isFloatRes iccProfile:&dummyIcc];
}

- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize bitsPerSample:(nonnull int*)bitsPerSample isFloat:(nonnull bool*)isFloatRes iccProfile:(nonnull std::vector<uint8_t>*)iccProfile {
    *isFloatRes = false;
    iccProfile->clear();
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    size_t bpc = CGImageGetBitsPerComponent(imageRef);
    if (bpc > 8) {
        bpc = 16;
    } else {
        bpc = 8;
    }
    *bitsPerSample = (int)bpc;
    *xSize = (int)width;
    *ySize = (int)height;

    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
    bool releaseColorSpace = false;
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        releaseColorSpace = true;
    }

    if (bpc == 16) {
        buffer.resize(height * width * 4 * sizeof(uint16_t));
        NSUInteger bytesPerPixel = 8;
        NSUInteger bytesPerRow = bytesPerPixel * width;
        NSUInteger bitsPerComponent = 16;
        
        CGBitmapInfo bitmapInfo = (int)kCGImageAlphaPremultipliedLast | (int)kCGBitmapByteOrder16Host;
        bool isFloat = ((CGImageGetBitmapInfo(imageRef) & kCGBitmapFloatComponents) != 0);
        if (isFloat) {
            bitmapInfo |= (int)kCGBitmapFloatComponents;
        }
        
        CGContextRef context = CGBitmapContextCreate(buffer.data(), width, height,
                                                     bitsPerComponent, bytesPerRow, colorSpace,
                                                     bitmapInfo);
        if (context == NULL && !isFloat) {
            isFloat = true;
            bitmapInfo |= (int)kCGBitmapFloatComponents;
            context = CGBitmapContextCreate(buffer.data(), width, height,
                                            bitsPerComponent, bytesPerRow, colorSpace,
                                            bitmapInfo);
        }
        
        if (context == NULL) {
            if (releaseColorSpace) { CGColorSpaceRelease(colorSpace); }
            return false;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
        if (releaseColorSpace) { CGColorSpaceRelease(colorSpace); }

        if (isFloat) {
            *isFloatRes = true;
            if (![self unpremultiplyFloat16:(uint16_t*)buffer.data() width:width height:height]) {
                return false;
            }
        } else {
            if (![self unpremultiply16:(uint16_t*)buffer.data() width:width height:height]) {
                return false;
            }
        }
        return true;
    } else {
        buffer.resize(height * width * 4 * sizeof(uint8_t));
        NSUInteger bytesPerPixel = 4;
        NSUInteger bytesPerRow = bytesPerPixel * width;
        NSUInteger bitsPerComponent = 8;
        CGContextRef context = CGBitmapContextCreate(buffer.data(), width, height,
                                                     bitsPerComponent, bytesPerRow, colorSpace,
                                                     (int)kCGImageAlphaPremultipliedLast | (int)kCGImageByteOrderDefault);
        if (context == NULL) {
            if (releaseColorSpace) { CGColorSpaceRelease(colorSpace); }
            return false;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
        if (releaseColorSpace) { CGColorSpaceRelease(colorSpace); }

        if (![self unpremultiply:buffer.data() width:width height:height]) {
            return false;
        }
        return true;
    }
}

- (bool)jxlRGBAPixels:(std::vector<uint8_t>&)buffer width:(nonnull int*)xSize height:(nonnull int*)ySize {
    CGImageRef imageRef = [self CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    buffer.resize(height * width * 4 * sizeof(uint8_t));
    *xSize = (int)width;
    *ySize = (int)height;
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(buffer.data(), width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 (int)kCGImageAlphaPremultipliedLast | (int)kCGImageByteOrderDefault);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);

    if (![self unpremultiply:buffer.data() width:width height:height]) {
        return false;
    }

    return true;
}
#endif
@end
