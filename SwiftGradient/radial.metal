//
//  radial.metal
//  SwiftGradient
//
//  Created by Pat Trudel on 5/28/22.
//

#include <metal_stdlib>
using namespace metal;

struct RadialUniforms {
    float2 center;
    float radius;
    uint stops;
};

float4 interpolate_color(constant float4 *colors, constant float *locations, uint count, float location);
float2 fix_aspect_ratio(float2 coordinate, float aspect_ratio);

kernel void radial(
                  constant RadialUniforms *uniforms [[buffer(0)]],
                  constant float4 *colors [[buffer(1)]],
                  constant float *locations [[buffer(2)]],
                  texture2d<float, access::write> texture [[ texture(0) ]],
                  uint2 global_id [[ thread_position_in_grid ]])
{
    // Make sure we're inside the output texture's bounds
    // (Workgroups don't necessarily have to line-up with texture dimensions):
    if (global_id.x >= texture.get_width() || global_id.y >= texture.get_height()) {
        return;
    }

    // Get output's dimensions:
    const float2 dimensions = float2(texture.get_width(), texture.get_height());

    // Get output's aspect ratio:
    const float aspect_ratio = dimensions.x / dimensions.y;

    // Get normalized 2D coordinate of output texture pixel:
    const float2 coordinate = fix_aspect_ratio(float2(global_id) / dimensions, aspect_ratio);
    const float2 center = fix_aspect_ratio(uniforms->center, aspect_ratio);
    const float radius = uniforms->radius;

    const float2 direction = coordinate - center;
    const float linearLocation = saturate(length(direction) / radius);
    const float sigmoidalLocation = smoothstep(0.0, 1.0, linearLocation);
    const float location = sigmoidalLocation;
    
    const float4 result_color = interpolate_color(colors, locations, uniforms->stops, location);

    texture.write(result_color, global_id);
}
