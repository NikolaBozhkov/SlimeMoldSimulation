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
                               constant Uniforms &uniforms [[buffer(BufferIndexUniforms)]])
{
    return float4(0.5);
}
