#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float frostHash(float2 p) {
    p = fract(p * float2(0.1031, 0.11369));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

[[ stitchable ]] half4 roughFrost(float2 position, half4 color, float intensity) {
    float2 coarseCell = floor(position / 3.0);
    float2 fineCell = floor(position / 1.35);
    float coarseNoise = frostHash(coarseCell);
    float fineNoise = frostHash(fineCell);
    float scratches = smoothstep(0.78, 1.0, frostHash(float2(position.y * 0.06, floor(position.x / 28.0))));
    float frost = (coarseNoise * 0.62 + fineNoise * 0.28 + scratches * 0.22) * intensity;
    
    half3 roughened = color.rgb + half3(frost * 0.34);
    roughened = mix(roughened, half3(1.0), half(frost * 0.22));
    
    return half4(roughened, color.a);
}
