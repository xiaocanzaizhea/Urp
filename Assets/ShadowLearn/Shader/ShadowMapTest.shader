Shader "Lit_Learn/ShadowMapTest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Color",Color) = (1,1,1,1)
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
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
            half4 _Color;
            float4x4 _worldToLightClipMat;
            CBUFFER_END

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
            TEXTURE2D(_LightDepthTexture);SAMPLER(sampler_LightDepthTexture);

            struct Attributes
            {
	            float4 vertex 	:POSITION;
	            float3 normal 	:NORMAL;
            	float2 texcoord :TEXCOORD0;
            };
            
            struct Varings
            {
	            float4 positionHCS		:SV_POSITION;
                float3 positionWS   	:TEXCOORD0;
                float3 normalWS     	:TEXCOORD1;
            	float4 shadowCoord		:TEXCOORD2;
            	float4 shadowCoord2		:TEXCOORD4;
            	float2 uv				:TEXCOORD3;
            };
            

            Varings vert (Attributes v)
            {
                Varings o;
				o.positionHCS = TransformObjectToHClip(v.vertex);
				
				o.normalWS = TransformObjectToWorldNormal(v.normal);
            	o.uv = v.texcoord;
				
	            VertexPositionInputs vertexinput = GetVertexPositionInputs(v.vertex);
	            o.shadowCoord = GetShadowCoord(vertexinput);
            	o.shadowCoord2 = normalize(mul(_worldToLightClipMat,float4(vertexinput.positionWS,1)));
            	
				return o;
            }

            half4 frag (Varings i) : SV_Target
            {

            	float4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
				/*Light mainlight = GetMainLight(i.shadowCoord);
            	
            	float3 lightDirWS = SafeNormalize(mainlight.direction);
                float3 normalWS = SafeNormalize(i.normalWS);
            	
                float NdotL = saturate(dot(normalWS, lightDirWS));*/
            	
            	ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
		        half4 shadowParams = GetMainLightShadowParams();
            	
            	//shadowAttenuation（阴影衰减获取）
            	
		        float shadow = SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_LinearClampCompare),i.shadowCoord, shadowSamplingData, shadowParams, false);
            	float shadow2 = SampleShadowmap(TEXTURE2D_ARGS(_LightDepthTexture, sampler_LinearClampCompare),i.shadowCoord2, shadowSamplingData, shadowParams, false);

            	float shadowmap = SAMPLE_TEXTURE2D(_LightDepthTexture,sampler_LightDepthTexture,i.uv);
            	
            	return shadowmap;
            	//return shadow * NdotL * col * _Color;
            }
            ENDHLSL
        }

    }
}