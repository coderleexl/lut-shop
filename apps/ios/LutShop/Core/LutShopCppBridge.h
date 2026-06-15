#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LutShopCppBridge : NSObject

+ (NSString *)coreVersion;
+ (NSInteger)sampleImportPhotoCount;
+ (NSInteger)sampleCubeEntryCount;
+ (NSArray<NSDictionary<NSString *, id> *> *)bundledLutMetadata;
+ (NSString *)loadSummaryForBundledLutNamed:(NSString *)fileName;
+ (NSString *)previewPixelSummaryForBundledLutNamed:(NSString *)fileName;
+ (nullable UIImage *)previewImageByApplyingBundledLutNamed:(NSString *)fileName
                                              toImageNamed:(NSString *)imageName
                                                intensity:(double)intensity;
+ (nullable UIImage *)previewImageByApplyingBundledLutNamed:(NSString *)fileName
                                                toImageAtPath:(NSString *)imagePath
                                                   intensity:(double)intensity;
+ (nullable UIImage *)userLutPreviewImageByApplyingLutAtPath:(NSString *)lutPath
                                                 toImageNamed:(NSString *)imageName
                                                   intensity:(double)intensity
    NS_SWIFT_NAME(applyUserLut(atPath:toImageNamed:intensity:));
+ (nullable UIImage *)userLutPreviewImageByApplyingLutAtPath:(NSString *)lutPath
                                                toImageAtPath:(NSString *)imagePath
                                                   intensity:(double)intensity
    NS_SWIFT_NAME(applyUserLut(atPath:toImageAtPath:intensity:));

@end

NS_ASSUME_NONNULL_END
