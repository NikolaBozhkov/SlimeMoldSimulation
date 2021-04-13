//
//  ShaderTypes.h
//  SlimeMoldSimulation Shared
//
//  Created by Nikola Bozhkov on 13.04.21.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexVertices = 0,
    BufferIndexUniforms = 1
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    simd_float2 screenSize;
} Uniforms;

#endif /* ShaderTypes_h */

