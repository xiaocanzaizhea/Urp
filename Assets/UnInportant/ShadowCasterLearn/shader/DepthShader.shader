Shader "Unlit/DepthShader"
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
            
            struct Attributes
            {
	            float4 vertex : POSITION;
            };
            
            struct Varings
            {
	            float4 pos : SV_POSITION;
                float depth : TEXCOORD0;
            };
            

            Varings vert (Attributes v)
            {
                Varings o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.depth = o.pos.z / o.pos.w;
                return o;
            }

            half4 frag (Varings i) : SV_Target
            {
            	return half4(i.depth,0,0,1);
            }
            ENDHLSL
        }
    }
}