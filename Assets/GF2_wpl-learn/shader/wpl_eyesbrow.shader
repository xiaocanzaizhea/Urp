Shader "Character/wpl_face"
{
	Properties
	{
		[Header(Textures)]
        _ReverseACESIntensity           ("ReverseACESIntensity", Range(0,1))         = 0.5
		_BaseColor  ("BaseColor", Color)    = (0,0,0,1)
		_BaseMap    ("BaseMap_d", 2D)       = "white" {}
		

		
		
		_RimThreshold("_RimThreshold",Float) = 0.5
		_EyeBrowColor("_EyeBrowColor",Color) = (0.5,0.5,0.5,1)
		_alpha("_alpha",Range(0,1)) = 0.5
	}
	SubShader
	{
		Tags
		{
			"RenderType"="Opaque"
			"RenderPipeline" = "UniversalPipeline"
			"Queue"="Geometry"
			"IgnoreProjector" = "True"
		}
		LOD 300 
		
		
		// BasePass
		Pass
		{
			Name "Face_Color_Reseiver"
			Tags
			{
				"LightMode" ="UniversalForward"
				"Queue" = "Transparent - 200"
			}
			
			Stencil  //模版测试
			{
				Ref 32
				Comp Always
				Pass Replace
			}
			ZTest Off
			HLSLPROGRAM
			#pragma target 4.5
			#pragma exclude_renderers gles3 glcore

			// Shader Stages
			#pragma vertex vert
			#pragma fragment frag

			// Material Keywords
			#pragma shader_feature_local _SHADOW_RAMP
			#pragma shader_feature_local _INDIR_CUBEMAP
			#pragma shader_feature_local _Rim_Key

			// Universal Pipeline keywords
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN  //主光
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS //额外光
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING         //反射球混合
			#pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION   
			#pragma multi_compile_fragment _ _SHADOWS_SOFT            //软阴影
			#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION  // SSAO
			

			// Includes
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Assets/GF2_wpl-learn/shader/Common/common.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half3	_BaseColor;
				float4	_BaseMap_ST;
				half	_NormalScale,_ReverseACESIntensity;
				// PBR Properties
				half	_Metallic,_Smoothness;
				half	_Occlusion,_NdotVAdd;
				// Direct Light
				half4	_SelfLight;
				half	_MainLightColorLerp,_DirectOcclusion;
				// Shadow
				half4	_ShadowColor;
				float   _ShadowOffset,_ShadowSmooth;
				float   _ShadowStrength,_SecShadowStrength;
				half4 	_SecShadowColor;
				// Specular
				half4 	_NoseSpecColor;
				half	_NoseSpecMin,_NoseSpecMax;
				// Indirect
				half4	_SelfEnvColor;
				half	_EnvColorLerp,_IndirDiffUpDirSH;
				half	_IndirDiffIntensity,_IndirSpecLerp;
				half	_IndirSpecIntensity;
				// Emission
				half4	_EmissionCol;
				float   _RimOffset,_EmissionIntensity;
			float _RimThreshold;
			CBUFFER_END

			TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
			TEXTURE2D(_PBRMask);SAMPLER(sampler_PBRMask);
			TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);	
			TEXTURE2D(_FaceLightMap);SAMPLER(sampler_FaceLightMap);
			TEXTURE2D(_FaceLightMap2);SAMPLER(sampler_FaceLightMap2);
			TEXTURE2D(_ShadowRampTex);SAMPLER(sampler_ShadowRampTex);
			TEXTURECUBE(_IndirSpecCubemap);SAMPLER(sampler_IndirSpecCubemap);
			TEXTURE2D(_CameraDepthTexture);SAMPLER(sampler_CameraDepthTexture);

			float3 reverseACES(float3 color)
            {
                return  3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
            }  

			

			float4 TransformHClipToViewPortPos(float4 positionCS)
             {
                 float4 o = positionCS * 0.5f;
                 o.xy = float2(o.x, o.y * _ProjectionParams.x) + o.w;
                 o.zw = positionCS.zw;
                 return o / o.w;
             }

			struct a2v 
			{
				float4 vertex 	:POSITION;
				float3 normal 	:NORMAL;
				float4 tangent 	:TANGENT;
				float4 color  	:COLOR;
				float4 uv0 		:TEXCOORD0;
				float4 uv1 		:TEXCOORD1;
				
			};
			struct v2f 
			{
				float4 positionHCS		:SV_POSITION;
				float3 positionWS   	:TEXCOORD0;
				float3 normalWS     	:TEXCOORD1;
				float3 tangentWS    	:TEXCOORD2;
				float3 biTangentWS  	:TEXCOORD3;
				float4 color 			:TEXCOORD4;
				float4 uv				:TEXCOORD5;
				float2 faceLightDot		:TEXCOORD6;
				float3 faceLightUp      :TEXCOORD7;
				
			};
			
			v2f vert (a2v v)
			{
				v2f o;

				o.positionHCS = TransformObjectToHClip(v.vertex);
				o.positionWS = TransformObjectToWorld(v.vertex);

				o.normalWS = TransformObjectToWorldNormal(v.normal);
				o.tangentWS = TransformObjectToWorldDir(v.tangent.xyz);
				o.biTangentWS = cross(o.normalWS,o.tangentWS) * v.tangent.w * GetOddNegativeScale();
				o.color = v.color;

				o.uv.xy = v.uv0.xy;
				o.uv.zw = v.uv1.xy;

				// Face lightmap dot value
				Light mainLight = GetMainLight();
				float3 lightDirWS = mainLight.direction;
				lightDirWS.xz = normalize(lightDirWS.xz);
				float3 FaceRightDirWS = normalize(TransformObjectToWorld(float4(1,0,0,0)));
				float3 FaceFrontDirWS = TransformObjectToWorld(float4(0,0,1,0));
				o.faceLightDot.x = dot(lightDirWS.xz, FaceRightDirWS.xz); // 区分光在左右
				o.faceLightDot.y = saturate(dot(-lightDirWS.xz, FaceFrontDirWS.xz) * 0.5 + _ShadowOffset); // 区分光在前后
				return o;
			}


			half4 frag(v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);
				half2  UV = i.uv.xy;
				half2  UV1 = i.uv.zw;
				float2 screenUV = i.positionHCS.xy/_ScreenParams.xy;
				float3 positionWS = i.positionWS;
				float4 shadowCoords = TransformWorldToShadowCoord(positionWS);
				Light mainLight = GetMainLight();
				mainLight.color = lerp(mainLight.color, _SelfLight.rgb, _MainLightColorLerp);

				// Tex Sample
				half4 mainTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, UV);
				float3 reverseACESBaseColor = reverseACES(mainTex.rgb);
                float3 BaseColor = lerp(mainTex.rgb,reverseACESBaseColor,_ReverseACESIntensity);
				half4 pbrMask = SAMPLE_TEXTURE2D(_PBRMask, sampler_PBRMask, UV);
				half3 bumpTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap,UV), _NormalScale);
				
				// VectorPrepare
				float3 lightDirWS = SafeNormalize(mainLight.direction);
				float3 camDirWS = GetCameraPositionWS();
				float3 viewDirWS = SafeNormalize(camDirWS - positionWS);
				float3 normalWS = SafeNormalize(i.normalWS);
				float3 viewNormal = normalize(TransformWorldToViewDir(normalWS));

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

				// FaceLightMap
				float2 faceLightMapUV = UV1;
				faceLightMapUV.x = 1 - faceLightMapUV.x;
				faceLightMapUV.x = i.faceLightDot.x < 0 ? 1 - faceLightMapUV.x : faceLightMapUV.x; // 翻转UV.x

				half4 faceLightMap = SAMPLE_TEXTURE2D(_FaceLightMap, sampler_FaceLightMap, faceLightMapUV);
				half faceSDF = faceLightMap.r;

				float faceMapShadow = sigmoid(faceSDF, i.faceLightDot.y, _ShadowSmooth * 10);
				shadowArea = (1 - faceMapShadow) * _ShadowStrength;

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
				
				// GGX specArea remap
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

				// Nose Spec
				float faceSpecStep = clamp(i.faceLightDot.y, 0.001, 0.999);
				faceLightMapUV.x = 1 - faceLightMapUV.x;
				faceLightMap = SAMPLE_TEXTURE2D(_FaceLightMap, sampler_FaceLightMap, faceLightMapUV);
				float noseSpecArea1 = step(faceSpecStep, faceLightMap.g);
				float noseSpecArea2 = step(1 - faceSpecStep, faceLightMap.b);
				float noseSpecArea = noseSpecArea1 * noseSpecArea2 * smoothstep(_NoseSpecMin, _NoseSpecMax, 1 - i.faceLightDot.y);
				half3 noseSpecColor = _NoseSpecColor.rgb * _NoseSpecColor.a * noseSpecArea;

				// Compose direct lighting
				float3 directLightResult = (directDiffColor * shadowRamp + (directSpecColor + noseSpecColor) * NdotLRemap)
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

				// -------------------屏幕空间等距边缘光--------------------
				float3 RimColor = 0;
				#if _Rim_Key
					float3 posVS = TransformWorldToView(i.positionWS);
                    float2 screenUV2 = i.positionHCS.xy / i.positionHCS.z;
                    
                    float3 offsetPosVS = float3(posVS.xy + viewNormal.xy * _RimOffset,posVS.z);
                    float4 offsetPosCS = TransformWViewToHClip(offsetPosVS);
                    float4 offsetPosVP = TransformHClipToViewPortPos(offsetPosCS);

                    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV);
                    float linearEyeDepth = LinearEyeDepth(depth,_ZBufferParams);

                    float offsetDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, offsetPosVP);
                    float linearEyeOffsetDepth = LinearEyeDepth(offsetDepth,_ZBufferParams);

                    float depthDiff = linearEyeOffsetDepth - linearEyeDepth;
                    float rimMask2 = smoothstep(0, _RimThreshold, depthDiff);
                    RimColor = _EmissionCol * rimMask2;
				#endif

				//主光源边缘光
                float nl = step(_RimOffset ,saturate(i.normalWS * lightDirWS));
                float nv = step(0.01,(1 - NdotV) + 0.2);
                float3 mainresult = clamp(0,1,nv * nl) * _EmissionIntensity * _EmissionCol;

				
				half3 emissResult = emission * albedo * _EmissionCol.rgb * _EmissionCol.a;
				half3 lightingResult = directLightResult + indirectLightResult + 0.1  + emissResult + RimColor + mainresult;

				float4 col = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);
			    
				return col;
			}
			ENDHLSL

		}

//

//眉毛重绘制
		Pass
		{
			Name "eyesbrow"
			Tags { "LightMode" = "eyesbrow" "Queue" = "Transparent + 100" }
			
			Blend SrcAlpha OneMinusSrcAlpha
            ZTest Off
			Stencil 
           {
               Ref 1
               Comp Equal
               Pass Keep
               Fail Keep
               ZFail Keep
           }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			CBUFFER_START(UnityPerMaterial)
			half4 _EyeBrowColor;
            float _alpha;
			CBUFFER_END

			struct appdata
			{
			    float4 vertex : POSITION; 
			    float2 uv : TEXCOORD0;
			};

			struct v2f
			{
			    float4 vertex : SV_POSITION;
			    float2 uv : TEXCOORD0;
				float eyesmask : TEXCOORD1;
			};
			TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
			v2f vert (appdata v)
			{
			    v2f o;
			    o.vertex = TransformObjectToHClip(v.vertex);

				float2 camFrontXZ = -UNITY_MATRIX_V[2].xz;
				float2 faceLeftxz = half2(-1,0);
				float isLeftSide = dot(camFrontXZ,faceLeftxz);
				//isLeftSide = isLeftSide * 0.2 + 0.8;
				//
				o.eyesmask = lerp(step(0,v.vertex.x),step(v.vertex,0),isLeftSide); //左右
				o.eyesmask = o.eyesmask * 0.2 + 0.8;

				float2 faceFrontXZ = half2(0,1);
				half2 dotFaceCamera = dot(faceFrontXZ,camFrontXZ) ;
				o.eyesmask = saturate(o.eyesmask * dotFaceCamera * _alpha) ;
			    o.uv = v.uv;
			    return o;
			}

			half4 frag (v2f i) : SV_Target
			{
				float3 col = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv);
				float mask = i.eyesmask;
			    return half4(col,mask);
			}
            
            
            ENDHLSL
		}
		
		// Outline
		//UsePass "Character/Outline/GF2Outline"

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
	FallBack "Hidden/Universal Render Pipeline/FallbackError"
}