#include <metal_stdlib>
using namespace metal;

kernel void warpPerspectiveKernel(
    texture2d<float, access::sample>  inTexture  [[texture(0)]],
    texture2d<float, access::write>   outTexture [[texture(1)]],
    device const float*               H          [[buffer(0)]],
    uint2                             gid        [[thread_position_in_grid]]
) {
    uint width  = outTexture.get_width();
    uint height = outTexture.get_height();
    if (gid.x >= width || gid.y >= height) return;

    float x = gid.x;
    float y = gid.y;

    float srcX = H[0]*x + H[1]*y + H[2];
    float srcY = H[3]*x + H[4]*y + H[5];
    float w    = H[6]*x + H[7]*y + H[8];

    if (w == 0.0f) {
        outTexture.write(float4(0,0,0,0), gid);
        return;
    }

    srcX /= w;
    srcY /= w;

    float2 normSrc = float2(srcX / float(inTexture.get_width()), srcY / float(inTexture.get_height()));

    constexpr sampler s(address::clamp_to_edge, filter::linear);

    if (normSrc.x < 0.0 || normSrc.x > 1.0 || normSrc.y < 0.0 || normSrc.y > 1.0) {
        outTexture.write(float4(0,0,0,0), gid);
    } else {
        float4 color = inTexture.sample(s, normSrc);
        outTexture.write(color, gid);
    }
}
