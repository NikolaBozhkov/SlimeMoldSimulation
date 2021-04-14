//
//  Shaders.metal
//  SlimeMoldSimulation Shared
//
//  Created by Nikola Bozhkov on 13.04.21.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float4 position [[position]];
    float2 uv;
} VertexOut;

float random(float x)
{
    return fract(sin(x) * 43758.5453123);
}

float random(float2 xy)
{
    return fract(sin(dot(xy, float2(12.9898,78.233)))*43758.5453123);
}

// Hash function www.cs.ubc.ca/~rbridson/docs/schechter-sca08-turbulence.pdf
uint hash(uint state)
{
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    return state;
}

float hash01(uint state)
{
    return hash(state) / 4294967295.0;
}

vertex VertexOut vertexShader(constant float4 *vertices [[buffer(BufferIndexVertices)]],
                              constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]],
                              uint vid [[vertex_id]])
{
    VertexOut out;

    out.position = uniforms.projectionMatrix * float4(vertices[vid].xy * uniforms.screenSize, 0.0, 1.0);
    out.uv = vertices[vid].zw;

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]],
                               texture2d<float> texture [[texture(0)]])
{
    constexpr sampler s;
    return texture.sample(s, in.uv);
}

float2 wrapPosition(float2 position, float width, float height)
{
    float xPositive = step(0, position.x);
    float yPositive = step(0, position.y);
    position.x = (1.0 - xPositive) * (width + position.x) + xPositive * fmod(position.x, width);
    position.y = (1.0 - yPositive) * (height + position.y) + yPositive * fmod(position.y, height);
    return position;
}

float sense(Agent agent, float sensorAngleOffset, texture2d<float, access::read_write> slimeTexture)
{
    const float sensorOffset = 35.0;
    
    float sensorAngle = agent.angle + sensorAngleOffset;
    float2 sensorPos = agent.position + float2(cos(sensorAngle), sin(sensorAngle)) * sensorOffset;
    
    float sum = 0;
    for (float i = -1; i <= 1; i++)
    {
        for (float j = -1; j <= 1; j++)
        {
            float2 sensePos = sensorPos + float2(i, j);
            sensePos = wrapPosition(sensePos, slimeTexture.get_width(), slimeTexture.get_height());
            sum += dot(1.0, slimeTexture.read(uint2(sensePos)));
        }
    }
    
//    float intensity = sum.x / 9.0;
    
//    float2 sensePos = sensorPos;
//    sensePos = wrapPosition(sensePos, slimeTexture.get_width(), slimeTexture.get_height());
//    intensity = slimeTexture.read(uint2(sensePos)).x;
    
    return sum;
}

kernel void slimeKernel(texture2d<float, access::read_write> slimeTexture,
                        device Agent *agents [[buffer(0)]],
                        constant Uniforms &uniforms [[buffer(1)]],
                        uint gid [[thread_position_in_grid]])
{
    const float sensorAngleOffset = M_PI_F / 6.2;
    const float turnRate = M_PI_F * 2.0 * 2.0;
        
    Agent agent = agents[gid];
    float weightLeft = sense(agent, sensorAngleOffset, slimeTexture);
    float weightRight = sense(agent, -sensorAngleOffset, slimeTexture);
    float weightForward = sense(agent, 0, slimeTexture);
    
//    float randomSteerStrength = hash01(agent.position.y * slimeTexture.get_width() + agent.position.x + hash(gid + uniforms.time * 100000.0));
//    float turnSpeed = 2.0 * 2.0 * M_PI_F;
//
//    // Continue in same direction
//    if (weightForward > weightLeft && weightForward > weightRight) {
//        agents[gid].angle += 0;
//    }
//    else if (weightForward < weightLeft && weightForward < weightRight) {
//        agents[gid].angle += (randomSteerStrength - 0.5) * 2 * turnSpeed * uniforms.deltaTime;
//    }
//    // Turn right
//    else if (weightRight > weightLeft) {
//        agents[gid].angle -= randomSteerStrength * turnSpeed * uniforms.deltaTime;
//    }
//    // Turn left
//    else if (weightLeft > weightRight) {
//        agents[gid].angle += randomSteerStrength * turnSpeed * uniforms.deltaTime;
//    }
    
    float forwardBest = step(max(weightLeft, weightRight) + 0.000001, weightForward);
    float leftBest = (1.0 - forwardBest) * step(weightRight + 0.000001, weightLeft);
    float rightBest = (1.0 - forwardBest) * step(weightLeft + 0.000001, weightRight);

    float randomTurn = step(weightForward + 0.000001, weightLeft) * step(weightForward + 0.000001, weightRight);

    float rand = hash01(agent.position.y * slimeTexture.get_width() + agent.position.x + hash(gid + uniforms.time * 100000.0));

    float turn = leftBest * turnRate * uniforms.deltaTime + rightBest * -turnRate * uniforms.deltaTime;
    agents[gid].angle += turn * mix(1.0, rand, 1.0) * (1.0 - randomTurn) + randomTurn * (rand - 0.5) * 2.0 * turnRate * uniforms.deltaTime;
    
//    float randomTurn1 = step(max(max(intensityLeft, intensityRight), intensityForward), hash01(gid));
//    agent.angle += randomTurn1 * turnRate * (hash01(gid) - 0.5) * 2.0;

    float2 direction = float2(cos(agents[gid].angle), sin(agents[gid].angle));
    float2 newPosition = agent.position + direction * uniforms.moveSpeed * uniforms.deltaTime;
    newPosition = wrapPosition(newPosition, slimeTexture.get_width(), slimeTexture.get_height());
    
    agents[gid].position = newPosition;
    
    float4 color = float4(0.2, 0.75, 0.4, 1.0);
    float4 newTrail = slimeTexture.read(uint2(newPosition)) + color * 5.0 * uniforms.deltaTime;
    slimeTexture.write(min(1.0, newTrail), uint2(newPosition));
}

kernel void diffuseKernel(texture2d<float, access::read_write> slimeTexture,
                          constant Uniforms &uniforms [[buffer(1)]],
                          uint2 gid [[thread_position_in_grid]])
{
    float4 sum = 0;
    
    // 3x3 blur
    for (int i = -1; i <= 1; i++)
    {
        for (int j = -1; j <= 1; j++)
        {
            uint2 pos = clamp(gid + uint2(i, j), 0, uint2(slimeTexture.get_width() - 1, slimeTexture.get_height() - 1));
            sum += slimeTexture.read(pos);
        }
    }
    
    float4 blurredCol = sum / 9.0;
    float4 baseColor = slimeTexture.read(gid);
    
    const float diffuseRate = 4.0, decayRate = 0.27;
    float diffuseWeight = saturate(diffuseRate * uniforms.deltaTime);

    float4 color = (1.0 - diffuseWeight) * baseColor + diffuseWeight * blurredCol;
    color = max(0.0, color - decayRate * uniforms.deltaTime);
    
    slimeTexture.write(color, gid);
}
