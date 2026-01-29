#include <metal_stdlib>
using namespace metal;

kernel void bgra2grayKernel(texture2d<float, access::read> inTex [[texture(0)]],
                            texture2d<float, access::write> outTex [[texture(1)]],
                            uint2 gid [[thread_position_in_grid]]) {
    // Note: The alpha channel is preserved from the input pixel
    if (gid.x >= inTex.get_width() || gid.y >= inTex.get_height()) {
        return;
    }
    
    // Read the BGRA pixel
    float4 pixel = inTex.read(gid);
    
    // Convert to grayscale using the luminosity method
    float gray = static_cast<ushort>(0.299f * pixel.x + 0.587f * pixel.y + 0.114f * pixel.z);
    
    // Write the grayscale pixel to the output texture
    outTex.write(float4(gray, gray, gray, pixel.w), gid);
}
