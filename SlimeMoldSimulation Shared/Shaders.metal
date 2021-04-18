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
                              texture2d<float> slimeTexture [[texture(0)]],
                              uint vid [[vertex_id]])
{
    VertexOut out;

    float2 xy = vertices[vid].xy * float2(slimeTexture.get_width(), slimeTexture.get_height());
    out.position = uniforms.projectionMatrix * float4(xy, 0.0, 1.0);
    out.uv = vertices[vid].zw;

    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]],
                               texture2d<float> texture [[texture(0)]])
{
    constexpr sampler s;
    
    float4 sum = 0.0;
    const int AA = 2;
    
    for (int m = 0; m < AA; m++)
    {
        for (int n = 0; n < AA; n++)
        {
            // Divide 0-1 range in blocks for each sample and get the center of each block
            // Offset it by 0.5 to get the offset from the central sample point
            float blockSize = 1.0 / float(AA);
            float2 o = float2(float(m), float(n)) * blockSize + blockSize / 2.0 - 0.5;

            // Scale by the screen size to get the correct uv scaling
            o /= uniforms.screenSize;

            sum += texture.sample(s, in.uv + o);
        }
    }
    
    return sum / (AA * AA);
}

float2 wrapPosition(float2 position, float width, float height)
{
    float xPositive = step(0, position.x);
    float yPositive = step(0, position.y);
    position.x = (1.0 - xPositive) * (width + position.x) + xPositive * fmod(position.x, width);
    position.y = (1.0 - yPositive) * (height + position.y) + yPositive * fmod(position.y, height);
    return position;
}

float sense(Agent agent, float sensorOffset, float sensorAngleOffset, texture2d<float, access::read_write> slimeTexture)
{
    float sensorAngle = agent.angle + sensorAngleOffset;
    float2 sensorPos = agent.position + float2(cos(sensorAngle), sin(sensorAngle)) * sensorOffset;
    
    float sum = 0;
//    for (float i = -1; i <= 1; i++)
//    {
//        for (float j = -1; j <= 1; j++)
//        {
//            float2 sensePos = sensorPos + float2(i, j);
//            sensePos = wrapPosition(sensePos, slimeTexture.get_width(), slimeTexture.get_height());
//            sum += dot(1.0, slimeTexture.read(uint2(sensePos)));
//        }
//    }
    
    float2 sensePos = wrapPosition(sensorPos, slimeTexture.get_width(), slimeTexture.get_height());
    sum = slimeTexture.read(uint2(sensePos)).x;
    
    return sum;
}

kernel void agentInitKernel(device Agent *agents [[buffer(0)]],
                            texture2d<float> slimeTexture,
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint gid [[thread_position_in_grid]])
{
    const float2 textureSize = float2(slimeTexture.get_width(), slimeTexture.get_height());
    
    const float h = hash01(gid);
    const float angle = h * M_PI_F * 2.0 - M_PI_F;
    const float radius = hash01(uint(h * 4294967295.0)) * 320.0;
    
    agents[gid].position.x = textureSize.x / 2 + cos(angle) * radius;
    agents[gid].position.y = textureSize.y / 2 + sin(angle) * radius;
    
//    agents[gid].position.x = random(h * 13.0) * textureSize.x;
//    agents[gid].position.y = random(h * 17.0) * textureSize.y;
    
//    float2 toOuter = normalize(agents[gid].position - textureSize / 2);
//    agents[gid].angle = atan2(toOuter.y, toOuter.x);
    
//    float2 toCenter = normalize(textureSize / 2 - agents[gid].position);
//    agents[gid].angle = atan2(toCenter.y, toCenter.x);
    
//    agents[gid].angle = angle;
    agents[gid].angle = random(h) * M_PI_F * 2.0;
}

kernel void slimeKernel(texture2d<float, access::read_write> slimeTexture,
                        device Agent *agents [[buffer(0)]],
                        constant Uniforms &uniforms [[buffer(1)]],
                        uint gid [[thread_position_in_grid]])
{
    Agent agent = agents[gid];
    float current = slimeTexture.read(uint2(agent.position)).x;
    float sensorOffset = mix(0.0, uniforms.sensorOffset, current);
    float sensorAngleOffset = mix(M_PI_F / 4.0, M_PI_F / 8.0, current);
    float weightLeft = sense(agent, sensorOffset, sensorAngleOffset, slimeTexture);
    float weightRight = sense(agent, sensorOffset, -sensorAngleOffset, slimeTexture);
    float weightForward = sense(agent, sensorOffset, 0, slimeTexture);
    
    float maxWeight = max(max(weightLeft, weightRight), weightForward);
    
    float randomSteerStrength = hash01(agent.position.y * slimeTexture.get_width() + agent.position.x + hash(gid + uniforms.time * 100000.0));
    float turnRate = uniforms.turnRate * 2.0 * M_PI_F * (1.0 + current * 3.0);

    if (weightForward > weightLeft && weightForward > weightRight) {
//        agents[gid].angle += current * (randomSteerStrength - 0.5) * 0.1 * turnRate * uniforms.deltaTime;
    }
    else if (weightForward < weightLeft && weightForward < weightRight) {
        agents[gid].angle += (randomSteerStrength - 0.5) * 2 * turnRate * uniforms.deltaTime;
    }
    else if (weightRight > weightLeft) {
        agents[gid].angle -= randomSteerStrength * turnRate * uniforms.deltaTime;
    }
    else if (weightLeft > weightRight) {
        agents[gid].angle += randomSteerStrength * turnRate * uniforms.deltaTime;
    }
    
//    float forwardBest = step(max(weightLeft, weightRight) + 0.000001, weightForward);
//    float leftBest = (1.0 - forwardBest) * step(weightRight + 0.000001, weightLeft);
//    float rightBest = (1.0 - forwardBest) * step(weightLeft + 0.000001, weightRight);
//
//    float randomTurn = step(weightForward + 0.000001, weightLeft) * step(weightForward + 0.000001, weightRight);
//
//    float rand = hash01(agent.position.y * slimeTexture.get_width() + agent.position.x + hash(gid + uniforms.time * 100000.0));
//
//    float turn = leftBest * turnRate * uniforms.deltaTime + rightBest * -turnRate * uniforms.deltaTime;
//    agents[gid].angle += turn * mix(1.0, rand, 1.0) * (1.0 - randomTurn) + randomTurn * (rand - 0.5) * 2.0 * turnRate * uniforms.deltaTime;
//    agent.moveSpeed += maxWeight * 20.0 * uniforms.deltaTime;
    
    float2 direction = float2(cos(agents[gid].angle), sin(agents[gid].angle));
    float2 newPosition = agent.position + direction * uniforms.moveSpeed * uniforms.deltaTime * current;
    newPosition = wrapPosition(newPosition, slimeTexture.get_width(), slimeTexture.get_height());
    
    agents[gid].position = newPosition;
//    agents[gid].moveSpeed = agent.moveSpeed - uniforms.deltaTime * 1.0;
    
    float4 newTrail = slimeTexture.read(uint2(newPosition)) + uniforms.color;
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
    
    float diffuseWeight = saturate(uniforms.diffuseRate * uniforms.deltaTime);

    float4 color = (1.0 - diffuseWeight) * baseColor + diffuseWeight * blurredCol;
    color = max(0.0, color - uniforms.decayRate * uniforms.deltaTime);
    
    slimeTexture.write(color, gid);
}
