//
//  shared.metal
//  SwiftGradient
//
//  Created by Pat Trudel on 5/28/22.
//

#include <metal_stdlib>
using namespace metal;

float4 interpolate_color(constant float4 *colors, constant float *locations, uint count, float location);
float4 interpolate_color(constant float4 *colors, constant float *locations, uint count, float location) {
    uint lower = 0;
    uint upper;
    for (upper = 0; upper < count; upper++) {
        if (locations[upper] > location) {
            break;
        }
        lower = upper;
    }
    float numerator = location - locations[lower];
    float denominator = locations[upper] - locations[lower];
    float fraction = (denominator != 0.0) ? saturate(numerator / denominator) : 0.0;
    return mix(colors[lower], colors[upper], fraction);
}

float2 fix_aspect_ratio(float2 coordinate, float aspect_ratio);
float2 fix_aspect_ratio(float2 coordinate, float aspect_ratio) {
    coordinate -= float2(0.5, 0.5);
    coordinate /= float2(1.0, aspect_ratio);
    coordinate += float2(0.5, 0.5);
    return coordinate;
}
