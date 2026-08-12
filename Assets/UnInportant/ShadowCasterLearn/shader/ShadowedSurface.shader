Shader "Unlit/ShadowedSurface"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
            float4x4 _WorldToLightClipMatrix; // 世界空间到光源裁剪空间的变换矩阵
            CBUFFER_END

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);
			TEXTURE2D(_ShadowMap);SAMPLER(sampler_ShadowMap);
            
            struct Attributes
            {
	            float4 vertex 	:POSITION;
	            float2 uv 		:TEXCOORD0;
	            
            };
            
            struct Varings
            {
	            float4 positionHCS	:SV_POSITION;
            	float2 uv			:TEXCOORD0;
	            float4 lightClipPos :TEXCOORD1;
            };
            

            Varings vert (Attributes v)
            {
	            Varings o;
				o.positionHCS = TransformObjectToHClip(v.vertex);
            	o.uv = v.uv;

            	// 将顶点从世界空间转换到光源裁剪空间
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.lightClipPos = mul(_WorldToLightClipMatrix, worldPos);
				
            	return o;
			
            }

            half4 frag (Varings i) : SV_Target
            {
            	// 采样纹理颜色
                half4 color = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);

				// 将光源裁剪空间坐标转换为 UV 坐标
                float3 projCoords = i.lightClipPos.xyz / i.lightClipPos.w;
                projCoords = projCoords * 0.5 + 0.5; // 从 [-1, 1] 转换到 [0, 1]

            	// 采样深度图
                float depthFromLight = SAMPLE_TEXTURE2D(_ShadowMap,sampler_ShadowMap,projCoords.xy).r;

            	// 比较当前深度和深度图的深度
                float shadow = (projCoords.z > depthFromLight + 0.001) ? 0.5 : 1.0;

            	// 应用阴影
                return color * shadow;
            }
            ENDHLSL
        }
    }
}