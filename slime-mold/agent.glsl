#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct Agent {
    vec2 pos;
    float angle;
    float species; // padding / future use
};

layout(set = 0, binding = 0, std430) restrict buffer AgentBuffer {
    Agent agents[];
};

layout(set = 0, binding = 1, r32f) uniform restrict image2D trail_map;

layout(push_constant, std430) uniform Params {
    float time;
    float delta;
    float width;
    float height;
    float move_speed;
    float turn_speed;
    float sensor_angle;
    float sensor_dist;
    float sensor_size;
    float deposit_amount;
    float agent_count;
    float pad1;
} params;

#define PI 3.14159265358979323846

float sense(vec2 pos, float angle) {
    vec2 dir = vec2(cos(angle), sin(angle));
    ivec2 sample_pos = ivec2(pos + dir * params.sensor_dist);
    sample_pos = clamp(sample_pos, ivec2(0), ivec2(params.width - 1, params.height - 1));
    return imageLoad(trail_map, sample_pos).r;
}

// Simple hash for randomness per agent
float hash(uint n) {
    n = (n << 13u) ^ n;
    n = n * (n * n * 15731u + 789221u) + 1376312589u;
    return float(n & uint(0x7fffffff)) / float(0x7fffffff);
}

void main() {
    uint i = gl_GlobalInvocationID.x;
    if (i >= uint(params.agent_count)) return;

    Agent agent = agents[i];

    // --- Sense ---
    float center = sense(agent.pos, agent.angle);
    float left   = sense(agent.pos, agent.angle + params.sensor_angle);
    float right  = sense(agent.pos, agent.angle - params.sensor_angle);

    // --- Steer ---
    float rand = hash(i + uint(params.time * 100000.0));

    if (center > left && center > right) {
        // Continue forward
    } else if (center < left && center < right) {
        // Both sides stronger — randomly pick
        agent.angle += (rand - 0.5) * 2.0 * params.turn_speed * params.delta;
    } else if (left > right) {
        agent.angle += params.turn_speed * params.delta;
    } else if (right > left) {
        agent.angle -= params.turn_speed * params.delta;
    }

    // --- Move ---
    vec2 dir = vec2(cos(agent.angle), sin(agent.angle));
    agent.pos += dir * params.move_speed * params.delta;

    // --- Bounce off walls ---
    if (agent.pos.x < 0.0 || agent.pos.x >= params.width) {
    agent.pos.x = clamp(agent.pos.x, 0.0, params.width - 1.0);
    agent.angle = PI - agent.angle;
    }
    if (agent.pos.y < 0.0 || agent.pos.y >= params.height) {
        agent.pos.y = clamp(agent.pos.y, 0.0, params.height - 1.0);
        agent.angle = -agent.angle;
    }

    // --- Deposit ---
    ivec2 deposit_pos = ivec2(agent.pos);
    vec4 existing = imageLoad(trail_map, deposit_pos);
    imageStore(trail_map, deposit_pos, vec4(min(1.0, existing.r + params.deposit_amount), 0, 0, 1));

    agents[i] = agent;
}
