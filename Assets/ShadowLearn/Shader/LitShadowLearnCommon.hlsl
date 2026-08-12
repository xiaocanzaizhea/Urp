#ifndef UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED_LEARN
#define UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED_LEARN

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"


//阴影投射光的几何参数。这些变量在应用阴影法线偏差时使用，并由UnityEngine设置。com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs的rendering . universal . shadow utils . setupshadowcasterconstantbuffer
//对于平行光，应用阴影法线偏移时使用_LightDirection。
//对于聚光灯和点光源，_LightPosition用于计算实际的灯光方向，因为它在每个阴影投射几何体顶点上是不同的。
float3 _LightDirection;
float3 _LightPosition;

struct Attributes
{
    float4 positionOS   : POSITION;
    float3 normalOS     : NORMAL;
    float2 texcoord     : TEXCOORD0;
    
};

struct Varyings
{
    
    float4 positionCS   : SV_POSITION;
    
};

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
    float3 lightDirectionWS = _LightDirection;
#endif

    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output;
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
    
    return 0;
}

#endif
