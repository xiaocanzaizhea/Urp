Shader "Unlit/urp muban"
{
    Properties
    {
       _Color ("Color", Color) = (1, 1, 1, 1)
        _Offset ("Offset", float) = 0.02
        [Header(Stencil)]
        _StencilRef ("_StencilRef", Range(0, 255)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)]_StencilComp ("_StencilComp", float) = 0
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
        HLSLINCLUDE
        float _StencilRef;
        float _StencilComp;
        
        ENDHLSL
        //FringeShadowCaster
		Pass
        {
	        Name "HairShadow"
            Tags { "LightMode" = "FringeShadowCaster" }
            
        	
        	ZTest LEqual
            ZWrite Off
            Cull Back
            
        	
        	Stencil
        	{
        		Ref[_FriStencil]
				Comp[_FriStencilComp]
				Pass[_FriStencilOp]
				Fail Keep
				ZFail Keep
        	}
            Blend SrcColor DstColor
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			CBUFFER_START(UnityPerMaterial)
            float _Offest;
            half4 _MainTex_ST;
            half4 _Color;
             
			 float _Offset;
			 float4 _LightDirSS;
			 
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
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.positionHCS = positionInputs.positionCS;

                float2 lightOffset = normalize(_LightDirSS.xy);
                //乘以_ProjectionParams.x是考虑裁剪空间y轴是否因为DX与OpenGL的差异而被翻转
                //参照https://docs.unity3d.com/Manual/SL-PlatformDifferences.html
                //"Similar to Texture coordinates, the clip space coordinates differ between Direct3D-like and OpenGL-like platforms"
                lightOffset.y = lightOffset.y * _ProjectionParams.x;
                o.positionHCS.xy += lightOffset * _Offset;

                o.color = v.color;
                return o;
            }

            half4 frag (Varings i) : SV_Target
            {

            	return _Color;
            			
            }
            ENDHLSL
        }
        //着色
		Pass
        {
	        
            Tags { "LightMode" ="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _Offest;
            half4 _MainTex_ST;
            half4 _Color;
             
			 float _Offset;
			 float4 _LightDirSS;
			 
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
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                o.positionHCS = positionInputs.positionCS;

                float2 lightOffset = normalize(_LightDirSS.xy);
                //乘以_ProjectionParams.x是考虑裁剪空间y轴是否因为DX与OpenGL的差异而被翻转
                //参照https://docs.unity3d.com/Manual/SL-PlatformDifferences.html
                //"Similar to Texture coordinates, the clip space coordinates differ between Direct3D-like and OpenGL-like platforms"
                lightOffset.y = lightOffset.y * _ProjectionParams.x;
                //o.positionHCS.xy += lightOffset * _Offset;

                o.color = v.color;
                return o;
            }

            half4 frag (Varings i) : SV_Target
            {

            	return _Color;
            			
            }
            ENDHLSL
        }
		//shadowcaster
		Pass
		{
			Name "ShadowCaster"
			Tags{"LightMode" = "ShadowCaster"}

			ZWrite On
			ZTest LEqual
			ColorMask 0
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON

			// -------------------------------------
			// Universal Pipeline keywords

			// This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"
			Tags{"LightMode" = "DepthOnly"}

			ZWrite On
			ColorMask 0
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
			ENDHLSL
		}

		// This pass is used when drawing to a _CameraNormalsTexture texture
		Pass
		{
			Name "DepthNormals"
			Tags{"LightMode" = "DepthNormals"}

			ZWrite On
			Cull[_Cull]

			HLSLPROGRAM
			#pragma exclude_renderers gles gles3 glcore
			#pragma target 4.5

			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature_local _NORMALMAP
			#pragma shader_feature_local _PARALLAXMAP
			#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
			ENDHLSL
		}
    }
}