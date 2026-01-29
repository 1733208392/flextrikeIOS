//
//  meanAbsDiffKernel.metal
//  opencvtestminimal
//
//  Created by Kai Yang on 2025/6/26.
//


#include <metal_stdlib>
using namespace metal;

kernel void meanAbsDiffKernel(
    texture2d<float, access::sample> inTex1 [[texture(0)]],
    texture2d<float, access::sample> inTex2 [[texture(1)]],
    device atomic_uint &sum [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = inTex1.get_width();
    uint height = inTex1.get_height();
    if (gid.x >= width || gid.y >= height) return;

    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    float4 c1 = inTex1.sample(s, float2(gid) / float2(width, height));
    float4 c2 = inTex2.sample(s, float2(gid) / float2(width, height));
    float diff = fabs(c1.x - c2.x) + fabs(c1.y - c2.y) + fabs(c1.z - c2.z);
    atomic_fetch_add_explicit(&sum, uint(diff * 255.0f), memory_order_relaxed);
}