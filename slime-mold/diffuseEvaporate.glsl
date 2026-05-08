#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32f) uniform restrict image2D trail_map;
layout(set = 0, binding = 1, rgba8) uniform restrict writeonly image2D display;

layout(push_constant, std430) uniform Params {
    float evaporate_speed;
    float diffuse_speed;
    float delta;
    float pad;
} params;

void main() {
    ivec2 coord = ivec2(gl_GlobalInvocationID.xy);
    ivec2 img_size = ivec2(imageSize(trail_map));
    if (coord.x >= img_size.x || coord.y >= img_size.y) return;

    // Box blur 3x3 (diffusion)
    float total = 0.0;
    for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
            ivec2 tap = clamp(coord + ivec2(dx, dy), ivec2(0), img_size - 1);
            total += imageLoad(trail_map, tap).r;
        }
    }
    float blurred = total / 9.0;

    // Blend between original and blurred, then evaporate
    float original = imageLoad(trail_map, coord).r;
    float diffused = mix(original, blurred, params.diffuse_speed * params.delta);
    float evaporated = max(0.0, diffused - params.evaporate_speed * params.delta);

    imageStore(trail_map, coord, vec4(evaporated, 0, 0, 1));

    // Write to display — color map the trail value
    vec3 color = mix(vec3(0.0), vec3(0.1, 0.8, 1.0), evaporated);
    imageStore(display, coord, vec4(color, 1.0));
}
