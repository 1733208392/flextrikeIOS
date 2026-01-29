//
//  OpenCVWrapper.m
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/22.
//


#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import "OpenCVWrapper.h"
#import <Metal/Metal.h>


@implementation OpenCVWrapper

+ (NSArray<NSValue *> *)centersOfContours:(UIImage *)binarizedImage {
    cv::Mat mask;
    UIImageToMat(binarizedImage, mask);

    // Ensure single channel
    if (mask.channels() != 1) {
        mask = metalBGRA2Gray(mask);
    }

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    double minArea = 10.0;    // Adjust as needed
    double maxArea = 2500.0;  // Adjust as needed

    NSMutableArray<NSValue *> *centers = [NSMutableArray array];
    for (const auto& contour : contours) {
        double area = cv::contourArea(contour);
        if (area < minArea || area > maxArea) continue;
        if (contour.empty()) continue;
        cv::Moments m = cv::moments(contour);
        if (m.m00 != 0) {
            CGFloat cx = m.m10 / m.m00;
            CGFloat cy = m.m01 / m.m00;
            CGPoint center = CGPointMake(cx, cy);
            [centers addObject:[NSValue valueWithCGPoint:center]];
        }
    }
    
    return centers;
}

// OpenCVWrapper.mm
+ (UIImage *)drawCirclesOnContours:(UIImage *)binarizedImage {
    cv::Mat mask;
    UIImageToMat(binarizedImage, mask);

//    NSLog(@"mask size: %d x %d, channels: %d", mask.cols, mask.rows, mask.channels());
    // Ensure single channel
    if (mask.channels() != 1) {
//        cv::cvtColor(mask, mask, cv::COLOR_BGRA2GRAY);
        mask = metalBGRA2Gray(mask);
    }

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
    
    double minArea = 100.0; // Adjust as needed
    std::vector<std::vector<cv::Point>> filteredContours;
    for (const auto& contour : contours) {
        if (cv::contourArea(contour) >= minArea) {
            filteredContours.push_back(contour);
        }
    }

//    NSLog(@"Contours found: %lu", filteredContours.size());
    
    // Draw circles around contours
    cv::Mat result;
    cv::cvtColor(mask, result, cv::COLOR_GRAY2BGR);

    for (const auto& contour : filteredContours) {
        cv::Point2f center;
        float radius;
        cv::minEnclosingCircle(contour, center, radius);
//        NSLog(@"Contour center: (%f, %f), radius: %f", center.x, center.y, radius);
        cv::circle(result, center, static_cast<int>(radius), cv::Scalar(0,255,0), 2);
    }

    return MatToUIImage(result);
}

+ (NSArray<NSDictionary *> *)centersAndRadiusOfContours:(UIImage *)binarizedImage {
    cv::Mat mask;
    UIImageToMat(binarizedImage, mask);

    // Ensure single channel
    if (mask.channels() != 1) {
        mask = metalBGRA2Gray(mask);
    }

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    NSMutableArray<NSDictionary *> *results = [NSMutableArray array];
    for (const auto& contour : contours) {
        if (contour.empty()) continue;
        cv::Point2f center;
        float radius;
        cv::minEnclosingCircle(contour, center, radius);
        NSDictionary *info = @{
            @"center": [NSValue valueWithCGPoint:CGPointMake(center.x, center.y)],
            @"radius": @(radius)
        };
        [results addObject:info];
    }
    return results;
}

// Objective-C++
+ (UIImage *)detectScreenWithBlackRectangleFrame:(UIImage *)image {
    cv::Mat mat;
    UIImageToMat(image, mat);

    // Convert to grayscale and threshold for black
    cv::Mat gray, thresh;
    cv::cvtColor(mat, gray, cv::COLOR_BGR2GRAY);
    cv::threshold(gray, thresh, 120, 255, cv::THRESH_BINARY_INV);

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    cv::Mat output;
    mat.copyTo(output);

    for (const auto& contour : contours) {
        std::vector<cv::Point> approx;
        cv::approxPolyDP(contour, approx, 0.02 * cv::arcLength(contour, true), true);
        if (approx.size() == 4 && cv::isContourConvex(approx) && cv::contourArea(approx) > 2000) {
            // Create a mask for the detected quadrilateral
            cv::Mat mask = cv::Mat::zeros(gray.size(), CV_8UC1);
            std::vector<std::vector<cv::Point>> poly = {approx};
            cv::fillPoly(mask, poly, cv::Scalar(255));

            // Erode mask to get the inside area (exclude the border)
            cv::Mat innerMask;
            int border = 10; // thickness of the frame
            cv::erode(mask, innerMask, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(border, border)));

            // Calculate mean inside the frame
            double meanInside = cv::mean(gray, innerMask)[0];

            // If inside is bright (white), it's likely a frame
            if (meanInside > 180) {
                cv::polylines(output, approx, true, cv::Scalar(0,255,0), 4);
                NSLog(@"Detected frame with mean inside: %f", meanInside);
                return MatToUIImage(output);
            }
        }
    }
    
    // If no valid frame found, return nil
    return nil;
}

+ (UIImage *)rectifyAreaWithinFourQRCodes:(UIImage *)image {
    cv::Mat mat;
    UIImageToMat(image, mat);

    cv::QRCodeDetector qr;
    std::vector<std::vector<cv::Point2f>> allCorners;
    std::vector<std::string> decoded;

    allCorners.clear();
    decoded.clear();

    // Only call detectAndDecodeMulti once
    bool found = qr.detectAndDecodeMulti(mat, decoded, allCorners);

    if (!found || allCorners.size() != 4) {
        // Not exactly 4 QR codes found
        return image;
    }

    // Compute center for each QR code
    std::vector<std::pair<cv::Point2f, std::vector<cv::Point2f>>> qrCenters;
    for (const auto& corners : allCorners) {
        cv::Point2f center(0,0);
        std::vector<cv::Point2f> pts;
        for (const auto& pt : corners) {
            center += cv::Point2f(pt);
            pts.push_back(pt);
        }
        center *= 0.25f;
        qrCenters.push_back({center, pts});
    }

    // Sort by y, then x to assign corners: TL, TR, BR, BL
    std::sort(qrCenters.begin(), qrCenters.end(), [](const auto& a, const auto& b) {
        if (a.first.y != b.first.y)
            return a.first.y < b.first.y;
        return a.first.x < b.first.x;
    });

    // Top two: left is TL, right is TR; bottom two: left is BL, right is BR
    std::vector<cv::Point2f> rectCorners(4);
    rectCorners[0] = qrCenters[0].first; // TL
    rectCorners[1] = qrCenters[1].first; // TR
    rectCorners[2] = qrCenters[3].first; // BR
    rectCorners[3] = qrCenters[2].first; // BL

    // Define output size (adjust as needed)
    float width = 1000, height = 1000;
    std::vector<cv::Point2f> dst = { {0,0}, {width,0}, {width,height}, {0,height} };

    cv::Mat H = cv::getPerspectiveTransform(rectCorners, dst);
    cv::Mat rectified;
    cv::warpPerspective(mat, rectified, H, cv::Size(width, height));
    return MatToUIImage(rectified);
}

+ (UIImage *)rectifyImageWith4Points:(UIImage *)image withPoints:(NSArray<NSValue *> *)points outputSize:(CGSize)size {
    if (points.count != 4) return image;
    cv::Mat mat;

    // Load test.jpg from main bundle
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"jpg"];
//    if (!path) return nil;
//    UIImage *imgTest = [UIImage imageWithContentsOfFile:path];
//    if (!image) return nil;
    
    UIImageToMat(image, mat);

    // Convert NSArray<NSValue *> to std::vector<cv::Point2f>
    std::vector<cv::Point2f> srcPoints;
    for (NSValue *val in points) {
        CGPoint cg = [val CGPointValue];
        srcPoints.push_back(cv::Point2f(cg.x, cg.y));
    }

    float width = size.width, height = size.height;
    std::vector<cv::Point2f> dstPoints = { {0,0}, {width,0}, {width,height}, {0,height} };

    // Compute perspective transform
    cv::Mat H = cv::getPerspectiveTransform(srcPoints, dstPoints);
    
    //Rectify
    cv::Mat rectified;
    cv::warpPerspective(mat, rectified, H, cv::Size(width, height));
//    for (int r = 0; r < 3; ++r)
//        for (int c = 0; c < 3; ++c)
//            NSLog(@"H[%d][%d] = %f", r, c, H.at<double>(r, c));
            
    return MatToUIImage(rectified);
    /*
    cv::Mat Hf;
    H.convertTo(Hf, CV_32F);
    if (Hf.at<float>(2,2) != 0.0f) {
        Hf /= Hf.at<float>(2,2); // Normalize
    }
    
    double Hdata[9];
    //Check the value of each element of H
        for (int r = 0; r < 3; ++r)
            for (int c = 0; c < 3; ++c)
                Hdata[r * 3 + c] = Hf.at<float>(r, c);
    
//    NSLog(@"H matrix: %@", Hdata);
    
//    float Hdata[9];
//    for (int r = 0; r < 3; ++r)
//        for (int c = 0; c < 3; ++c)
//            Hdata[r * 3 + c] = H.at<float>(r, c);
    
    // --- Metal setup ---
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) return image;
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLLibrary> library = [device newDefaultLibrary];
    id<MTLFunction> function = [library newFunctionWithName:@"warpPerspectiveKernel"];
    NSError *error = nil;
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
    if (!pipeline) return image;

    // Ensure mat.type is CV_8UC4
    if (mat.type() != CV_8UC4) {
        cv::cvtColor(mat, mat, cv::COLOR_BGR2BGRA);
    }

    // Input texture
    MTLTextureDescriptor *inDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:mat.cols height:mat.rows mipmapped:NO];
    inDesc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> inTex = [device newTextureWithDescriptor:inDesc];
    [inTex replaceRegion:MTLRegionMake2D(0,0,mat.cols,mat.rows) mipmapLevel:0 withBytes:mat.data bytesPerRow:mat.step];

    // Output texture
    MTLTextureDescriptor *outDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    outDesc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    id<MTLTexture> outTex = [device newTextureWithDescriptor:outDesc];

//    // Matrix buffer (row-major, 3x3)
//    float Hdata[9] = {
//        1.0f, 0.0f, 0.0f,
//        0.0f, 1.0f, 0.0f,
//        0.0f, 0.0f, 1.0f
//    };
    
//
//    float Hdata[9];
////    memcpy(Hdata, H.ptr<float>(), 9 * sizeof(float));
//    memcpy(Hdata, homography.ptr<float>(), 9 * sizeof(float));

    id<MTLBuffer> HBuffer = [device newBufferWithBytes:Hdata length:sizeof(Hdata) options:MTLResourceStorageModeShared];

    // Encode and dispatch
    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:pipeline];
    [encoder setTexture:inTex atIndex:0];
    [encoder setTexture:outTex atIndex:1];
    [encoder setBuffer:HBuffer offset:0 atIndex:0];
    MTLSize threads = MTLSizeMake(width, height, 1);
    MTLSize tpg = MTLSizeMake(8, 8, 1);
    [encoder dispatchThreadgroups:MTLSizeMake((width+7)/8, (height+7)/8, 1) threadsPerThreadgroup:tpg];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    // Read back to cv::Mat
    cv::Mat rectified(height, width, CV_8UC4);
    [outTex getBytes:rectified.data bytesPerRow:rectified.step fromRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0];

    return MatToUIImage(rectified);
     */
}

+ (NSDictionary *)rectifyImageAndMatrixFrom:(UIImage *)image
                                 withPoints:(NSArray<NSValue *> *)points
                                 outputSize:(CGSize)size
{
    if (points.count != 4 || !image) return nil;
    cv::Mat mat;
    UIImageToMat(image, mat);

    // Convert NSArray<NSValue *> to std::vector<cv::Point2f>
    std::vector<cv::Point2f> srcPoints;
    for (NSValue *val in points) {
        CGPoint cg = [val CGPointValue];
        srcPoints.push_back(cv::Point2f(cg.x, cg.y));
    }

    float width = size.width, height = size.height;
    std::vector<cv::Point2f> dstPoints = { {0,0}, {width,0}, {width,height}, {0,height} };

    // Compute perspective transform
    cv::Mat H = cv::getPerspectiveTransform(srcPoints, dstPoints);

    // Rectify
    cv::Mat rectified;
    cv::warpPerspective(mat, rectified, H, cv::Size(width, height));
    UIImage *rectifiedImg = MatToUIImage(rectified);

    // Extract matrix as NSArray<NSArray<NSNumber *> *>
    NSMutableArray *matrixRows = [NSMutableArray arrayWithCapacity:3];
    for (int r = 0; r < 3; ++r) {
        NSMutableArray *row = [NSMutableArray arrayWithCapacity:3];
        for (int c = 0; c < 3; ++c) {
            [row addObject:@(H.at<double>(r, c))];
        }
        [matrixRows addObject:row];
    }

    return @{
        @"image": rectifiedImg ?: [NSNull null],
        @"matrix": matrixRows
    };
}

+ (UIImage *)warpImage:(UIImage *)image
           withMatrix:(NSArray<NSArray<NSNumber *> *> *)matrix
           outputSize:(CGSize)size
{
    if (!image || matrix.count != 3) return nil;
    for (NSArray *row in matrix) if ([row count] != 3) return nil;

    cv::Mat mat;
    UIImageToMat(image, mat);

    // Convert NSArray to cv::Mat (CV_64F)
    cv::Mat H(3, 3, CV_64F);
    for (int r = 0; r < 3; ++r)
        for (int c = 0; c < 3; ++c)
            H.at<double>(r, c) = [matrix[r][c] doubleValue];

    float width = size.width, height = size.height;
    cv::Mat warped;
    cv::warpPerspective(mat, warped, H, cv::Size(width, height));
    return MatToUIImage(warped);
}

+ (double)meanAbsDiffBetween:(UIImage *)img1 andImg:(UIImage *)img2 {
    cv::Mat mat1;
    cv::Mat mat2;
    
    UIImageToMat(img1, mat1);
    UIImageToMat(img2, mat2);
    
    if (mat1.size() != mat2.size() || mat1.type() != mat2.type()) return DBL_MAX;
    cv::Mat diff;
    cv::absdiff(mat1, mat2, diff);
    return cv::mean(diff)[0];
}

cv::Mat metalBGRA2Gray(const cv::Mat& bgraMat) {
    if (bgraMat.empty() || bgraMat.channels() != 4) return cv::Mat();

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) return cv::Mat();

    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLLibrary> library = [device newDefaultLibrary];
    id<MTLFunction> function = [library newFunctionWithName:@"bgra2grayKernel"];
    NSError *error = nil;
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
    if (!pipeline) return cv::Mat();

    int width = bgraMat.cols, height = bgraMat.rows;
    MTLTextureDescriptor *inDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    inDesc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> inTex = [device newTextureWithDescriptor:inDesc];
    [inTex replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:bgraMat.data bytesPerRow:bgraMat.step];
    
    MTLTextureDescriptor *outDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:width height:height mipmapped:NO];
    outDesc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    id<MTLTexture> outTex = [device newTextureWithDescriptor:outDesc];

    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:pipeline];
    [encoder setTexture:inTex atIndex:0];
    [encoder setTexture:outTex atIndex:1];
    MTLSize threads = MTLSizeMake(width, height, 1);
    MTLSize tpg = MTLSizeMake(1, 1, 1);
    [encoder dispatchThreadgroups:threads threadsPerThreadgroup:tpg];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    cv::Mat gray(height, width, CV_8UC1);
    [outTex getBytes:gray.data bytesPerRow:gray.step fromRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0];
    return gray;
}

+ (UIImage *)metalBinaryRedHSV:(UIImage *)image baselineWhiteHSV:(simd_float3)baselineWhiteHSV {
    cv::Mat mat;
    UIImageToMat(image, mat);
    cv::Mat mask = metalBinaryRedHSV(mat);
    //print baselineWhiteHSV
//    NSLog(@"Baseline White HSV: (%f, %f, %f)", baselineWhiteHSV.x, baselineWhiteHSV.y, baselineWhiteHSV.z);
    return MatToUIImage(mask);
}

+ (UIImage *)metalBinaryRedHSV:(UIImage *)image {
    cv::Mat mat;
    UIImageToMat(image, mat);
    cv::Mat mask = metalBinaryRedHSV(mat);
    //print baselineWhiteHSV
//    NSLog(@"Baseline White HSV: (%f, %f, %f)", baselineWhiteHSV.x, baselineWhiteHSV.y, baselineWhiteHSV.z);
    return MatToUIImage(mask);
}

//cv::Mat metalBinaryRedHSV(const cv::Mat& bgraMat, simd_float3 baselineWhiteHSV) {
    cv::Mat metalBinaryRedHSV(const cv::Mat& bgraMat) {

    if (bgraMat.empty() || bgraMat.channels() != 4) return cv::Mat();

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) return cv::Mat();

    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLLibrary> library = [device newDefaultLibrary];
    id<MTLFunction> function = [library newFunctionWithName:@"binaryRedHSVKernel"];
    NSError *error = nil;
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];
    if (!pipeline) return cv::Mat();

    int width = bgraMat.cols, height = bgraMat.rows;
    MTLTextureDescriptor *inDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    inDesc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> inTex = [device newTextureWithDescriptor:inDesc];
    [inTex replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:bgraMat.data bytesPerRow:bgraMat.step];

    MTLTextureDescriptor *outDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:width height:height mipmapped:NO];
    outDesc.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    id<MTLTexture> outTex = [device newTextureWithDescriptor:outDesc];
    
    // Create buffer for baselineWhiteHSV
//    id<MTLBuffer> hsvBuffer = [device newBufferWithBytes:&baselineWhiteHSV length:sizeof(simd_float3) options:MTLResourceStorageModeShared];

    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:pipeline];
    [encoder setTexture:inTex atIndex:0];
    [encoder setTexture:outTex atIndex:1];
//    [encoder setBuffer:hsvBuffer offset:0 atIndex:0]; // Pass baselineWhiteHSV as buffer(0)
    MTLSize threads = MTLSizeMake(width, height, 1);
    MTLSize tpg = MTLSizeMake(1, 1, 1);
    [encoder dispatchThreadgroups:threads threadsPerThreadgroup:tpg];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    cv::Mat mask(height, width, CV_8UC1);
    [outTex getBytes:mask.data bytesPerRow:mask.step fromRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0];
    return mask;
}

+ (double)metalMeanAbsDiffBetween:(UIImage *)img1 andImg:(UIImage *)img2 {
    cv::Mat mat1, mat2;
    UIImageToMat(img1, mat1);
    UIImageToMat(img2, mat2);
    if (mat1.size() != mat2.size() || mat1.type() != mat2.type()) return DBL_MAX;

    // Ensure CV_8UC4
    if (mat1.type() != CV_8UC4) cv::cvtColor(mat1, mat1, cv::COLOR_BGR2BGRA);
    if (mat2.type() != CV_8UC4) cv::cvtColor(mat2, mat2, cv::COLOR_BGR2BGRA);

    int width = mat1.cols, height = mat1.rows;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLLibrary> library = [device newDefaultLibrary];
    id<MTLFunction> function = [library newFunctionWithName:@"meanAbsDiffKernel"];
    NSError *error = nil;
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:width height:height mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> tex1 = [device newTextureWithDescriptor:desc];
    id<MTLTexture> tex2 = [device newTextureWithDescriptor:desc];
    [tex1 replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:mat1.data bytesPerRow:mat1.step];
    [tex2 replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:mat2.data bytesPerRow:mat2.step];

    uint32_t zero = 0;
    id<MTLBuffer> sumBuffer = [device newBufferWithBytes:&zero length:sizeof(uint32_t) options:MTLResourceStorageModeShared];

    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [cmdBuf computeCommandEncoder];
    [encoder setComputePipelineState:pipeline];
    [encoder setTexture:tex1 atIndex:0];
    [encoder setTexture:tex2 atIndex:1];
    [encoder setBuffer:sumBuffer offset:0 atIndex:0];
    MTLSize threads = MTLSizeMake(width, height, 1);
    MTLSize tpg = MTLSizeMake(8, 8, 1);
    [encoder dispatchThreadgroups:MTLSizeMake((width+7)/8, (height+7)/8, 1) threadsPerThreadgroup:tpg];
    [encoder endEncoding];
    [cmdBuf commit];
    [cmdBuf waitUntilCompleted];

    uint32_t sum = *(uint32_t *)sumBuffer.contents;
    double mean = (double)sum / (width * height * 3); // 3 channels
    return mean;
}
@end// Objective-C++
