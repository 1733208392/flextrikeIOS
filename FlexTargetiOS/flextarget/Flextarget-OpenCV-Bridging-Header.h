//
//
//  Created by Kai Yang on 2025/6/22.
//

#ifndef Flextarget-OpenCV-Bridging-Header_h
#define Flextarget-OpenCV-Bridging-Header_h

// Only import OpenCV when building for device
#if TARGET_OS_SIMULATOR
// Simulator build - exclude OpenCV
#else
// Device build - include OpenCV
#import "OpenCVWrapper.h"
#endif

#endif /* Flextarget-OpenCV-Bridging-Header_h */
