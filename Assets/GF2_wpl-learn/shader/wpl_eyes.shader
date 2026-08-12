Shader "Character/wpl_eyes"
{
	Properties
	{
		[Header(Textures)]
        _ReverseACESIntensity           ("ReverseACESIntensity", Range(0,1))         = 0.5
		_BaseColor						("BaseColor", Color)    				= (0,0,0,1)
		_BaseMap						("BaseMap_d", 2D)       				= "white" {}
		
		

		[Header(Parallax)]
		_ParallaxScale("ParallaxScale", Range(0, 1))        = 1.0
		_ParallaxMaskEdge("MaskEdge", Range(0, 1))          = 0.8
		_ParallaxMaskEdgeOffset("MaskEdgeOffset", Range(0, 1))         = 0.2

		

		// Direct LIght
		[Header(DirectLight)]
		[HDR]_SelfLight					("SelfLight", Color) 					= (1,1,1,1)
		_MainLightColorLerp				("Unity Light or SelfLight", Range(0,1))= 0
		_DirectOcclusion				("DirectOcclusion",Range(0,1)) 			= 0.1
		
		

		

		

		

		
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
			"RenderPipeline" = "UniversalPipeline"
			"Queue"="Geometry"
			"IgnoreProjector" = "True"
			"UniversalMaterialType" = "CharacterLit"
		}
		LOD 300
//basecol
		Pass
		{
			Tags
			{
				"LightMode" = "UniversalForward"
			}

			Stencil
			{
				Ref[_ELStencil]
				Comp[_ELStencilComp]
				Pass[_ELStencilOp]
			}

			ZWrite On
			ZTest LEqual
			Cull [_Cull]

			HLSLPROGRAM
			#pragma target 4.5
			#pragma exclude_renderers gles3 glcore

			// Shader Stages
			#pragma vertex ToonVert
			#pragma fragment frag

			// Material Keywords
			#pragma shader_feature_local _SHADOW_RAMP
			#pragma shader_feature_local _INDIR_CUBEMAP

			// Universal Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN  //主光
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS //额外光
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING         //反射球混合
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION   
			#pragma multi_compile_fragment _ _SHADOWS_SOFT            //软阴影
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION  // SSAO

			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma instancing_options renderinglayer
			#pragma multi_compile _ DOTS_INSTANCING_ON

			// Includes
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Assets/GF2_wpl-learn/shader/Common/common.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half3	_BaseColor;
				float4	_BaseMap_ST;
				half	_NormalScale,_ReverseACESIntensity;
				//Parallax
				half _ParallaxScale,_ParallaxMaskEdge;
				half _ParallaxMaskEdgeOffset;
				// PBR Properties
				half	_Metallic,_Smoothness;
				half	_Occlusion,_NdotVAdd;
				// Direct Light
				half4	_SelfLight;
				half	_MainLightColorLerp,_DirectOcclusion;
				// Shadow
				half4	_ShadowColor;
				float   _ShadowOffset,_ShadowSmooth;
				float   _ShadowStrength;
				// Indirect
				half4	_SelfEnvColor;
				half	_EnvColorLerp,_IndirDiffUpDirSH;
				half	_IndirDiffIntensity,_IndirSpecLerp;
				half	_IndirSpecIntensity;
				// Emission
				half4	_EmissionCol;
			CBUFFER_END

			TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
			TEXTURE2D(_PBRMask);SAMPLER(sampler_PBRMask);
			TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
			TEXTURE2D(_FaceMap);SAMPLER(sampler_FaceMap);
			TEXTURE2D(_ShadowRampTex);SAMPLER(sampler_ShadowRampTex);
			TEXTURECUBE(_IndirSpecCubemap);SAMPLER(sampler_IndirSpecCubemap);

			float3 reverseACES(float3 color)
            {
                return  3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
            }  

			half4 frag(Toon_v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				float2 UV = i.uv.xy;
				float3 positionWS = i.positionWS;
				float4 shadowCoords = TransformWorldToShadowCoord(positionWS);
				Light mainLight = GetMainLight();
				mainLight.color = lerp(mainLight.color, _SelfLight.rgb, _MainLightColorLerp);

				// VectorPrepare
				float3 lightDirWS = SafeNormalize(mainLight.direction);
				float3 camDirWS = GetCameraPositionWS();
				float3 viewDirWS = SafeNormalize(camDirWS - positionWS);
				float3 normalWS = SafeNormalize(i.normalWS);

				//Parallax
				float3 viewDirOS = TransformWorldToObjectDir(viewDirWS);
				viewDirOS = normalize(viewDirOS);
				float2 parallaxOffset = viewDirOS.xy;
				parallaxOffset.y *= -1;
				float2 parallaxUV = i.uv + _ParallaxScale * parallaxOffset;
				//parallaxMask
				float2 centerVec = i.uv - float2(0.5, 0.5);
				half centerDist = dot(centerVec, centerVec);
				half parallaxMask = smoothstep(_ParallaxMaskEdge, _ParallaxMaskEdge + _ParallaxMaskEdgeOffset, 1 - centerDist);

				// Tex Sample
				half4 mainTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, lerp(UV, parallaxUV, parallaxMask));

				return mainTex;
				float3 reverseACESBaseColor = reverseACES(mainTex.rgb);
                float3 BaseColor = lerp(mainTex.rgb,reverseACESBaseColor,_ReverseACESIntensity);
				half4 pbrMask = SAMPLE_TEXTURE2D(_PBRMask, sampler_PBRMask, UV);
				half3 bumpTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap,UV), _NormalScale);

				float3x3 TBN = float3x3(i.tangentWS, i.biTangentWS, i.normalWS);
				float3 bumpWS = TransformTangentToWorld(bumpTS,TBN);
				normalWS = SafeNormalize(bumpWS);

				float3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
				float halfLambert = dot(normalWS, lightDirWS) * 0.5 + 0.5;
				float NdotL = saturate(dot(normalWS, lightDirWS));
				float NdotV = saturate(dot(normalWS, viewDirWS));
				float NdotH = saturate(dot(normalWS, halfDir));
				float HdotV = saturate(dot(halfDir,  viewDirWS));

				// Property prepare
				half emission			= 1 - mainTex.a;
				half metallic  			= lerp(0, _Metallic, pbrMask.r);
				half smoothness 		= lerp(0, _Smoothness, pbrMask.g);
				half occlusion  		= lerp(1 - _Occlusion, 1, pbrMask.b);
				half directOcclusion  	= lerp(1 - _DirectOcclusion, 1, pbrMask.b);
				half3 albedo = BaseColor.rgb * _BaseColor.rgb;

				// NPR diffuse
				float shadowArea = sigmoid(1 - halfLambert, _ShadowOffset, _ShadowSmooth * 10) * _ShadowStrength;
				half3 shadowRamp = lerp(1, _ShadowColor.rgb, shadowArea);
				//Remap NdotL for PBR Spec
				half NdotLRemap = 1 - shadowArea;
				#if _SHADOW_RAMP
					shadowRamp = SampleDirectShadowRamp(TEXTURE2D_ARGS(_ShadowRampTex, sampler_ShadowRampTex), 1.0 - shadowArea);
				#endif
				
				// NdotV modify fresnel
				NdotV += _NdotVAdd;

				// Direct
				float3 directDiffColor = albedo.rgb;

				float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
				float roughness           = max(PerceptualRoughnessToRoughness(perceptualRoughness), HALF_MIN_SQRT);
				float roughnessSquare     = max(roughness * roughness, HALF_MIN);
				float3 F0 = lerp(0.04, albedo, metallic);

				float NDF = DistributionGGX(NdotH, roughnessSquare);
				float G = GeometrySmith(NdotLRemap, NdotV, pow(roughness + 1.0, 2.0) / 8.0);
				float3 F = fresnelSchlick(HdotV, F0);
				
				// GGX specArea remap;
				NDF = NDF * 1;

				float3 kSpec = F;
				// LightUpDiff: (1.0 - F) => (1.0 - F) * 0.5 + 0.5
				float3 kDiff = ((1.0 - F) * 0.5 + 0.5) * (1.0 - metallic);

				float3 nom = NDF * G * F;
				float3 denom = 4.0 * NdotV * NdotLRemap + 0.0001;
				float3 BRDFSpec = nom / denom;

				directDiffColor = kDiff * albedo;
				float3 directSpecColor = BRDFSpec * PI;

				#if _SHADOW_RAMP
					float specRange= saturate(NDF * G / denom.x);
					half4 specRampCol = SampleDirectSpecularRamp(TEXTURE2D_ARGS(_ShadowRampTex, sampler_ShadowRampTex), specRange);
					directSpecColor = clamp(specRampCol.rgb * 3 + BRDFSpec * PI / F, 0, 10) * F * shadowRamp;
				#endif

				// Compose direct lighting
				float3 directLightResult = (directDiffColor * shadowRamp + directSpecColor * NdotLRemap)
				* mainLight.color * mainLight.shadowAttenuation * directOcclusion;

				// Indirect
				// Diffuse
				float3 indirDiffColor = IndirectDiffuse(normalWS, _IndirDiffUpDirSH, half4(_SelfEnvColor.rgb, _EnvColorLerp), albedo, F0, NdotV, roughness, metallic, occlusion);

				// Specular
				float3 indirSpecCubeColor = IndirSpeCube(normalWS, viewDirWS, roughness, occlusion);
				float3 indirSpecCubeFactor = IndirSpeFactor(roughness, smoothness, BRDFSpec, F0, NdotV);
				half3 additionalIndirSpec = 0;
				#if _INDIR_CUBEMAP // Additional cubemap
					float3 reflectDirWS = reflect(-viewDirWS, normalWS);
					roughness = roughness * (1.7 - 0.7 * roughness);
					float mipLevel= roughness * 6;
					additionalIndirSpec = SAMPLE_TEXTURECUBE_LOD(_IndirSpecCubemap, sampler_LinearRepeat, reflectDirWS, mipLevel);
				#endif 
				float3 indirSpecColor = lerp(indirSpecCubeColor, additionalIndirSpec, _IndirSpecLerp) * indirSpecCubeFactor;

				// Compose indirect lighting
				float3 indirectLightResult = indirDiffColor * _IndirDiffIntensity + indirSpecColor * _IndirSpecIntensity;

				half3 emissResult = emission * albedo * _EmissionCol.rgb * _EmissionCol.a;
				half3 lightingResult = directLightResult + indirectLightResult + emissResult;

				
				return float4(lightingResult,1);
			}
			ENDHLSL

		}

		

		Pass
		{
			Tags
			{
				"LightMode" = "eyesblend" "Queue" = "Geomtry - 1"
			}
			
			
			Blend One Zero
            ZTest Off
			Stencil 
           {
               Ref 1
               Comp Always
               Pass Replace
               Fail Keep
               ZFail Keep
           }
			HLSLPROGRAM
			#pragma target 4.5
			#pragma exclude_renderers gles3 glcore

			// Shader Stages
			#pragma vertex ToonVert
			#pragma fragment frag

			// Material Keywords
			#pragma shader_feature_local _SHADOW_RAMP
			#pragma shader_feature_local _INDIR_CUBEMAP

			// Universal Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN  //主光
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS //额外光
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING         //反射球混合
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION   
			#pragma multi_compile_fragment _ _SHADOWS_SOFT            //软阴影
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION  // SSAO

			// GPU Instancing
			#pragma multi_compile_instancing
			#pragma instancing_options renderinglayer
			#pragma multi_compile _ DOTS_INSTANCING_ON

			// Includes
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Assets/GF2_wpl-learn/shader/Common/common.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half3	_BaseColor;
				float4	_BaseMap_ST;
				half	_NormalScale,_ReverseACESIntensity;
				//Parallax
				half _ParallaxScale,_ParallaxMaskEdge;
				half _ParallaxMaskEdgeOffset;
				// PBR Properties
				half	_Metallic,_Smoothness;
				half	_Occlusion,_NdotVAdd;
				// Direct Light
				half4	_SelfLight;
				half	_MainLightColorLerp,_DirectOcclusion;
				// Shadow
				half4	_ShadowColor;
				float   _ShadowOffset,_ShadowSmooth;
				float   _ShadowStrength;
				// Indirect
				half4	_SelfEnvColor;
				half	_EnvColorLerp,_IndirDiffUpDirSH;
				half	_IndirDiffIntensity,_IndirSpecLerp;
				half	_IndirSpecIntensity;
				// Emission
				half4	_EmissionCol;
				float _alpha;
			CBUFFER_END

			TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
			TEXTURE2D(_PBRMask);SAMPLER(sampler_PBRMask);
			TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);
			TEXTURE2D(_FaceMap);SAMPLER(sampler_FaceMap);
			TEXTURE2D(_ShadowRampTex);SAMPLER(sampler_ShadowRampTex);
			TEXTURECUBE(_IndirSpecCubemap);SAMPLER(sampler_IndirSpecCubemap);

			float3 reverseACES(float3 color)
            {
                return  3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
            }  

			half4 frag(Toon_v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				float2 UV = i.uv.xy;
				float3 positionWS = i.positionWS;
				float4 shadowCoords = TransformWorldToShadowCoord(positionWS);
				Light mainLight = GetMainLight();
				mainLight.color = lerp(mainLight.color, _SelfLight.rgb, _MainLightColorLerp);

				// VectorPrepare
				float3 lightDirWS = SafeNormalize(mainLight.direction);
				float3 camDirWS = GetCameraPositionWS();
				float3 viewDirWS = SafeNormalize(camDirWS - positionWS);
				float3 normalWS = SafeNormalize(i.normalWS);

				//Parallax
				float3 viewDirOS = TransformWorldToObjectDir(viewDirWS);
				viewDirOS = normalize(viewDirOS);
				float2 parallaxOffset = viewDirOS.xy;
				parallaxOffset.y *= -1;
				float2 parallaxUV = i.uv + _ParallaxScale * parallaxOffset;
				//parallaxMask
				float2 centerVec = i.uv - float2(0.5, 0.5);
				half centerDist = dot(centerVec, centerVec);
				half parallaxMask = smoothstep(_ParallaxMaskEdge, _ParallaxMaskEdge + _ParallaxMaskEdgeOffset, 1 - centerDist);

				// Tex Sample
				half4 mainTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, lerp(UV, parallaxUV, parallaxMask));
				float3 reverseACESBaseColor = reverseACES(mainTex.rgb);
                float3 BaseColor = lerp(mainTex.rgb,reverseACESBaseColor,_ReverseACESIntensity);
				half4 pbrMask = SAMPLE_TEXTURE2D(_PBRMask, sampler_PBRMask, UV);
				half3 bumpTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap,UV), _NormalScale);

				float3x3 TBN = float3x3(i.tangentWS, i.biTangentWS, i.normalWS);
				float3 bumpWS = TransformTangentToWorld(bumpTS,TBN);
				normalWS = SafeNormalize(bumpWS);

				float3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
				float halfLambert = dot(normalWS, lightDirWS) * 0.5 + 0.5;
				float NdotL = saturate(dot(normalWS, lightDirWS));
				float NdotV = saturate(dot(normalWS, viewDirWS));
				float NdotH = saturate(dot(normalWS, halfDir));
				float HdotV = saturate(dot(halfDir,  viewDirWS));

				// Property prepare
				half emission			= 1 - mainTex.a;
				half metallic  			= lerp(0, _Metallic, pbrMask.r);
				half smoothness 		= lerp(0, _Smoothness, pbrMask.g);
				half occlusion  		= lerp(1 - _Occlusion, 1, pbrMask.b);
				half directOcclusion  	= lerp(1 - _DirectOcclusion, 1, pbrMask.b);
				half3 albedo = BaseColor.rgb * _BaseColor.rgb;

				// NPR diffuse
				float shadowArea = sigmoid(1 - halfLambert, _ShadowOffset, _ShadowSmooth * 10) * _ShadowStrength;
				half3 shadowRamp = lerp(1, _ShadowColor.rgb, shadowArea);
				//Remap NdotL for PBR Spec
				half NdotLRemap = 1 - shadowArea;
				#if _SHADOW_RAMP
					shadowRamp = SampleDirectShadowRamp(TEXTURE2D_ARGS(_ShadowRampTex, sampler_ShadowRampTex), 1.0 - shadowArea);
				#endif
				
				// NdotV modify fresnel
				NdotV += _NdotVAdd;

				// Direct
				float3 directDiffColor = albedo.rgb;

				float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
				float roughness           = max(PerceptualRoughnessToRoughness(perceptualRoughness), HALF_MIN_SQRT);
				float roughnessSquare     = max(roughness * roughness, HALF_MIN);
				float3 F0 = lerp(0.04, albedo, metallic);

				float NDF = DistributionGGX(NdotH, roughnessSquare);
				float G = GeometrySmith(NdotLRemap, NdotV, pow(roughness + 1.0, 2.0) / 8.0);
				float3 F = fresnelSchlick(HdotV, F0);
				
				// GGX specArea remap;
				NDF = NDF * 1;

				float3 kSpec = F;
				// LightUpDiff: (1.0 - F) => (1.0 - F) * 0.5 + 0.5
				float3 kDiff = ((1.0 - F) * 0.5 + 0.5) * (1.0 - metallic);

				float3 nom = NDF * G * F;
				float3 denom = 4.0 * NdotV * NdotLRemap + 0.0001;
				float3 BRDFSpec = nom / denom;

				directDiffColor = kDiff * albedo;
				float3 directSpecColor = BRDFSpec * PI;

				#if _SHADOW_RAMP
					float specRange= saturate(NDF * G / denom.x);
					half4 specRampCol = SampleDirectSpecularRamp(TEXTURE2D_ARGS(_ShadowRampTex, sampler_ShadowRampTex), specRange);
					directSpecColor = clamp(specRampCol.rgb * 3 + BRDFSpec * PI / F, 0, 10) * F * shadowRamp;
				#endif

				// Compose direct lighting
				float3 directLightResult = (directDiffColor * shadowRamp + directSpecColor * NdotLRemap)
				* mainLight.color * mainLight.shadowAttenuation * directOcclusion;

				// Indirect
				// Diffuse
				float3 indirDiffColor = IndirectDiffuse(normalWS, _IndirDiffUpDirSH, half4(_SelfEnvColor.rgb, _EnvColorLerp), albedo, F0, NdotV, roughness, metallic, occlusion);

				// Specular
				float3 indirSpecCubeColor = IndirSpeCube(normalWS, viewDirWS, roughness, occlusion);
				float3 indirSpecCubeFactor = IndirSpeFactor(roughness, smoothness, BRDFSpec, F0, NdotV);
				half3 additionalIndirSpec = 0;
				#if _INDIR_CUBEMAP // Additional cubemap
					float3 reflectDirWS = reflect(-viewDirWS, normalWS);
					roughness = roughness * (1.7 - 0.7 * roughness);
					float mipLevel= roughness * 6;
					additionalIndirSpec = SAMPLE_TEXTURECUBE_LOD(_IndirSpecCubemap, sampler_LinearRepeat, reflectDirWS, mipLevel);
				#endif 
				float3 indirSpecColor = lerp(indirSpecCubeColor, additionalIndirSpec, _IndirSpecLerp) * indirSpecCubeFactor;

				// Compose indirect lighting
				float3 indirectLightResult = indirDiffColor * _IndirDiffIntensity + indirSpecColor * _IndirSpecIntensity;

				half3 emissResult = emission * albedo * _EmissionCol.rgb * _EmissionCol.a;
				half3 lightingResult = directLightResult + indirectLightResult + emissResult;

				float mask = saturate(i.eyesmask * _alpha);
				
				return float4(lightingResult,mask);
			}
			ENDHLSL

		}


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

	CustomEditor "UnityEditor.DanbaidongGUI.DanbaidongGUI"
	FallBack "Hidden/Universal Render Pipeline/FallbackError"
}