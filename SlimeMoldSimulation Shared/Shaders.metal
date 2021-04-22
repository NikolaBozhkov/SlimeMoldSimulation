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

#define PHI 1.618034
#define THETA -0.618034
#define SQRT_5 2.236068

#define SDF_R 0.3
#define THOLD 0.1
#define W_OFFSET -0.025
#define OFFSET float2(0.46, 0.46)

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
    const int AA = 4;

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
    
    float4 col = sum / (AA * AA);
    float scale = 50.0 * M_PI_F;
    float4 bg = float4(0.07) * step(0.0, sin(in.uv.x * scale) * cos(in.uv.y * scale));
    return mix(col, bg, step(col.w, 0.00001));
}

float2 wrapPosition(float2 position, float width, float height)
{
    float xPositive = step(0, position.x);
    float yPositive = step(0, position.y);
    position.x = (1.0 - xPositive) * (width + position.x) + xPositive * fmod(position.x, width);
    position.y = (1.0 - yPositive) * (height + position.y) + yPositive * fmod(position.y, height);
    return position;
}

float sdEquilateralTriangle(float2 p)
{
    const float k = sqrt(3.0);
    p.x = abs(p.x) - 1.0;
    p.y = p.y + 1.0/k;
    if( p.x+k*p.y>0.0 ) p = float2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0, 0.0 );
    return -length(p)*sign(p.y);
}

float sdEquilateralTriangle(float2 p, float r)
{
    const float k = sqrt(3.0);
    p.x = abs(p.x) - r;
    p.y = p.y + r/k;
    if( p.x+k*p.y>0.0 ) p=float2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0*r, 0.0 );
    return -length(p)*sign(p.y);
}

float2x2 rotate2d(float a)
{
    const float s = sin(a);
    const float c = cos(a);
    const float2x2 m = float2x2(c, -s, s, c);
    return m;
}

kernel void agentInitKernel(device Agent *agents [[buffer(0)]],
                            texture2d<float> slimeTexture,
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint gid [[thread_position_in_grid]])
{
    const float2 textureSize = float2(slimeTexture.get_width(), slimeTexture.get_height());
    
    const float h = hash01(gid);
    const float angle = h * M_PI_F * 2.0 - M_PI_F;
    const float radius = hash01(uint(h * 4294967295.0)) * 420.0;
    
//    agents[gid].position.x = textureSize.x / 2 + cos(angle) * radius;
//    agents[gid].position.y = textureSize.y / 2 + sin(angle) * radius;
    
    float rand = random(h * 7.0 + 3.17);
    
    float i0Pct = 0.22, i1Pct = 0.22, i2Pct = 0.3, i3Pct = 0.26;
    
//    float i0 = step(0.0, rand) - step(i0Pct, rand);
//    float i1 = step(i0Pct, rand) - step(i0Pct + i1Pct, rand);
//    float i2 = step(i0Pct + i1Pct, rand) - step(i0Pct + i1Pct + i2Pct, rand);
//    float i3 = step(i0Pct + i1Pct + i2Pct, rand) - step(i0Pct + i1Pct + i2Pct + i3Pct, rand);
    
    float2 p = float2(random(h * 13.0), random(h * 17.0)) * 2.0 - 1.0;
    const float spawnR = 0.15;
    p *= textureSize * float2(spawnR);
    
    float2 offset = (1.0 - OFFSET) * 0.5;
    
    if (rand >= 0.0 && rand < i0Pct)
    {
        agents[gid].position = textureSize * float2(offset.x, 1.0 - offset.y) + p;
        agents[gid].mask = 0;
    }
    else if (rand >= i0Pct && rand < i0Pct + i1Pct)
    {
        agents[gid].position = textureSize * (1.0 - offset) + p;
        agents[gid].mask = 1;
    }
    else if (rand >= i0Pct + i1Pct && rand < i0Pct + i1Pct + i2Pct)
    {
        agents[gid].position = textureSize * offset + p;
        agents[gid].mask = 2;
    }
    else if (rand >= i0Pct + i1Pct + i2Pct && rand < i0Pct + i1Pct + i2Pct + i3Pct)
    {
        agents[gid].position = textureSize.x * float2(1.0 - offset.x, offset.y) + p;
        agents[gid].mask = 3;
    }
    
//    float2 toOuter = normalize(agents[gid].position - textureSize / 2);
//    agents[gid].angle = atan2(toOuter.y, toOuter.x);
    
//    float2 toCenter = normalize(textureSize / 2 - agents[gid].position);
//    agents[gid].angle = atan2(toCenter.y, toCenter.x);
    
//    agents[gid].angle = angle;
    agents[gid].angle = random(h) * M_PI_F * 2.0;
    
//    agents[gid].moveSpeed = 0.0;
}

float sdUnion(float2 p)
{
    float2 sdtOffset = float2(-OFFSET.x, OFFSET.y + SDF_R * 0.25);
    float sdt = sdEquilateralTriangle(p + sdtOffset, SDF_R);
    
    float2 p1 = rotate2d(M_PI_F) * p;
    float sdt1 = abs(sdEquilateralTriangle(p1 + sdtOffset, SDF_R - W_OFFSET)) - W_OFFSET;
    
    float sdc = length(p + OFFSET) - SDF_R;
    
    float sdc1 = abs(length(p - OFFSET) - SDF_R + W_OFFSET) - W_OFFSET;

    return min(min(sdt, sdt1), min(sdc, sdc1));
}

float2 sdUnionInfo(float2 p)
{
    float2 sdtOffset = float2(-OFFSET.x, OFFSET.y + SDF_R * 0.25);
    float sdt = sdEquilateralTriangle(p + sdtOffset, SDF_R);
    
    float2 p1 = rotate2d(M_PI_F) * p;
    float sdt1 = abs(sdEquilateralTriangle(p1 + sdtOffset, SDF_R - W_OFFSET)) - W_OFFSET;
    
    float sdc = length(p + OFFSET) - SDF_R;
    
    float sdc1 = abs(length(p - OFFSET) - SDF_R + W_OFFSET) - W_OFFSET;
    
    float sd = min(min(sdt, sdt1), min(sdc, sdc1));
    float isOutline = step(min(sdt1, sdc1), min(sdt, sdc));
    return float2(sd, isOutline);
}

float sense(Agent agent, float sensorOffset, float sensorAngleOffset, texture2d<float, access::read_write> slimeTexture)
{
    float sensorAngle = agent.angle + sensorAngleOffset;
    float2 sensorPos = agent.position + float2(cos(sensorAngle), sin(sensorAngle)) * sensorOffset;
    
    float sum = 0;
    
    float2 sensePos = wrapPosition(sensorPos, slimeTexture.get_width(), slimeTexture.get_height());
    sum = slimeTexture.read(uint2(sensePos)).x;
    
    const float2 center = float2(slimeTexture.get_width(), slimeTexture.get_height()) / 2.0;
    
    float2 p = (sensorPos - center) / (slimeTexture.get_width() * 0.5);
    float sd = sdUnion(p);
    
    return mix(sum, -sd, step(THOLD, sd));
}

kernel void slimeKernel(texture2d<float, access::read_write> slimeTexture,
                        device Agent *agents [[buffer(0)]],
                        constant Uniforms &uniforms [[buffer(1)]],
                        uint gid [[thread_position_in_grid]])
{
//    const float maxSpeed = 200.0, minSpeed = 2.0;
    Agent agent = agents[gid];
    float current = slimeTexture.read(uint2(agent.position)).w;
//    float speedF = agent.moveSpeed / maxSpeed;
    
    const float2 center = float2(slimeTexture.get_width(), slimeTexture.get_height()) / 2.0;
    
    float2 p = (agent.position - center) / (slimeTexture.get_width() * 0.5);
    float2 sdInfo = sdUnionInfo(p);
    float sd = sdInfo.x;
    float thold = THOLD * (1.0 + sdInfo.y * 0.2);
    float t = 1.0 - smoothstep(0.0, thold, sd);
    
    float branchIndex = floor(current * uniforms.branchCount) + 30.0;
    float sensorOffset = 0.000001 * uniforms.branchScale * (pow(PHI, branchIndex) - pow(THETA, branchIndex)) / SQRT_5;
    sensorOffset *= mix(0.5, 1.0, t);
//    float sensorAngleOffset = uniforms.sensorAngleOffset;//mix(M_PI_F / 4.0, M_PI_F / 8.0, current);
    float sensorAngleOffset = mix(M_PI_F / 4.0, M_PI_F / 10.0, current);
    float weightLeft = sense(agent, sensorOffset, sensorAngleOffset, slimeTexture);
    float weightRight = sense(agent, sensorOffset, -sensorAngleOffset, slimeTexture);
    float weightForward = sense(agent, sensorOffset, 0, slimeTexture);
    
//    float agentD = distance(center, agent.position) / (slimeTexture.get_width() * 0.5);
    
//    float maxWeight = max(max(weightLeft, weightRight), weightForward);
    
//    float randomSteerStrength = hash01(agent.position.y * slimeTexture.get_width() + agent.position.x + hash(gid + uniforms.time * 100000.0));
    float turnRate = uniforms.turnRate * 2.0 * M_PI_F * (1.0 + current * 3.0);
    turnRate = mix(turnRate, turnRate * 0.5, step(thold, sd));
//    turnRate = mix(turnRate, turnRate * 2.0, smoothstep(0.4, 0.5, agentD));

//    if (weightForward > weightLeft && weightForward > weightRight) {
////        agents[gid].angle += current * (randomSteerStrength - 0.5) * 0.1 * turnRate * uniforms.deltaTime;
//    }
//    else if (weightForward < weightLeft && weightForward < weightRight) {
//        agents[gid].angle += (randomSteerStrength - 0.5) * 2 * turnRate * uniforms.deltaTime;
//    }
//    else if (weightRight > weightLeft) {
//        agents[gid].angle -= randomSteerStrength * turnRate * uniforms.deltaTime;
//    }
//    else if (weightLeft > weightRight) {
//        agents[gid].angle += randomSteerStrength * turnRate * uniforms.deltaTime;
//    }
    
//    weightForward = pow(weightForward, 1.0 + 6.0 * step(0.4, agentD));
//    weightLeft = pow(weightLeft, 7.0);
//    weightRight = pow(weightRight, 7.0);
    
    float forwardBest = step(max(weightLeft, weightRight) + 0.000001, weightForward);
    float leftBest = (1.0 - forwardBest) * step(weightRight + 0.000001, weightLeft);
    float rightBest = (1.0 - forwardBest) * step(weightLeft + 0.000001, weightRight);

    float turnRandom = step(weightForward + 0.000001, weightLeft) * step(weightForward + 0.000001, weightRight);

    float rand = hash01(agent.position.y * slimeTexture.get_width() + agent.position.x + hash(gid + uniforms.time * 100000.0));

    float turn = leftBest * turnRate * uniforms.deltaTime + rightBest * -turnRate * uniforms.deltaTime;
    float randomTurn = (rand - 0.5) * 2.0 * turnRate * uniforms.deltaTime;
    
    agents[gid].angle += turn * rand * (1.0 - turnRandom) + turnRandom * randomTurn;
    
//    agent.moveSpeed += current * 10.0 * uniforms.deltaTime;
                             
    float2 direction = float2(cos(agents[gid].angle), sin(agents[gid].angle));
    float2 newPosition = agent.position + direction * uniforms.moveSpeed * uniforms.deltaTime * current;
    newPosition = wrapPosition(newPosition, slimeTexture.get_width(), slimeTexture.get_height());
    
    agents[gid].position = newPosition;
    
    float4 color = uniforms.colors.columns[agent.mask];
    
    float4 prevTrail = slimeTexture.read(uint2(newPosition));
    float4 newTrail = prevTrail + color * (1.0 - prevTrail * prevTrail);
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
    
//    float4 color = max(0.0, slimeTexture.read(gid) - uniforms.decayRate * uniforms.deltaTime);
    
    slimeTexture.write(color, gid);
    
//    const float2 center = float2(slimeTexture.get_width(), slimeTexture.get_height()) / 2.0;
//    float sdt = sdEquilateralTriangle(2.3 * (float2(gid) - center) / (slimeTexture.get_width() * 0.5));
//    slimeTexture.write(color + color * 0.01 * (1.0 - smoothstep(0.0, 0.05, abs(sdt))), gid);
}
