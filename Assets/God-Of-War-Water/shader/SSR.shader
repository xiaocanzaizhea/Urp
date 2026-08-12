Shader "Unlit/urp muban"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SkyBoxCubeMap("SkyBox", Cube) = ""{}
    	
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent" 
            "RenderPipeline" = "UniversalPipeline" 
            "IgnoreProjector" = "True" 
            "ShaderModel"="4.5"
        }
        
            LOD 300
            ZWrite Off
        
        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define MAX_TRACE_DIS 500
			#define MAX_IT_COUNT 200         
			#define EPSION 0.1

            CBUFFER_START(UnityPerMaterial)
            
            CBUFFER_END

            TEXTURE2D(_CameraOpaqueTexture);SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture);SAMPLER(sampler_CameraDepthTexture);
            TEXTURECUBE(_SkyBoxCubeMap);SAMPLER(sampler_SkyBoxCubeMap);
           
            struct Attributes
            {
	            float4 vertex 	:POSITION;
	            float3 normal 	:NORMAL;
	            float2 uv 		:TEXCOORD0;
            };
            
            struct Varings
            {
	            float2 uv : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float4 positionOS : TEXCOORD2;
				float4 positionCS : TEXCOORD3;
				float4 vsRay	  : TEXCOORD4;
				float4 vertex : SV_POSITION;
            };

            float2 ViewPosToCS(float3 vpos)
			{
				float4 proj_pos = mul(unity_CameraProjection, float4(vpos, 1));
				float3 screenPos = proj_pos.xyz / proj_pos.w;
				return float2(screenPos.x, screenPos.y) * 0.5 + 0.5;
			}

            float compareWithDepth(float3 vpos)
			{
				float2 uv = ViewPosToCS(vpos);
				float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
				depth = LinearEyeDepth(depth, _ZBufferParams);
				int isInside = uv.x > 0 && uv.x < 1 && uv.y > 0 && uv.y < 1;
				return lerp(0, vpos.z + depth, isInside);
			}

			bool rayMarching(float3 o, float3 r, out float2 hitUV)
			{
				float3 end = o;
				float stepSize = 0.5;
				float thinkness = 0.1;
				float triveled = 0;
				int max_marching = 256;
				float max_distance = 500;

				UNITY_LOOP
				for (int i = 1; i <= max_marching; ++i)
				{
					end += r * stepSize;
					triveled += stepSize;

					if (triveled > max_distance)
					return false;

					float collied = compareWithDepth(end);
					if (collied < 0)
					{
						if (abs(collied) < thinkness)
						{
							hitUV = ViewPosToCS(end);
							return true;
						}

						//回到当前起点
						end -= r * stepSize;
						triveled -= stepSize;
						//步进减半
						stepSize *= 0.5;
					}
				}
				return false;
			}
            

            Varings vert (Attributes v)
            {
                Varings o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;

                o.positionWS = TransformObjectToWorld(v.vertex).xyz;
                o.positionOS = v.vertex.xyzw;

                float4 screenPos = TransformObjectToHClip(v.vertex);
                screenPos.xyz /= screenPos.w;
                screenPos.xy = screenPos.xy * 0.5 + 0.5;

                o.positionCS = screenPos;
#if UNITY_UV_STARTS_AT_TOP
                o.positionCS.y = 1 - o.positionCS.y;
#endif

                float zFar = _ProjectionParams.z;
                float4 vsRay = float4(float3(o.positionCS.xy * 2.0 - 1.0, 1) * zFar, zFar);
                vsRay = mul(unity_CameraInvProjection, vsRay);

                o.vsRay = vsRay;
                return o;
            }

            half4 frag (Varings i) : SV_Target
            {
            	float4 screenPos = i.positionCS;

                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenPos.xy);
                depth = Linear01Depth(depth, _ZBufferParams);
               
                float3 wsNormal = normalize(float3(0, 1, 0));    //世界坐标系下的法线
                float3 vsNormal = (TransformWorldToViewDir(wsNormal));    //将转换到view space

            	
            	
                float3 vsRayOrigin = (i.vsRay) * depth;
                float3 reflectionDir = normalize(reflect(vsRayOrigin, vsNormal));

                float2 hitUV = 0;
                float3 col = 0;
                if (rayMarching(vsRayOrigin, reflectionDir, hitUV))
                {
                    float3 hitCol = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, hitUV).xyz;
                    col += hitCol;
                }
                else {
                    float3 viewPosToWorld = normalize(i.positionWS.xyz - _WorldSpaceCameraPos.xyz);
                    float3 reflectDir = reflect(viewPosToWorld, wsNormal);
                    col = SAMPLE_TEXTURECUBE(_SkyBoxCubeMap, sampler_SkyBoxCubeMap, reflectDir);
                }

                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}