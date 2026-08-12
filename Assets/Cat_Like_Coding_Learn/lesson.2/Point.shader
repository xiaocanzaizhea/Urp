Shader "Unlit/urp muban"
{
    Properties
    {
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "IgnoreProjector" = "True" 
            "ShaderModel"="4.5"
        }
        LOD 300

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling  procedural:ConfigureProcedural
            #pragma editor_sync_compilation
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Smoothness;
            CBUFFER_END

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);

            struct Attributes
            {
	            float4 vertex 	:POSITION;
                uint instanceID : SV_InstanceID;
            };
            
            struct Varings
            {
	            float4 positionHCS		:SV_POSITION;
                float3 positionWS   	:TEXCOORD0;
                
            };
            #if defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)
                StructuredBuffer<float3> _Positions;
            #endif

            float _Step;

            Varings vert (Attributes v)
            {
                #if defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)
                    float3 position = _Positions[v.instanceID];

                    unity_ObjectToWorld = 0.0;
                    unity_ObjectToWorld._m03_m13_m23_m33 = float4(position,1);
                    unity_ObjectToWorld._m00_m11_m22 = _Step;
                #endif
                
                Varings o;
				o.positionHCS = TransformObjectToHClip(v.vertex);
				o.positionWS = TransformObjectToWorld(v.vertex);
				return o;
            }

            half4 frag (Varings i) : SV_Target
            {
		        return float4(i.positionWS * 0.5 + 0.5,1);
            }
            ENDHLSL
        }
    }
}