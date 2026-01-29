//
//  OpenCVWrapper.h
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/22.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <simd/simd.h>

@interface OpenCVWrapper : NSObject

+ (NSArray<NSValue *> *)centersOfContours:(UIImage *)binarizedImage NS_SWIFT_NAME(centersOfContours(from:));

+ (UIImage *)drawCirclesOnContours:(UIImage *)image NS_SWIFT_NAME(drawCirclesOnContours(from:));

+ (UIImage *)detectScreenWithBlackRectangleFrame:(UIImage *)image NS_SWIFT_NAME(detectBlackFrame(from:));

+ (UIImage *)rectifyAreaWithinFourQRCodes:(UIImage *)image NS_SWIFT_NAME(rectifyAreaWithinFourQRCodes(from:));

+ (UIImage *)rectifyImageWith4Points:(UIImage *)image withPoints:(NSArray<NSValue *> *)points outputSize:(CGSize)size NS_SWIFT_NAME(rectifyImage(from:withPoints:outputSize:));

+ (double)meanAbsDiffBetween:(UIImage *)img1 andImg:(UIImage *)img2 NS_SWIFT_NAME(meanAbsDiffBetween(_:and:));

+ (UIImage *)metalBinaryRedHSV:(UIImage *)image baselineWhiteHSV:(simd_float3)baselineWhiteHSV NS_SWIFT_NAME(metalBinaryRedHSV(_:baselineWhiteHSV:));
+ (double)metalMeanAbsDiffBetween:(UIImage *)img1 andImg:(UIImage *)img2 NS_SWIFT_NAME(metalMeanAbsDiffBetween(_:and:));
+ (UIImage *)metalBinaryRedHSV:(UIImage *)image;
+ (NSDictionary *)rectifyImageAndMatrixFrom:(UIImage *)image
                                 withPoints:(NSArray<NSValue *> *)points
                                 outputSize:(CGSize)outputSize NS_SWIFT_NAME(rectifyImageAndMatrix(from:withPoints:outputSize:));
+ (UIImage *)warpImage:(UIImage *)image
           withMatrix:(NSArray<NSArray<NSNumber *> *> *)matrix
           outputSize:(CGSize)size NS_SWIFT_NAME(warpImage(_:withMatrix:outputSize:));
+ (NSArray<NSDictionary *> *)centersAndRadiusOfContours:(UIImage *)binarizedImage NS_SWIFT_NAME(centersAndRadiusOfContours(from:));
@end
