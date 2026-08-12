Shader "ChiChi/GerstnerWater"
{
    Properties
    {
        _WaveParam("_WaveParam",Vector) = (0,0,0,0)
        _Speed("_Speed",Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
        LOD 100
        Cull Back
        HLSLINCLUDE

        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        ENDHLSL
        Pass
        {
          Cull Back
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            float4 _WaveParam;
            float _Speed;

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD2;
                float4 vertexCS: TEXCOORD3;
                float4 tangentWS: TEXCOORD5;
            };

            float SineWave(float4 waveParam, float x)
            {
                float amplitude = waveParam.x;
                float waveOffset = amplitude * sin(x);
                return waveOffset;
            }

            float SineWave(float4 waveParam, float speed, float x)
            {
                float amplitude = waveParam.x;
                float waveLength = waveParam.y;
                float k = 2 * PI / max(1, waveLength);
                float waveOffset = amplitude * sin(k * (x - speed));
                return waveOffset;
            }

            v2f vert(appdata i)
            {
                v2f o = (v2f)0;
                
                o.positionWS = TransformObjectToWorld(i.positionOS.xyz);
                
                o.positionWS.y += SineWave(_WaveParam, _Time.y * _Speed,o.positionWS.x * 0.5);
                o.positionWS.y += SineWave(_WaveParam, _Time.y * _Speed + 0.5,o.positionWS.z * 0.5);
                o.positionCS = TransformWorldToHClip(o.positionWS.xyz);

                
                
                return o;
            }

            half4 frag(v2f i) : SV_TARGET
            {
                return half4(1,1,1,1);
            }
            
            ENDHLSL
        }
    }
}