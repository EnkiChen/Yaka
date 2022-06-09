//
//  PixelBufferTool.m
//  Yaka
//
//  Created by Enki on 2021/7/23.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "PixelBufferTools.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#include "libyuv.h"
#include "ColorToolbox.h"

@implementation PixelBufferTools

- (void)writeToFile:(CVImageBufferRef)pixelBuffer {
    FILE *fd = 0;
    const OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if ( pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ) {
        const size_t width = CVPixelBufferGetWidth(pixelBuffer);
        
        const uint8_t* srcY = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
        const size_t srcYStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        const size_t srcYHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        
        for (int i = 0; i < srcYHeight; i++) {
            fwrite(srcY + srcYStride * i, 1, width, fd);
        }
        
        const uint8_t* srcUV = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
        const size_t srcUVStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
        const size_t srcUVHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        
        for (int i = 0; i < srcUVHeight; i++) {
            fwrite(srcUV + srcUVStride * i, 1, width, fd);
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

+ (void)writeToFile:(CVPixelBufferRef)pixelBuffer fd:(FILE*)fd {
    const OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        int factor = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ? 2 : 1;
        int planeCount = (int)CVPixelBufferGetPlaneCount(pixelBuffer);
        for (int i = 0; i < planeCount; i++) {
            const uint8_t* src = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i));
            const size_t srcStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i);
            const size_t srcWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
            const size_t srcHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
            size_t size = (i == 0) ? srcWidth * factor : srcWidth * ((planeCount == 2) ? 2 : 1) * factor;
            for (int i = 0; i < srcHeight; i++) {
                fwrite(src + srcStride * i, 1, size, fd);
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

+ (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size pixelFormat:(OSType)format {
    CVPixelBufferRef resultPixelBuffer;
    CFDictionaryRef options = NULL;
    const void *keys[] = {
        kCVPixelBufferOpenGLCompatibilityKey,
        kCVPixelBufferIOSurfacePropertiesKey,
        kCVPixelBufferCGImageCompatibilityKey,
        kCVPixelBufferCGBitmapContextCompatibilityKey,
        kCVPixelBufferBytesPerRowAlignmentKey,
    };
    const void *values[] = {
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSDictionary dictionary]),
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSNumber numberWithInt:32]),
    };
    
    options = CFDictionaryCreate(NULL, keys, values, 5, NULL, NULL);
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, format, options, &resultPixelBuffer);
    CFRelease(options);
    
    return resultPixelBuffer;
}

+ (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size from:(CVPixelBufferRef)src {
    CVPixelBufferRef result;
    CFDictionaryRef options = NULL;
    const void *keys[] = {
        kCVPixelBufferOpenGLCompatibilityKey,
        kCVPixelBufferIOSurfacePropertiesKey,
        kCVPixelBufferCGImageCompatibilityKey,
        kCVPixelBufferCGBitmapContextCompatibilityKey,
        kCVPixelBufferBytesPerRowAlignmentKey,
    };
    const void *values[] = {
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSDictionary dictionary]),
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSNumber numberWithBool:YES]),
        (__bridge const void *)([NSNumber numberWithInt:32]),
    };
    
    OSType format = CVPixelBufferGetPixelFormatType(src);
    options = CFDictionaryCreate(NULL, keys, values, 5, NULL, NULL);
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, format, options, &result);
    CFRelease(options);
    
    CVAttachmentMode attachmentMode = kCVAttachmentMode_ShouldPropagate;
    CGColorSpaceRef colorSpace = (CGColorSpaceRef)CVBufferGetAttachment(src, kCVImageBufferCGColorSpaceKey, &attachmentMode);
    if (colorSpace != nil) {
        CVBufferSetAttachment(result, kCVImageBufferCGColorSpaceKey, colorSpace, attachmentMode);
    }

    CFTypeRef matrix = CVBufferGetAttachment(src, kCVImageBufferYCbCrMatrixKey, &attachmentMode);
    if (matrix != nil) {
        CVBufferSetAttachment(result, kCVImageBufferYCbCrMatrixKey, matrix, attachmentMode);
    }

    CFTypeRef colorPrimaries = CVBufferGetAttachment(src, kCVImageBufferColorPrimariesKey, &attachmentMode);
    if (colorPrimaries != nil) {
        CVBufferSetAttachment(result, kCVImageBufferColorPrimariesKey, colorPrimaries, attachmentMode);
    }

    CFTypeRef transferFunction = CVBufferGetAttachment(src, kCVImageBufferTransferFunctionKey, &attachmentMode);
    if (transferFunction != nil) {
        CVBufferSetAttachment(result, kCVImageBufferTransferFunctionKey, transferFunction, attachmentMode);
    }
    
    return result;
}

+ (CVPixelBufferRef)copyPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    const size_t width = CVPixelBufferGetWidth(pixelBuffer);
    const size_t height = CVPixelBufferGetHeight(pixelBuffer);
    const OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CVPixelBufferRef outputPixelBuffer = [self createPixelBufferWithSize:NSMakeSize(width, height) pixelFormat:format];
    if (outputPixelBuffer == nil) {
        return nil;
    }
    
    CVAttachmentMode attachmentMode = kCVAttachmentMode_ShouldPropagate;
    CGColorSpaceRef colorSpace = (CGColorSpaceRef)CVBufferGetAttachment(pixelBuffer, kCVImageBufferCGColorSpaceKey, &attachmentMode);
    if (colorSpace != nil) {
        CVBufferSetAttachment(outputPixelBuffer, kCVImageBufferCGColorSpaceKey, colorSpace, attachmentMode);
    }

    CFTypeRef matrix = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, &attachmentMode);
    if (matrix != nil) {
        CVBufferSetAttachment(outputPixelBuffer, kCVImageBufferYCbCrMatrixKey, matrix, attachmentMode);
    }

    CFTypeRef colorPrimaries = CVBufferGetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, &attachmentMode);
    if (colorPrimaries != nil) {
        CVBufferSetAttachment(outputPixelBuffer, kCVImageBufferColorPrimariesKey, colorPrimaries, attachmentMode);
    }

    CFTypeRef transferFunction = CVBufferGetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, &attachmentMode);
    if (transferFunction != nil) {
        CVBufferSetAttachment(outputPixelBuffer, kCVImageBufferTransferFunctionKey, transferFunction, attachmentMode);
    }

    CFTypeRef chromaLocationTopField = CVBufferGetAttachment(pixelBuffer, kCVImageBufferChromaLocationTopFieldKey, &attachmentMode);
    if (chromaLocationTopField != nil) {
        CVBufferSetAttachment(outputPixelBuffer, kCVImageBufferChromaLocationTopFieldKey, chromaLocationTopField, attachmentMode);
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(outputPixelBuffer, kNilOptions);
    
    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        int planeCount = (int)CVPixelBufferGetPlaneCount(pixelBuffer);
        for (int i = 0; i < planeCount; i++) {
            const uint8_t* src = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i));
            const size_t srcStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i);
            const size_t srcHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
            uint8_t* dst = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(outputPixelBuffer, i));
            const size_t dstStride = CVPixelBufferGetBytesPerRowOfPlane(outputPixelBuffer, i);
            for (int i = 0; i < srcHeight; i++) {
                memcpy(dst + dstStride * i, src + srcStride * i, srcStride);
            }
        }
    } else if (format == kCVPixelFormatType_32ARGB || format == kCVPixelFormatType_32BGRA) {
        const uint8_t* src = (const uint8_t*)CVPixelBufferGetBaseAddress(pixelBuffer);
        const size_t srcHeight = CVPixelBufferGetHeight(pixelBuffer);
        const size_t srcStride = CVPixelBufferGetBytesPerRow(pixelBuffer);
        uint8_t* dst = (uint8_t*)CVPixelBufferGetBaseAddress(outputPixelBuffer);
        for (int i = 0; i < srcHeight; i++) {
            memcpy(dst + srcStride * i, src + srcStride * i, srcStride);
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferUnlockBaseAddress(outputPixelBuffer, kNilOptions);
    return outputPixelBuffer;
}

+ (CVPixelBufferRef)createAndRotatePixelBuffer:(CVPixelBufferRef)pixelBuffer rotationConstant:(uint8_t)rotationConstant
{
    const OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int srcYWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int srcYHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    int dstWidth = srcYWidth;
    int dstHeight = srcYHeight;
    if (rotationConstant == 3 || rotationConstant == 1) {
        dstWidth = srcYHeight;
        dstHeight = srcYWidth;
    }
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CVPixelBufferRef outputPixelBuffer = [self createPixelBufferWithSize:NSMakeSize(dstWidth, dstHeight) pixelFormat:pixelFormat];
    CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    CVBufferSetAttachment(outputPixelBuffer, kCVImageBufferYCbCrMatrixKey, colorAttachments, kCVAttachmentMode_ShouldNotPropagate);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(outputPixelBuffer, kNilOptions);
    
    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        vImage_Buffer srcImageBuffer;
        srcImageBuffer.data = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        srcImageBuffer.width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        srcImageBuffer.height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        srcImageBuffer.rowBytes = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);

        vImage_Buffer dstImageBuffer;
        dstImageBuffer.data = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(outputPixelBuffer, 0);
        dstImageBuffer.width = (int)CVPixelBufferGetWidthOfPlane(outputPixelBuffer, 0);
        dstImageBuffer.height = (int)CVPixelBufferGetHeightOfPlane(outputPixelBuffer, 0);
        dstImageBuffer.rowBytes = (int)CVPixelBufferGetBytesPerRowOfPlane(outputPixelBuffer, 0);

        vImageRotate90_Planar8(&srcImageBuffer, &dstImageBuffer, rotationConstant, 0, kvImageBackgroundColorFill);

        vImage_Buffer srcUVImageBuffer;
        srcUVImageBuffer.data = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        srcUVImageBuffer.width = srcYWidth / 2;
        srcUVImageBuffer.height = srcYHeight / 2;
        srcUVImageBuffer.rowBytes = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        vImage_Buffer dstUVImageBuffer;
        dstUVImageBuffer.data = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(outputPixelBuffer, 1);
        dstUVImageBuffer.width = dstWidth / 2;
        dstUVImageBuffer.height = dstHeight / 2;
        dstUVImageBuffer.rowBytes = (int)CVPixelBufferGetBytesPerRowOfPlane(outputPixelBuffer, 1);

        vImageRotate90_Planar16U(&srcUVImageBuffer, &dstUVImageBuffer, rotationConstant, 0, kvImageBackgroundColorFill);
    } else if (format == kCVPixelFormatType_32ARGB || format == kCVPixelFormatType_32BGRA) {
        vImage_Buffer srcImageBuffer;
        srcImageBuffer.data = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
        srcImageBuffer.width = (int)CVPixelBufferGetWidth(pixelBuffer);
        srcImageBuffer.height = (int)CVPixelBufferGetHeight(pixelBuffer);
        srcImageBuffer.rowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);

        vImage_Buffer dstImageBuffer;
        dstImageBuffer.data = (uint8_t *)CVPixelBufferGetBaseAddress(outputPixelBuffer);
        dstImageBuffer.width = (int)CVPixelBufferGetWidth(outputPixelBuffer);
        dstImageBuffer.height = (int)CVPixelBufferGetHeight(outputPixelBuffer);
        dstImageBuffer.rowBytes = (int)CVPixelBufferGetBytesPerRow(outputPixelBuffer);

        Pixel_8888 backgroundColor = {0,0,0,0};
        vImageRotate90_ARGB8888(&srcImageBuffer, &dstImageBuffer, rotationConstant, backgroundColor, kvImageBackgroundColorFill);
    }

    CVPixelBufferUnlockBaseAddress(outputPixelBuffer, kNilOptions);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return outputPixelBuffer;
    return nil;
}

+ (CGImagePropertyOrientation)getOrientation:(CMSampleBufferRef)sampleBuffer
{
    CFStringRef sampleBufferVideoOrientation = CFSTR("RPSampleBufferVideoOrientation");
    CFNumberRef numberRef = (CFNumberRef)CMGetAttachment(sampleBuffer, sampleBufferVideoOrientation, nil);
    CGImagePropertyOrientation orientation = (CGImagePropertyOrientation)[((__bridge NSNumber *)numberRef) intValue];
    return orientation;
}

+ (CVPixelBufferRef)createAndscalePixelBuffer:(CVPixelBufferRef)srcPixelBuffer scaleSize:(CGSize)size
{
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer);
    CVPixelBufferRef ouputPixelBuffer = [self createPixelBufferWithSize:size pixelFormat:pixelFormat];
    
    CVPixelBufferLockBaseAddress(srcPixelBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(ouputPixelBuffer, kNilOptions);
    
    if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        int planeCount = (int)CVPixelBufferGetPlaneCount(srcPixelBuffer);
        if (@available(iOS 10.0, *)) {
            for (int i = 0; i < planeCount; i++) {
                vImage_Buffer srcBuffer, destBuffer;
                srcBuffer.data = CVPixelBufferGetBaseAddressOfPlane(srcPixelBuffer, i);
                srcBuffer.width = CVPixelBufferGetWidthOfPlane(srcPixelBuffer, i);
                srcBuffer.height = CVPixelBufferGetHeightOfPlane(srcPixelBuffer, i);
                srcBuffer.rowBytes = CVPixelBufferGetBytesPerRowOfPlane(srcPixelBuffer, i);
                
                destBuffer.data = CVPixelBufferGetBaseAddressOfPlane(ouputPixelBuffer, i);
                destBuffer.width = CVPixelBufferGetWidthOfPlane(ouputPixelBuffer, i);
                destBuffer.height = CVPixelBufferGetHeightOfPlane(ouputPixelBuffer, i);
                destBuffer.rowBytes = CVPixelBufferGetBytesPerRowOfPlane(ouputPixelBuffer, i);
                
                if (i ==0) {
                    vImageScale_Planar8(&srcBuffer, &destBuffer, NULL, kvImageBackgroundColorFill);
                } else {
                    vImageScale_CbCr8(&srcBuffer, &destBuffer, NULL, kvImageBackgroundColorFill);
                }
            }
        }
    }
    else if (pixelFormat == kCVPixelFormatType_32ARGB || pixelFormat == kCVPixelFormatType_32BGRA)
    {
        vImage_Buffer srcBuffer, destBuffer;
        srcBuffer.data = CVPixelBufferGetBaseAddress(srcPixelBuffer);
        srcBuffer.width = CVPixelBufferGetWidth(srcPixelBuffer);
        srcBuffer.height = CVPixelBufferGetHeight(srcPixelBuffer);
        srcBuffer.rowBytes = CVPixelBufferGetBytesPerRow(srcPixelBuffer);
        
        destBuffer.data = CVPixelBufferGetBaseAddress(ouputPixelBuffer);
        destBuffer.width = CVPixelBufferGetWidth(ouputPixelBuffer);
        destBuffer.height = CVPixelBufferGetHeight(ouputPixelBuffer);
        destBuffer.rowBytes = CVPixelBufferGetBytesPerRow(ouputPixelBuffer);
        
        vImageScale_ARGB8888(&srcBuffer, &destBuffer, NULL, kvImageNoFlags);
    }
    
    CVPixelBufferUnlockBaseAddress(srcPixelBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferUnlockBaseAddress(ouputPixelBuffer, kNilOptions);
    
    return ouputPixelBuffer;
}

+ (CVPixelBufferRef)scaleCropPixelBuffer:(CVPixelBufferRef)src cropSize:(CGSize)size {
    int src_width = (int)CVPixelBufferGetWidth(src);
    int src_height = (int)CVPixelBufferGetHeight(src);
    OSType format = CVPixelBufferGetPixelFormatType(src);
    if (format != kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange || size.width > src_width || size.height > src_height ) {
        return src;
    }

    int offset_x = 0;
    int offset_y = 0;
    
    int dst_width = size.width;
    int dst_height = size.height;
    
    float hs = 1.0 * src_width / size.width;
    float vs = 1.0 * src_height / size.height;

    if ( vs > hs ) {
        dst_width = src_width;
        dst_height = src_width / (1.0 * size.width / size.height);
    } else {
        dst_width = src_height * (1.0 * size.width / size.height);
        dst_height = src_height;
    }

    offset_x = (src_width - dst_width) / 2;
    offset_y = (src_height - dst_height) / 2;
    
    CVPixelBufferRef dst = [self createPixelBufferWithSize:CGSizeMake(dst_width, dst_height) from:src];
    
    CVPixelBufferLockBaseAddress(dst, kNilOptions);
    CVPixelBufferLockBaseAddress(src, kNilOptions);
    
    const uint16_t* src_y = (const uint16_t*)(CVPixelBufferGetBaseAddressOfPlane(src, 0));
    const uint16_t* src_uv = (const uint16_t*)(CVPixelBufferGetBaseAddressOfPlane(src, 1));
    const int src_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(src, 0)) / 2;
    const int src_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(src, 1)) / 2;

    const int uv_offset_x = offset_x;
    const int uv_offset_y = offset_y / 2;
    const uint16_t* y_plane = src_y + src_stride_y * offset_y + offset_x;
    const uint16_t* uv_plane = src_uv + src_stride_uv * uv_offset_y + uv_offset_x;
    
    uint16_t* dst_y = (uint16_t*)(CVPixelBufferGetBaseAddressOfPlane(dst, 0));
    uint16_t* dst_uv = (uint16_t*)(CVPixelBufferGetBaseAddressOfPlane(dst, 1));
    const int dst_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(dst, 0)) / 2;
    const int dst_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(dst, 1)) / 2;
    
    size.width = (int)CVPixelBufferGetWidth(dst);
    size.height = (int)CVPixelBufferGetHeight(dst);

    int srcHeight = (int)CVPixelBufferGetHeightOfPlane(src, 0);
    int dstHeight = (int)CVPixelBufferGetHeightOfPlane(dst, 0);
    for (int i = 0; i < dstHeight && i < srcHeight; i++) {
        memcpy(dst_y + i * dst_stride_y, y_plane + i * src_stride_y, size.width * 2);
    }

    srcHeight = (int)CVPixelBufferGetHeightOfPlane(src, 1);
    dstHeight = (int)CVPixelBufferGetHeightOfPlane(dst, 1);
    for (int i = 0; i < dstHeight && i < srcHeight; i++) {
        memcpy(dst_uv + i * dst_stride_uv, uv_plane + i * src_stride_uv, size.width * 4);
    }
    
    CVPixelBufferUnlockBaseAddress(src, kNilOptions);
    CVPixelBufferUnlockBaseAddress(dst, kNilOptions);
    
    return dst;
}

+ (CMSampleBufferRef)createSampleBufferWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CMSampleBufferRef result = NULL;
    CMVideoFormatDescriptionRef formatDescription = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDescription);
    
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             formatDescription,
                                             &timing,
                                             &result);
    CFRelease(formatDescription);
    return result;
}

+ (CMSampleBufferRef)createSampleBufferWithPixelBuffer:(CVPixelBufferRef)pixelBuffer from:(CMSampleBufferRef)sampleBuffer
{
    CMSampleBufferRef result = NULL;
    CMVideoFormatDescriptionRef formatDescription = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDescription);
    
    CMSampleTimingInfo timing;
    CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing);
    CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             formatDescription,
                                             &timing,
                                             &result);
    CFRelease(formatDescription);
    return result;
}

+ (CVPixelBufferRef)convertTo32BGRA:(CVPixelBufferRef)pixelBuffer
{
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    CVPixelBufferRef ouputPixelBuffer = [self createPixelBufferWithSize:NSMakeSize(width, height) pixelFormat:kCVPixelFormatType_32BGRA];
    if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
    
//        vImage_Buffer Y_Buffer, UV_Buffer, dstBuffer;
//        Y_Buffer.data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//        Y_Buffer.width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
//        Y_Buffer.height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
//        Y_Buffer.rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
//
//        UV_Buffer.data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//        UV_Buffer.width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
//        UV_Buffer.height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
//        UV_Buffer.rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
//
//        dstBuffer.data = CVPixelBufferGetBaseAddress(ouputPixelBuffer);
//        dstBuffer.width = CVPixelBufferGetWidth(ouputPixelBuffer);
//        dstBuffer.height = CVPixelBufferGetHeight(ouputPixelBuffer);;
//        dstBuffer.rowBytes = CVPixelBufferGetBytesPerRow(ouputPixelBuffer);
//
//        uint8_t permuteMap[4] = {3, 2, 1, 0};
//        vImage_YpCbCrPixelRange pixelRange = { 0, 128, 255, 255, 255, 1, 255, 0 };
//        vImage_YpCbCrToARGB *outInfo = (vImage_YpCbCrToARGB *)malloc(sizeof(vImage_YpCbCrToARGB));
//        vImageYpCbCrType inType = kvImage420Yp8_CbCr8;
//        vImageARGBType outType = kvImageARGB8888;
//        vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, &pixelRange, outInfo, inType, outType, kvImagePrintDiagnosticsToConsole);
//        vImageConvert_420Yp8_CbCr8ToARGB8888(&Y_Buffer, &UV_Buffer, &dstBuffer, outInfo, permuteMap, 0, kvImageNoFlags);
//        free(outInfo);
    }
    return ouputPixelBuffer;
}

//void cropAndScaleFrom(CVPixelBufferRef dst,
//                      CVPixelBufferRef src,
//                      int offset_x,
//                      int offset_y,
//                      int crop_width,
//                      int crop_height) {
//
//    CVPixelBufferLockBaseAddress(dst, kNilOptions);
//    CVPixelBufferLockBaseAddress(src, kNilOptions);
//    OSType format = CVPixelBufferGetPixelFormatType(src);
//    if (format == kCVPixelFormatType_420YpCbCr8Planar) {
//        const int uv_offset_x = offset_x / 2;
//        const int uv_offset_y = offset_y / 2;
//        offset_x = uv_offset_x * 2;
//        offset_y = uv_offset_y * 2;
//
//        const int src_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(src, 0));
//        const int src_stride_u = (int)(CVPixelBufferGetBytesPerRowOfPlane(src, 1));
//        const int src_stride_v = (int)(CVPixelBufferGetBytesPerRowOfPlane(src, 2));
//
//        const uint8_t* srcY = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(src, 0));
//        const uint8_t* srcU = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(src, 1));
//        const uint8_t* srcV = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(src, 2));
//
//        const uint8_t* y_plane = srcY + src_stride_y * offset_y + offset_x;
//        const uint8_t* u_plane = srcU + src_stride_u * uv_offset_y + uv_offset_x;
//        const uint8_t* v_plane = srcV + src_stride_v * uv_offset_y + uv_offset_x;
//
//        const int dst_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(dst, 0));
//        const int dst_stride_u = (int)(CVPixelBufferGetBytesPerRowOfPlane(dst, 1));
//        const int dst_stride_v = (int)(CVPixelBufferGetBytesPerRowOfPlane(dst, 2));
//
//        uint8_t* dstY = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(dst, 0));
//        uint8_t* dstU = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(dst, 1));
//        uint8_t* dstV = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(dst, 2));
//
//        int width = (int)CVPixelBufferGetWidth(dst);
//        int height = (int)CVPixelBufferGetHeight(dst);
//
//        libyuv::I420Scale(y_plane, src_stride_y, u_plane, src_stride_u, v_plane, src_stride_v,
//                          crop_width, crop_height,
//                          dstY, dst_stride_y, dstU, dst_stride_u, dstV, dst_stride_v,
//                          width, height,
//                          libyuv::kFilterBox);
//    }
//    else if (format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
//        const int uv_offset_x = offset_x / 2;
//        const int uv_offset_y = offset_y / 2;
//        offset_x = uv_offset_x * 2;
//        offset_y = uv_offset_y * 2;
//
//        const int src_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(src, 0));
//        const int src_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(src, 1));
//
//        const uint8_t* srcY = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(src, 0));
//        const uint8_t* srcUV = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(src, 1));
//
//        const uint8_t* y_plane = srcY + src_stride_y * offset_y + offset_x;
//        const uint8_t* uv_plane = srcUV + src_stride_uv * uv_offset_y * 2 + uv_offset_x * 2;
//
//        const int dst_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(dst, 0));
//        const int dst_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(dst, 1));
//
//        uint8_t* dstY = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(dst, 0));
//        uint8_t* dstUV = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(dst, 1));
//
//        int width = (int)CVPixelBufferGetWidth(dst);
//        int height = (int)CVPixelBufferGetHeight(dst);
//
//        libyuv::NV12Scale(y_plane, src_stride_y, uv_plane, src_stride_uv,
//                          crop_width, crop_height,
//                          dstY, dst_stride_y, dstUV, dst_stride_uv,
//                          width, height,
//                          libyuv::kFilterBox);
//    }
//
//    CVPixelBufferUnlockBaseAddress(src, kNilOptions);
//    CVPixelBufferUnlockBaseAddress(dst, kNilOptions);
//}

+ (CVPixelBufferRef)mirrorPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int planeCount = (int)CVPixelBufferGetPlaneCount(pixelBuffer);
    if (planeCount == 2) {
        int factor = 1;
        if (pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange) {
            factor = 2;
        }
        uint8_t* src_y = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
        uint8_t* src_uv = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
        const int src_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0));
        const int src_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1));
        
        int width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        int height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        uint32_t value = 0;
        for (int i = 0; i < height; i++) {
            for (int j = 0; j < width / 2; j++) {
                memcpy(&value, src_y + j * factor, factor);
                memcpy(src_y + j * factor, src_y + (width - j - 1) * factor, factor);
                memcpy(src_y + (width - j - 1) * factor, &value, factor);
            }
            src_y += src_stride_y;
        }

        width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        factor *= 2;
        for (int i = 0; i < height; i++) {
            for (int j = 0; j < width / 2; j++) {
                memcpy(&value, src_uv + j * factor, factor);
                memcpy(src_uv + j * factor, src_uv + (width - j - 1) * factor, factor);
                memcpy(src_uv + (width - j - 1) * factor, &value, factor);
            }
            src_uv += src_stride_uv;
        }
    } else if (planeCount == 3) {
        for (int i = 0; i < planeCount; i++) {
            int height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
            int width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
            uint8_t* src = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i));
            const int stride = (int)(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i));
            uint8_t value = 0;
            for (int j = 0; j < height; j++) {
                for (int k = 0; k < width / 2; k++) {
                    value = src[k];
                    src[k] = src[width - k - 1];
                    src[width - k - 1] = value;
                }
                src += stride;
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    return pixelBuffer;
}

+ (CVPixelBufferRef)mirrorPixelBufferByte:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange) {
        uint16_t* src_y = (uint16_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
        uint32_t* src_uv = (uint32_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
        const int src_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0));
        const int src_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1));
        
        int width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        int height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        uint16_t y_value = 0;
        for (int i = 0; i < height; i++) {
            for (int j = 0; j < width / 2; j++) {
                y_value = src_y[j];
                src_y[j] = src_y[width - j - 1];
                src_y[width - j - 1] = y_value;
            }
            src_y = (uint16_t*)(((uint8_t*)src_y) + src_stride_y);
        }

        width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);

        uint32_t uv_value = 0;
        for (int i = 0; i < height; i++) {
            for (int j = 0; j < width / 2; j++) {
                uv_value = src_uv[j];
                src_uv[j] = src_uv[width - j - 1];
                src_uv[width - j - 1] = uv_value;
            }
            src_uv = (uint32_t*)(((uint8_t*)src_uv) + src_stride_uv);
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    return pixelBuffer;
}

+ (CVPixelBufferRef)mirror:(CVPixelBufferRef)srcpbr dst:(CVPixelBufferRef)dstpbr
{
    CVPixelBufferLockBaseAddress(srcpbr, kNilOptions);
    CVPixelBufferLockBaseAddress(dstpbr, kNilOptions);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(srcpbr);
    if (pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange) {
        uint8_t* src_y = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(srcpbr, 0));
        uint8_t* src_uv = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(srcpbr, 1));
        const int src_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(srcpbr, 0));
        const int src_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(srcpbr, 1));
        uint8_t* dst_y = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(dstpbr, 0));
        uint8_t* dst_uv = (uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(dstpbr, 1));
        const int dst_stride_y = (int)(CVPixelBufferGetBytesPerRowOfPlane(dstpbr, 0));
        const int dst_stride_uv = (int)(CVPixelBufferGetBytesPerRowOfPlane(dstpbr, 1));
        
        int width = (int)CVPixelBufferGetWidthOfPlane(srcpbr, 0);
        int height = (int)CVPixelBufferGetHeightOfPlane(srcpbr, 0);
        libyuv::MirrorUVPlane(src_y, src_stride_y, dst_y, dst_stride_y, width, height);

        width = (int)CVPixelBufferGetWidthOfPlane(srcpbr, 1);
        height = (int)CVPixelBufferGetHeightOfPlane(srcpbr, 1);
        libyuv::ARGBMirror(src_uv, src_stride_uv, dst_uv, dst_stride_uv, width, height);
    }
    CVPixelBufferUnlockBaseAddress(srcpbr, kNilOptions);
    CVPixelBufferUnlockBaseAddress(dstpbr, kNilOptions);
    return dstpbr;
}

+ (CVPixelBufferRef)fillPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (format != kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange) {
        return pixelBuffer;
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    uint16_t *pixel = (uint16_t *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
    int dstStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) / 2;
    int dstHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    
    uint16_t y = 0;
    uint16_t u = 0;
    uint16_t v = 0;
    rgbToYuvBT2020(1023, 0, 0, &y, &u, &v);
    
    for (int i = 0; i < dstHeight; i++) {
        for (int j = 0; j < dstStride; j++) {
            pixel[dstStride * i + j] = y << 6;
        }
    }
    
    pixel = (uint16_t *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
    dstStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) / 2;
    dstHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    for (int i = 0; i < dstHeight; i++) {
        for (int j = 0; j < dstStride; j += 2) {
            pixel[dstStride * i + j] = u << 6;
            pixel[dstStride * i + j + 1] = v << 6;
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    return pixelBuffer;
}

- (void)fillHDRRectangle {
    int width = 720;
    int height = 1280;
    int bitdepth = 10;
    
    uint16_t y = 0;
    uint16_t u = 0;
    uint16_t v = 0;
    
    int frameSize = height * width * 2 + (height / 2 * width) * 2;
    uint8_t *dataY = (uint8_t *)malloc(frameSize);
    
    rgbToYuvBT2020(1023, 1023, 1023, &y, &u, &v);
    [self fillRect:dataY
          original:CGSizeMake(width, height)
              fill:CGRectMake(0, 0, width, height)
                 y:(y << (bitdepth - 10))
                 u:(u << (bitdepth - 10))
                 v:(v << (bitdepth - 10))];
    
    rgbToYuvBT2020(1023, 0, 0, &y, &u, &v);
    [self fillRect:dataY
          original:CGSizeMake(width, height)
              fill:CGRectMake(0, 0, 360, 640)
                 y:(y << (bitdepth - 10))
                 u:(u << (bitdepth - 10))
                 v:(v << (bitdepth - 10))];

    rgbToYuvBT2020(0, 1023, 0, &y, &u, &v);
    [self fillRect:dataY
          original:CGSizeMake(width, height)
              fill:CGRectMake(360, 0, 360, 640)
                 y:(y << (bitdepth - 10))
                 u:(u << (bitdepth - 10))
                 v:(v << (bitdepth - 10))];


    rgbToYuvBT2020(0, 0, 1023, &y, &u, &v);
    [self fillRect:dataY
          original:CGSizeMake(width, height)
              fill:CGRectMake(0, 640, 360, 640)
                 y:(y << (bitdepth - 10))
                 u:(u << (bitdepth - 10))
                 v:(v << (bitdepth - 10))];

    FILE *fd = fopen("/Users/enki/Desktop/rgbw_720x1280x24_yuv420p10le.yuv", "wb");
    for (int i = 0; i < 50; i++) {
        fwrite(dataY, 1, frameSize, fd);
    }
    free(dataY);
    fflush(fd);
    fclose(fd);
}

- (void)fillRect:(uint8_t *)data original:(CGSize)size fill:(CGRect)fillRect y:(uint16_t)y u:(uint16_t)u v:(uint16_t)v {
    int strideY = size.width;
    int strideU = size.width / 2;
    int strideV = size.width / 2;
    uint16_t *dataY = (uint16_t*)data;
    uint16_t *dataU = dataY + (int)(size.height * strideY);
    uint16_t *dataV = dataU + (int)(size.height / 2 * strideU);
    
    for (int h = fillRect.origin.y; h < fillRect.origin.y + fillRect.size.height; h++) {
        for (int w = fillRect.origin.x; w < fillRect.origin.x + fillRect.size.width; w++) {
            dataY[h * strideY + w] = y;
        }
    }
    
    for (int h = fillRect.origin.y / 2; h < (fillRect.origin.y + fillRect.size.height) / 2; h++) {
        for (int w = fillRect.origin.x / 2; w < (fillRect.origin.x + fillRect.size.width) / 2; w++) {
            dataU[h * strideU + w] = u;
        }
    }
    
    for (int h = fillRect.origin.y / 2; h < (fillRect.origin.y + fillRect.size.height) / 2; h++) {
        for (int w = fillRect.origin.x / 2; w < (fillRect.origin.x + fillRect.size.width) / 2; w++) {
            dataV[h * strideV + w] = v;
        }
    }
}

@end
