#import "LutShopCppBridge.h"

#include "lutshop/bridge_c.h"
#include "lutshop/cube.hpp"

#include <algorithm>
#include <cmath>
#include <vector>

namespace {

NSString *StringFromCString(const char *value) {
    if (value == nullptr || value[0] == '\0') {
        return @"";
    }
    return [NSString stringWithUTF8String:value] ?: @"";
}

NSString *ReadableNameFromFileName(NSString *fileName) {
    NSString *base = [fileName stringByDeletingPathExtension];
    return [[base stringByReplacingOccurrencesOfString:@"_" withString:@" "] stringByReplacingOccurrencesOfString:@"-" withString:@" "];
}

NSString *CategoryForFileName(NSString *fileName) {
    NSString *lower = [fileName lowercaseString];
    if ([lower containsString:@"bw"] || [lower containsString:@"mono"]) {
        return @"B&W";
    }
    if ([lower containsString:@"color"] || [lower containsString:@"warm"] || [lower containsString:@"teal"]) {
        return @"Film";
    }
    return @"Custom";
}

NSArray<NSURL *> *BundledLutURLs(void) {
    NSArray<NSURL *> *urls = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"cube" subdirectory:@"BundledLuts"];
    return [urls sortedArrayUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
        return [[left lastPathComponent] compare:[right lastPathComponent]];
    }];
}

NSString *CubeTextForFileName(NSString *fileName) {
    NSURL *url = [[NSBundle mainBundle] URLForResource:[fileName stringByDeletingPathExtension] withExtension:@"cube" subdirectory:@"BundledLuts"];
    if (url == nil) {
        return nil;
    }
    return [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
}

UIImage *PrototypeImage(NSString *imageName) {
    NSURL *url = [[NSBundle mainBundle] URLForResource:imageName withExtension:@"jpg" subdirectory:@"PrototypePhotos"];
    if (url == nil) {
        return nil;
    }
    return [UIImage imageWithContentsOfFile:[url path]];
}

UIImage *ImageAtPath(NSString *imagePath) {
    if (imagePath.length == 0) {
        return nil;
    }
    return [UIImage imageWithContentsOfFile:imagePath];
}

CGSize PreviewSizeForImage(UIImage *image, CGFloat maxDimension) {
    CGSize size = image.size;
    CGFloat longest = std::max(size.width, size.height);
    if (longest <= 0) {
        return CGSizeZero;
    }
    CGFloat scale = std::min<CGFloat>(1.0, maxDimension / longest);
    return CGSizeMake(std::max<CGFloat>(1.0, std::round(size.width * scale)),
                      std::max<CGFloat>(1.0, std::round(size.height * scale)));
}

UIImage *ApplyBundledLutToImage(NSString *fileName, UIImage *sourceImage, double intensity) {
    NSString *text = CubeTextForFileName(fileName);
    if (text == nil || sourceImage == nil) {
        return sourceImage;
    }

    const auto parsed = lutshop::parseCube([[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] UTF8String]);
    if (!parsed.success) {
        return sourceImage;
    }

    CGSize targetSize = PreviewSizeForImage(sourceImage, 900.0);
    if (CGSizeEqualToSize(targetSize, CGSizeZero)) {
        return sourceImage;
    }

    const size_t width = static_cast<size_t>(targetSize.width);
    const size_t height = static_cast<size_t>(targetSize.height);
    const size_t bytesPerPixel = 4;
    const size_t bytesPerRow = width * bytesPerPixel;
    std::vector<unsigned char> pixels(height * bytesPerRow);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = static_cast<CGBitmapInfo>(
        static_cast<uint32_t>(kCGImageAlphaPremultipliedLast) |
        static_cast<uint32_t>(kCGBitmapByteOrder32Big)
    );
    CGContextRef context = CGBitmapContextCreate(
        pixels.data(),
        width,
        height,
        8,
        bytesPerRow,
        colorSpace,
        bitmapInfo
    );
    CGColorSpaceRelease(colorSpace);

    if (context == nullptr) {
        return sourceImage;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, targetSize.width, targetSize.height), [sourceImage CGImage]);

    const float blend = static_cast<float>(std::clamp(intensity, 0.0, 1.0));
    for (size_t offset = 0; offset + 3 < pixels.size(); offset += bytesPerPixel) {
        const auto input = lutshop::CubeEntry{
            pixels[offset] / 255.0F,
            pixels[offset + 1] / 255.0F,
            pixels[offset + 2] / 255.0F,
        };
        const auto output = lutshop::applyCubeNearest(parsed.cube, input, blend);
        pixels[offset] = static_cast<unsigned char>(std::round(std::clamp(output.r, 0.0F, 1.0F) * 255.0F));
        pixels[offset + 1] = static_cast<unsigned char>(std::round(std::clamp(output.g, 0.0F, 1.0F) * 255.0F));
        pixels[offset + 2] = static_cast<unsigned char>(std::round(std::clamp(output.b, 0.0F, 1.0F) * 255.0F));
    }

    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (cgImage == nullptr) {
        return sourceImage;
    }

    UIImage *outputImage = [UIImage imageWithCGImage:cgImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return outputImage;
}

}  // namespace

@implementation LutShopCppBridge

+ (NSString *)coreVersion {
    const char *version = lutshop_core_version();
    return version == nullptr ? @"unknown" : [NSString stringWithUTF8String:version];
}

+ (NSInteger)sampleImportPhotoCount {
    lutshop_import_item items[] = {
        {"asset://ios-sample-1", "CPP_IMPORT_0001.CR3", "2026-06-12T10:00:00Z"},
        {"asset://ios-sample-2", "CPP_IMPORT_0002.CR3", "2026-06-12T10:01:00Z"},
        {"asset://ios-sample-3", "CPP_IMPORT_0003.CR3", "2026-06-12T10:02:00Z"},
    };

    return static_cast<NSInteger>(
        lutshop_import_photo_count("ios-session", "iOS C++ Smoke", items, 3)
    );
}

+ (NSInteger)sampleCubeEntryCount {
    const char *cube =
        "TITLE \"iOS Smoke LUT\"\n"
        "LUT_3D_SIZE 2\n"
        "0 0 0\n"
        "0 0 1\n"
        "0 1 0\n"
        "0 1 1\n"
        "1 0 0\n"
        "1 0 1\n"
        "1 1 0\n"
        "1 1 1\n";

    return static_cast<NSInteger>(lutshop_parse_cube_entry_count(cube));
}

+ (NSArray<NSDictionary<NSString *, id> *> *)bundledLutMetadata {
    NSMutableArray<NSDictionary<NSString *, id> *> *items = [NSMutableArray array];
    for (NSURL *url in BundledLutURLs()) {
        NSString *text = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        if (text == nil) {
            continue;
        }

        NSString *fileName = [url lastPathComponent];
        lutshop_cube_metadata metadata = lutshop_parse_cube_metadata([text UTF8String], [fileName UTF8String]);
        if (metadata.success != 1) {
            continue;
        }

        NSString *title = StringFromCString(metadata.title);
        if ([title isEqualToString:@"Generated by Resolve"]) {
            title = ReadableNameFromFileName(fileName);
        }

        [items addObject:@{
            @"id": [@"bundled-" stringByAppendingString:[fileName stringByDeletingPathExtension]],
            @"name": title.length > 0 ? title : ReadableNameFromFileName(fileName),
            @"fileName": fileName,
            @"category": CategoryForFileName(fileName),
            @"cubeSize": @(metadata.size),
            @"entryCount": @(metadata.entry_count),
            @"provider": @"Sony",
        }];
    }
    return items;
}

+ (NSString *)loadSummaryForBundledLutNamed:(NSString *)fileName {
    NSString *text = CubeTextForFileName(fileName);
    if (text == nil) {
        return @"CUBE file not found";
    }

    lutshop_cube_metadata metadata = lutshop_parse_cube_metadata([text UTF8String], [fileName UTF8String]);
    if (metadata.success != 1) {
        NSString *message = StringFromCString(metadata.message);
        return message.length > 0 ? message : @"CUBE parse failed";
    }

    return [NSString stringWithFormat:@"C++ loaded %@ · %d^3 · %zu entries", fileName, metadata.size, metadata.entry_count];
}

+ (NSString *)previewPixelSummaryForBundledLutNamed:(NSString *)fileName {
    NSString *text = CubeTextForFileName(fileName);
    if (text == nil) {
        return @"pixel smoke skipped";
    }

    lutshop_rgb input = {0.5F, 0.5F, 0.5F};
    lutshop_rgb output = lutshop_apply_cube_to_rgb([text UTF8String], input, 1.0F);
    return [NSString stringWithFormat:@"RGB 0.50 -> %.2f %.2f %.2f", output.r, output.g, output.b];
}

+ (nullable UIImage *)previewImageByApplyingBundledLutNamed:(NSString *)fileName
                                              toImageNamed:(NSString *)imageName
                                                intensity:(double)intensity {
    return ApplyBundledLutToImage(fileName, PrototypeImage(imageName), intensity);
}

+ (nullable UIImage *)previewImageByApplyingBundledLutNamed:(NSString *)fileName
                                                toImageAtPath:(NSString *)imagePath
                                                   intensity:(double)intensity {
    return ApplyBundledLutToImage(fileName, ImageAtPath(imagePath), intensity);
}

@end
