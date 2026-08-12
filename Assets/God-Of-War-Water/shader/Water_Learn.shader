Shader "Unlit/MyWater"
{
    Properties
    {
		_NoiseMap("noisemap",2D) = "bump"{}
		_NoiseMap2("noisemap2",2D) = "bump"{}
    	
    	_AbsorptionScatteringRamp("_AbsorptionScatteringRamp",2D) = "white"{}
    	_AbsorptionScatteringRamp2("_AbsorptionScatteringRamp",2D) = "white"{}
    	
    	_WaterColor("watercolor",Color) = (0,0,0,1)
    	
    	_FoamMap("FoamMap",2D) = "white"{}
    	
    	[Header(Wave)]
    	_WaveParam("WaveParam",Vector) = (0,0,0,0)
    	_Speed("_Speed",Float) = 0.5
    	
    	_WaterRing("_WaterRing",2D) = "white"{}
    	_RingPower("_RingPower",Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
		ZWrite On
        Pass
        {

		    Tags{"LightMode" = "UniversalForward"}
		    //Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/God-Of-War-Water/shader/GERSTNER_WAVES.hlsl"
 
			TEXTURE2D(_PlanarReflectionTexture); SAMPLER(sampler_PlanarReflectionTexture);
			TEXTURE2D(_AbsorptionScatteringRamp); SAMPLER(sampler_AbsorptionScatteringRamp);
			TEXTURE2D(_AbsorptionScatteringRamp2); SAMPLER(sampler_AbsorptionScatteringRamp2);
			TEXTURE2D(_FoamMap); SAMPLER(sampler_FoamMap);
			TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
			TEXTURE2D(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_NoiseMap); SAMPLER(sampler_NoiseMap);
            TEXTURE2D(_NoiseMap2); SAMPLER(sampler_NoiseMap2);
            TEXTURE2D(_WaterRing); SAMPLER(sampler_WaterRing);

            #define _MaxDepth 1000

            CBUFFER_START(UnityPerMaterial)
            float4 _WaterColor;
            float4 _WaveParam;
            float _Speed;
            float _RingPower;
            CBUFFER_END
 
			struct appdata
            {
                float4 vertex : POSITION;
            	float4 normal : NORMAL;
            	
            };

            struct v2f
            {
                float4 vertex					 : POSITION;
				half3 	normal					 : NORMAL;
				float4 uv						 : TEXCOORD0;
				float3	posWS					: TEXCOORD1;
				float4	shadowCoord				 : TEXCOORD2;
            	float3 	viewDir					: TEXCOORD3;
            	float4	additionalData			: TEXCOORD5;
            	float4 shadowCoord2				:TEXCOORD6;
            	half3x3 TBN						:TEXCOORD7;
            };

            float4 SampleWaterRing(half2 uv)
            {
	            return SAMPLE_TEXTURE2D(_WaterRing,sampler_WaterRing,uv);
            }

            half3 SampleFoamMap(half2 uv)
            {
	            return SAMPLE_TEXTURE2D(_FoamMap,sampler_FoamMap,uv);
            }
            
            half3 Scattering(half depth)
			{
				return SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp2, sampler_AbsorptionScatteringRamp2, half2(depth, 0)).rgb;
			}

            float2 AdjustedDepth(half2 uvs, half4 additionalData)
			{
				float rawD = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uvs);
				float d = LinearEyeDepth(rawD, _ZBufferParams);

				// TODO: Changing the usage of UNITY_REVERSED_Z this way to fix testing, but I'm not sure the original code is correct anyway.
				// In OpenGL, rawD should already have be remmapped before converting depth to linear eye depth.
			#if UNITY_REVERSED_Z
				float offset = 0;
			#else
				float offset = 1;
			#endif
				
 				return float2(d * additionalData.x - additionalData.y, (rawD * -_ProjectionParams.x) + offset);
			}

            half3 Absorption(half depth)
			{
				return SAMPLE_TEXTURE2D(_AbsorptionScatteringRamp, sampler_AbsorptionScatteringRamp, half2(depth, 0.0h)).rgb;
			}
            
            half3 Refraction(half2 distortion, half depth, real depthMulti)  //折射
			{
            	
				half3 output = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, distortion, depth * 0.25).rgb;
				output *= Absorption((depth) * depthMulti);
				return output;
			}
            
            half4 AdditionalData(float3 postionWS)
			{
			    half4 data = half4(0.0, 0.0, 0.0, 0.0);
			    float3 viewPos = TransformWorldToView(postionWS);
				data.x = length(viewPos / viewPos.z);// distance to surface
			    data.y = length(GetCameraPositionWS().xyz - postionWS); // local position in camera space
				return data;
			}

            half2 DistortionUVs(half depth, float3 normalWS)
			{
				half3 viewNormal = mul((float3x3)GetWorldToHClipMatrix(), -normalWS).xyz;
            	
				return viewNormal.xz *0.05;
			}

            half CalculateFresnelTerm(half3 normalWS, half3 viewDirectionWS)
			{
				return pow(1.0 - saturate(dot(normalWS, viewDirectionWS)), 10);
			}
		 
		   half3 SampleReflections(half3 normalWS, half2 screenUV, half fresnelTerm)
		   {
				half3 reflection = 0;
				half2 reflectionUV = screenUV + normalWS.zx * half2(0.02, 0.15);
				reflection += SAMPLE_TEXTURE2D(_PlanarReflectionTexture, sampler_PlanarReflectionTexture, reflectionUV).rgb;//planar reflection
				return reflection * fresnelTerm;
		   }

            float SineWave(float4 waveParam, float speed, float x)
	        {
	            float amplitude = waveParam.x;
	            float waveLength = waveParam.y;
	            float k = 2 * PI / max(1, waveLength);
	            float waveOffset = amplitude * sin(k * (x - speed));
	            return waveOffset;
	        }
 
            v2f vert (appdata v)
            {
                v2f o;	
				o.normal = float3(0, 1, 0);			
		   		o.posWS  = TransformObjectToWorld(v.vertex);
            	o.posWS.y += SineWave(_WaveParam,_Speed * _Time.y,o.posWS * 0.5);
            	o.posWS.y += SineWave(_WaveParam, _Time.y * _Speed + 0.5,o.posWS.z * 0.2);
                o.vertex = TransformWorldToHClip(o.posWS);
				o.shadowCoord = ComputeScreenPos(o.vertex);
				o.viewDir = SafeNormalize(_WorldSpaceCameraPos - o.posWS);
		   		float time = _Time.y;
				// Detail UVs
				o.uv.zw = o.posWS.xz * 0.1h + time * 0.05h;
				o.uv.xy = o.posWS.xz * 0.4h - time.xx * 0.1h;

				/*VertexNormalInputs normal_inputs = GetVertexNormalInputs(v.normal.xyz);
            	o.TBN[0] = normal_inputs.tangentWS;
            	o.TBN[1] = normal_inputs.bitangentWS;
            	o.TBN[2] = normal_inputs.normalWS;*/
            	
            	o.additionalData = AdditionalData(o.posWS);
		   	
                return o;
            }

            float4 frag (v2f IN) : SV_Target
            {		
				half4 waterColor = _WaterColor;//half4(0,0.1,0.3,0.7);
				half3 screenUV = IN.shadowCoord.xyz / IN.shadowCoord.w;

            	Light mainLight = GetMainLight(IN.shadowCoord2);

            	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenUV.xy);
            	float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenUV.xy);
            	depth2 = Linear01Depth(depth2,_ZBufferParams);

            	half depthMulti = 1 / _MaxDepth;

				// Detail waves
				half2 detailBump1 = SAMPLE_TEXTURE2D(_NoiseMap, sampler_NoiseMap, IN.uv.zw * 0.3).xy * 2 - 1;
				half2 detailBump2 = SAMPLE_TEXTURE2D(_NoiseMap2, sampler_NoiseMap2, IN.uv.xy * 0.3).xy * 2 - 1;
				half2 detailBump = (detailBump1 * 0.2 + detailBump2 * 0.2);
				IN.normal += half3(detailBump.x, 0, detailBump.y) * 2;
				IN.normal = normalize(IN.normal);

            	/*//WaterRing
            	float4 ringColor = SampleWaterRing(screenUV);
            	float3 ringNormal = ringColor * 0.5 + 0.5;
            	
            	ringNormal = mul(IN.TBN,ringNormal);
            	ringNormal = normalize(ringNormal) * ringColor.a * _RingPower;
            	IN.normal =  normalize(ringNormal + IN.normal);*/

            	// Fresnel
				half fresnelTerm = CalculateFresnelTerm(IN.normal, IN.viewDir.xyz);
            	
				half3 reflection = SampleReflections(IN.normal, screenUV.xy, fresnelTerm);
            	
				waterColor.xyz += reflection;

            	//GI
            	float3 GI = SampleSH(IN.normal);
            	

            	 // Distortion
				half2 distortion = DistortionUVs(depth.x, IN.normal);
				distortion = screenUV.xy + distortion;// * clamp(depth.x, 0, 5);
				float d = depth.x;
				depth.x = AdjustedDepth(distortion, IN.additionalData);
				distortion = depth.x < 0 ? screenUV.xy : distortion;
            	
				//calc depth
            	float diffDepth = 0;
            	float rawD = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,screenUV.xy);
            	float CameraDepline = LinearEyeDepth(rawD,_ZBufferParams);
            	diffDepth = CameraDepline * IN.additionalData.x - IN.additionalData.y;
            	diffDepth = diffDepth * 0.01;
            	diffDepth = smoothstep(0,1,diffDepth);

            	

            	//Absorption
				half3 RampCol = Absorption(diffDepth);

            	//SSSscattering
            	half3 RampCol2 = Scattering(diffDepth);

				

            	//BRDFData
            	BRDFData brdf_data;
            	half alpha = 1;
            	InitializeBRDFData(half3(0,0,0),0,half3(1,1,1),1,alpha,brdf_data);
            	half3 spec = DirectBRDF(brdf_data,IN.normal,mainLight.direction,IN.viewDir + half3(1,0.5,-0.1)) * mainLight.color;

			
            	
            	//Foam
				half3 FoamCol = SampleFoamMap(IN.uv * 0.1);
            	half oneminedepth = saturate(1-depth2);
				half depthEdge = saturate(depth.x * 20);
            	half edgeFoam = saturate(1 - diffDepth * 20 - 0.2) * depthEdge ;
            	half edgeFoam2 = saturate(1 - diffDepth * 2000);
            	half foamValue = saturate((FoamCol.yyy * edgeFoam));
            	foamValue += edgeFoam2;
            	half3 foam = foamValue.xxx * (mainLight.shadowAttenuation * mainLight.color + GI);
            	
            	half4 resultCol = waterColor + float4(RampCol,1) + float4(RampCol2,1) + float4(spec,1) + float4(foam,1) * mainLight.shadowAttenuation;
            	
				return resultCol;//float4(RampCol2,1);
				
            }
            ENDHLSL
        }

    }
}