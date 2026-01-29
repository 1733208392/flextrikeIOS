//
//  binaryRedHSVKernel.metal
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/25.
//


#include <metal_stdlib>
using namespace metal;

float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

kernel void binaryRedHSVKernel(texture2d<float, access::read> inTex [[texture(0)]],
                              texture2d<float, access::write> outTex [[texture(1)]],
//                              constant float3 &baselineWhiteHSV [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= inTex.get_width() || gid.y >= inTex.get_height()) return;
    float4 bgra = inTex.read(gid);
    float3 rgb = float3(bgra.z, bgra.y, bgra.x); // BGRA to RGB
    float3 hsv = rgb2hsv(rgb);

    // Red: H in [0,0.05] or [0.9,1], S > 0.5, V > 0.5
    bool isRed = ((hsv.x < 0.05 || hsv.x > 0.9) && hsv.y > 0.5 && hsv.z > 0.5); //z was 0.2
    uchar outVal = isRed ? 255 : 0;
    outTex.write(outVal, gid);

    // Red hue range (normalized): around 0.0 or 1.0
//    bool isRed = (hsv.x < 0.05 || hsv.x > 0.95);
//    // Calibrate S and V thresholds based on baseline white
//    float sThresh = max(0.5, baselineWhiteHSV.y + 0.2); // require more saturation than white
//    float vThresh = min(0.9, baselineWhiteHSV.z - 0.1); // require less value than white
//
//    bool isRedCalibrated = isRed && hsv.y > sThresh && hsv.z > vThresh;
//    outTex.write(float4(isRedCalibrated ? 1.0 : 0.0), gid);
}
