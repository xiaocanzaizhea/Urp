Shader "Unlit/ObjectShader"
{
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
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

            TEXTURE2D(_ObjectMaskTexture);SAMPLER(sampler_ObjectMaskTexture);
            struct Attributes
            {
	            float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct Varings
            {
	            float4 pos : SV_POSITION;
                float depth : TEXCOORD0;
                float2 uv :TEXCOORD1;
            };
            

            Varings vert (Attributes v)
            {
                Varings o;
                o.uv = v.uv;
                o.pos = TransformObjectToHClip(v.vertex);
                o.depth = o.pos.z / o.pos.w;
                return o;
            }

            half4 frag (Varings i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_ObjectMaskTexture,sampler_ObjectMaskTexture,i.uv);
            	return col;
            }
            ENDHLSL
        }
    }
}