Shader "Unlit/Fractal Urp"
{
    Properties
    {
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
        _Color ("color",Color) = (0,0,0,0)
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
                float4 _Color;
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
                StructuredBuffer<float4x4> _Matrices;
            #endif

            float _Step;

            Varings vert (Attributes v)
            {
                #if defined(UNITY_PROCEDURAL_INSTANCING_ENABLED)
                    unity_ObjectToWorld = _Matrices[instanceID];
                #endif
                
                Varings o;
				o.positionHCS = TransformObjectToHClip(v.vertex);
				o.positionWS = TransformObjectToWorld(v.vertex);
				return o;
            }

            half4 frag (Varings i) : SV_Target
            {
		        return _Color;
            }
            ENDHLSL
        }
    }
}