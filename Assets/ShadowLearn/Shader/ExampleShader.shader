Shader "Unlit/ExampleShader"
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

            CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
            half4 _Color;
            CBUFFER_END

            TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);

            struct Attributes
            {
	            float4 vertex 	:POSITION;
	            float3 normal 	:NORMAL;
	            float4 tangent 	:TANGENT;
	            float4 color  	:COLOR;
	            float2 uv 		:TEXCOORD0;
	            UNITY_VERTEX_INPUT_INSTANCE_ID 
            };
            
            struct Varings
            {
	            float4 positionHCS		:SV_POSITION;
                    float3 positionWS   	:TEXCOORD0;
                    float3 normalWS     	:TEXCOORD1;
                    float3 tangentWS    	:TEXCOORD2;
                    float3 biTangentWS  	:TEXCOORD3;
	            float4 color 		:TEXCOORD4;
            	    float2 uv			:TEXCOORD5;
	            UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            

            Varings vert (Attributes v)
            {
                Varings o;
			UNITY_SETUP_INSTANCE_ID(v); 
			UNITY_TRANSFER_INSTANCE_ID(v,o); 
			o.positionHCS = TransformObjectToHClip(v.vertex);
			o.positionWS = TransformObjectToWorld(v.vertex);
			o.normalWS = TransformObjectToWorldNormal(v.normal);
			o.tangentWS = TransformObjectToWorldDir(v.tangent.xyz);
			o.biTangentWS = cross(o.normalWS,o.tangentWS) * v.tangent.w * GetOddNegativeScale();
			o.color = v.color;
            	
			return o;
            }

            half4 frag (Varings i) : SV_Target
            {
            	UNITY_SETUP_INSTANCE_ID(i);
		Light mainlight = GetMainLight();
            	
                // Tex Sample
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                // VectorPrepare
                float3 lightDirWS = SafeNormalize(mainlight.direction);
                float3 camDirWS = GetCameraPositionWS();
                float3 viewDirWS = SafeNormalize(camDirWS - i.positionWS);
                float3 normalWS = SafeNormalize(i.normalWS);

                float3x3 TBN = float3x3(i.tangentWS, i.biTangentWS, i.normalWS);

                float3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
                float halfLambert = dot(normalWS, lightDirWS) * 0.5 + 0.5;
                float NdotL = saturate(dot(normalWS, lightDirWS));
                float NdotV = saturate(dot(normalWS, viewDirWS));
                float NdotH = saturate(dot(normalWS, halfDir));
                float HdotV = saturate(dot(halfDir,  viewDirWS));

            	return mainTex * _Color;
            }
            ENDHLSL
        }
    }
}