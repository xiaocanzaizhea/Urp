Shader"1/wpl_hair"
{
    Properties
    {

        [Header(Textures)]
        _ReverseACESIntensity           ("ReverseACESIntensity", Range(0,1))         = 0.5
        _BaseColor						("BaseColor", Color)    				= (0,0,0,1)
        _BaseMap						("BaseMap_d", 2D)       				= "white" {}
        [NoScaleOffset]_PBRMask         ("PBRMask(metal smooth ao)", 2D)		= "white" {}
        [NoScaleOffset]_NormalMap       ("NormalMap", 2D)               		= "bump" {}
        _NormalScale					("NormalScale",Range(0,1)) 				= 1

        [Header(PBRProperties)]
        _Metallic						("Metallic",Range(0,1)) 				= 0.5
        _Smoothness						("Smoothness",Range(0,1)) 				= 0.5
        _NdotVAdd						("NdotVAdd(Leather Reflect)",Range(0,2))= 0

        // Direct LIght
        [Header(DirectLight)]
        _SelfLight				    	("SelfLight", Color) 					= (1,1,1,1)
        _MainLightColorLerp				("Unity Light or SelfLight", Range(0,1))= 0
        _DirectOcclusion				("DirectOcclusion",Range(0,1)) 			= 0.1
        _ShadowColor        			("ShadowColor", Color)        			= (0,0,0,1)
        _ShadowOffset       			("ShadowOffset",Range(-1,1))  			= 0.0
        _ShadowSmooth       			("ShadowSmooth", Range(0,1))  			= 0.0
        _ShadowStrength     			("ShadowStrength", Range(0,1))			= 1.0

        // Ramp
        [Header(ShadowRamp)]
        [Toggle(_SHADOW_RAMP)]_SHADOW_RAMP("_SHADOW_RAMP", float) = 0
        _ShadowRampTex			("ShadowRampTex", 2D) 					= "white" { }

        [Header(HairSpec)]
        [NoScaleOffset]_HairSpecTex	("HairSpecTex", 2D)          			= "black" {}
        [HDR]_SpecColor			    	("SpecColor", color)					= (0.5, 0.5, 0.5, 0)
        _AnisotropicSlide			("AnisotropicSlide", Range(-0.5, 0.5))	= 0.3
        _AnisotropicOffset			("AnisotropicOffset", Range(-1.0, 1.0))	= 0.0
        _BlinnPhongPow				("BlinnPhongPow", Range(1, 50))			= 5
        _SpecMinimum				("SpecMinimum", Range(0, 0.5))			= 0.1

        // Indirect Light
        [Header(IndirectLight)]
        _SelfEnvColor  		        	("SelfEnvColor", Color) 				= (0.5,0.5,0.5,0.5)
        _EnvColorLerp       			("Unity SH or SelfEnv", Range(0,1)) 	= 0.5
        _IndirDiffUpDirSH   			("IndirDiffUpDirSH", Range(0,1))		= 0.0
        _IndirDiffIntensity 			("IndirDiffIntensity", Range(0,1))		= 0.3
        [Toggle(_INDIR_CUBEMAP)]_INDIR_CUBEMAP("_INDIR_CUBEMAP", Float) 		= 0
        [NoScaleOffset]_IndirSpecCubemap("SpecCube", cube) 						= "black" {}
        _IndirSpecLerp      			("Unity Reflect or Self Map", Range(0,1))= 0.3
        _IndirSpecIntensity 			("IndirSpecIntensity", Range(0.01,10))	= 1.0
        _IndirectOcclusion				("IndirectOcclusion",Range(0,1)) 		= 1

        // Emission, Rim, etc.
        [Header(Emission Rim etc)]
        [HDR]_EmissionCol				("EmissionCol", color)         			= (1,1,1,1)
        [Toggle(_Rim_Key)] _Rim_Key("RimColor", float) = 0
        _RimOffset("RimOffset", Range(0,1)) = 1
        _EmissionIntensity("EmissionIntensity", float) = 1

        // Outline
        [Header(Outline)]
        _OutlineColor					("Outline Color", Color)				= (0, 0, 0, 0.8)
        _OutlineWidth					("OutlineWidth", Range(0, 10))			= 1.0
        _OutlineClampScale				("OutlineClampScale", Range(0.01, 5)) 	= 1

        // Other Settings
        [Header(OtherSettings)]
        [Enum(UnityEngine.Rendering.CullMode)] 
        _Cull								("Cull Mode", Float) 					= 2
        _AlphaClip							("AlphaClip", Range(0, 1)) 				= 1
        
        _RimThreshold("_RimThreshold",Float) = 0.5
        _SpecularWidth("_SpecularWidth",Float) = 1
        _SpecularScale("_SpecularScale",Float) = 1
        _SpecularShiftTex("_SpecularShiftTex",2D) = "black"{}
        _HighLightMask("_HighLightMask",2D) = "black"{}
        _SpecularShiftValue("_SpecularShiftValue",Float) = 1
    }

    SubShader
    {

        Tags
        {
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline" 
            "Queue"="Geometry"
            "IgnoreProjector" = "True" 
            "ShaderModel"="4.5"
            "UniversalMaterialType" = "CharacterLit"
        }
        LOD 300
//basecol
        Pass
        {
            
            Tags{"LightMode" = "UniversalForward" "Queue" = "Geomotry + 200"}
            Cull[_Cull]

            ZWrite On
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

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

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ToonVert
            #pragma fragment ToonFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/GF2_wpl-learn/shader/Common/common.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half3	_BaseColor;
                float4	_BaseMap_ST;
                half	_NormalScale,_ReverseACESIntensity;
                // PBR Properties
                half	_Metallic,_Smoothness;
                half	_IndirectOcclusion,_NdotVAdd;
                // Direct Light
                half4	_SelfLight;
                half	_MainLightColorLerp,_DirectOcclusion;
                // Shadow
                half4	_ShadowColor;
                float   _ShadowOffset,_ShadowSmooth;
                float   _ShadowStrength;
                // HairSpec
                half4 _SpecColor;
                half _AnisotropicSlide,_AnisotropicOffset;
                half _BlinnPhongPow,_SpecMinimum;
                // Indirect
                half4	_SelfEnvColor;
                half	_EnvColorLerp,_IndirDiffUpDirSH;
                half	_IndirDiffIntensity,_IndirSpecLerp;
                half	_IndirSpecMatcapTile,_IndirSpecIntensity;
                // Emission
                half4	_EmissionCol;
                float   _RimOffset,_EmissionIntensity;
            float _RimThreshold;
            float _SpecularWidth;
            float _SpecularScale;
            float _SpecularShiftValue;
            CBUFFER_END

            TEXTURE2D(_BaseMap);SAMPLER(sampler_BaseMap);
            TEXTURE2D(_PBRMask);SAMPLER(sampler_PBRMask);
            TEXTURE2D(_NormalMap);SAMPLER(sampler_NormalMap);	
            TEXTURE2D(_ShadowRampTex);SAMPLER(sampler_ShadowRampTex);
            TEXTURECUBE(_IndirSpecCubemap);SAMPLER(sampler_IndirSpecCubemap);
            TEXTURE2D(_HairSpecTex);SAMPLER(sampler_HairSpecTex);
            TEXTURE2D(_CameraDepthTexture);SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_SpecularShiftTex);SAMPLER(sampler_SpecularShiftTex);
            TEXTURE2D(_HighLightMask);SAMPLER(sampler_HighLightMask);
            
            float3 shiftTangent(float3 T, float3 N, float shift)  //以shiftmap对T进行偏移
            {
                return normalize(T + shift * N);
            }

            float hairStrandSpecular(float3 T, float3 V, float3 L, float specPower)
            {
                float3 H = normalize(V + L) ;

                float HdotT = dot(T, H);
                float sinTH = sqrt(1 - HdotT * HdotT);
                float dirAtten = smoothstep(-_SpecularWidth, 0, HdotT);

                
                return dirAtten * saturate(pow(sinTH, specPower)) * _SpecularScale;
            }

            float4 getSpecular(float shiftTex,
                float4 primaryColor, float primaryShift,
                float3 N, float3 T, float3 V, float3 L, float specPower, float2 uv)
            {
                float3 t1 = shiftTangent(T, N, primaryShift + shiftTex-0.5);

                float4 specular;
                specular = primaryColor * hairStrandSpecular(t1, V, L, specPower) * _SpecularScale;
                specular = hairStrandSpecular(t1, V, L, specPower);
                return specular;
            }

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

            half4 ToonFrag(Toon_v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                float2 UV = i.uv.xy;
                float2 UV1 = i.uv.zw;
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
                half directOcclusion  	= lerp(1 - _DirectOcclusion, 1, pbrMask.b);
                half indirectOcclusion  = lerp(1 - _IndirectOcclusion, 1, pbrMask.b);
                half3 albedo = BaseColor.rgb * _BaseColor.rgb;

                // NPR diffuse
                float shadowArea = sigmoid(1 - halfLambert, _ShadowOffset, _ShadowSmooth * 10) * _ShadowStrength;
                half3 shadowRamp = lerp(1, _ShadowColor.rgb, shadowArea);
                //Remap NdotL for PBR Spec
                half NdotLRemap = 1 - shadowArea;
                #if _SHADOW_RAMP // 采样渐变阴影
                    shadowRamp = SampleDirectShadowRamp(TEXTURE2D_ARGS(_ShadowRampTex, sampler_ShadowRampTex), 1.0 - shadowArea, 0.125);
                #endif
                // NdotV modify fresnel
                NdotV += _NdotVAdd;

                // DirectLighting
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

                float specRange = 1;
                half4 specRampCol = 1;
                #if _SHADOW_RAMP // 采样直接光渐变
                    specRange= saturate(NDF * G / denom.x);
                    specRampCol = SampleDirectSpecularRamp(TEXTURE2D_ARGS(_ShadowRampTex, sampler_ShadowRampTex), specRange);
                    directSpecColor = clamp(specRampCol.rgb * 3 + BRDFSpec * PI / F, 0, 10) * F * shadowRamp;
                #endif

                // Hair Spec    头发高光计算
                float anisotropicOffsetV = - viewDirWS.y * _AnisotropicSlide + _AnisotropicOffset;
                half3 hairSpecTex = SAMPLE_TEXTURE2D(_HairSpecTex, sampler_LinearClamp, float2(UV1.x, UV1.y + anisotropicOffsetV));
                float hairSpecStrength = _SpecMinimum + pow(NdotH, _BlinnPhongPow) * NdotLRemap;
                half3 hairSpecColor = hairSpecTex * _SpecColor * hairSpecStrength;

                /*//3、mask高光  
                float anisotropicOffsetV2 = _AnisotropicSlide + _AnisotropicOffset;
                half3 hairSpecTex2 = SAMPLE_TEXTURE2D(_HighLightMask, sampler_HighLightMask, float2(UV.x, UV.y + anisotropicOffsetV2));
                hairSpecColor = hairSpecTex2 * _SpecColor * 2;
                
                //1、kajiya-kay  柔和高光
                float PrimaryShift = SAMPLE_TEXTURE2D(_SpecularShiftTex,sampler_SpecularShiftTex,half2(i.uv.z,i.uv.w+anisotropicOffsetV));
                half4 specular = getSpecular( _SpecularShiftValue,_SpecColor, PrimaryShift, i.normalWS, i.biTangentWS, viewDirWS, lightDirWS, _BlinnPhongPow, i.uv.xy) * 50;
                hairSpecColor = specular;*/

                
                //2、风格化kajiya-kay 未实现

                
                
                //return float4(hairSpecColor,1);




                
                // Compose direct lighting
                float3 directLightResult = (directDiffColor * shadowRamp + directSpecColor * NdotLRemap + hairSpecColor)
                * mainLight.color * mainLight.shadowAttenuation * directOcclusion;

                // Additional light
                float3 addDiffColor = 0;
                float3 addSpecColor = 0;
                #ifdef _ADDITIONAL_LIGHTS
                    uint pixelLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                    {
                        Light light = GetAdditionalLight(lightIndex, positionWS);
                        float3 addDiffLightColor = light.color * shadowRamp;
                        float3 addSpecLightColor = light.color * specRampCol;
                        shadowRamp = SampleDirectShadowRamp(TEXTURE2D_ARGS(_ShadowRampTex, sampler_ShadowRampTex), light.distanceAttenuation * light.shadowAttenuation, 0.875);
                        // half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
                        
                        //diff
                        addDiffColor += LightingLambert(addDiffLightColor, light.direction, normalWS); // sat(NoL) * LightColor
                        //addSpecColor += LightingSpecular(attenuatedLightColor, light.direction, normalWS, viewDirWS, 1.0, smoothness*10);
                        
                        //spec
                        float3 halfAdd = normalize(light.direction+viewDirWS);
                        float NdotAddH = saturate(dot(normalWS,halfAdd));
                        float NdotAddL = saturate(dot(normalWS,light.direction));
                        addSpecColor += DistributionGGX(NdotAddH,roughnessSquare) * addSpecLightColor * shadowRamp * NdotAddL;
                    }
                #endif
                float3 addLightResult = addDiffColor * albedo + addSpecColor;

                // IndirectLighting
                // Diffuse
                float3 indirDiffColor = IndirectDiffuse(normalWS, _IndirDiffUpDirSH, half4(_SelfEnvColor.rgb, _EnvColorLerp), albedo, F0, NdotV, roughness, metallic, indirectOcclusion);

                // Specular
                float3 indirSpecCubeColor = IndirSpeCube(normalWS, viewDirWS, roughness, indirectOcclusion);
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

                // -------------------屏幕空间等距边缘光--------------------
                float3 RimColor = 0;
                #if _Rim_Key
                    //偏移UV
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

               /*float nl = step(_RimOffset ,saturate(i.normalWS * lightDirWS));
                float nv = step(0.01,(1 - NdotV) + 0.2);
                float mainresult = clamp(0,1,nv * nl) * _EmissionIntensity * _EmissionCol;*/


                
                half3 lightingResult = directLightResult + indirectLightResult + 0.3 * addLightResult + emissResult   + RimColor;


                
                
                return half4(lightingResult,1);//half4(lightingResult ,1);

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

        UsePass "Character/Outline/GF2Outline"

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
