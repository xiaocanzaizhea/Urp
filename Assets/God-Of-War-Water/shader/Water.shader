Shader "Water/Water"
{
    Properties
    {
        _Color("Color",Color) = (1,1,1,1)
    	
    	//Normal
    	_NormalMap1("_NormalMap1",2D) = "bump"{}
    	_NormalMap2("_NormalMap2",2D) = "bump"{}
    	_NormalScale("_NormalScale",Range(0,100)) = 0.5
    	
    	//天空盒
        _SkyBox("SkyBox",Cube) = "white" {}
        _SkyBoxReflectSmooth("SkyBoxReflectSmooth",Range(1,10)) = 3
    	
    	_Gloss("_Gloss",Float) = 0.5
    	_Shininess("_Shininess",Float) = 0.5
    	_FresnelPower("FresnelPower",Range(1,5)) = 3
        
    	//白沫
        _FoamTex("FoamMap", 2D) = "white" {}
        _FoamPower("FoamPower",Range(0,1)) = 0.5
    	
    	_Alpha("Alpha",Range(0,1))= 0.5
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
            Blend SrcAlpha OneMinusSrcAlpha 
            Blend SrcAlpha DstAlpha
            HLSLPROGRAM
            #pragma vertex LitPassVertex
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Assets/God-Of-War-Water/shader/WaterCommon.hlsl"
            
           

            
            

           struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;
                float2 uvLM         : TEXCOORD1;
                
            };
            
            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                float3 positionWS               : TEXCOORD1;
                half3  normalWS                 : TEXCOORD3;
                float4 positionCS               : SV_POSITION;
            };
            
            float _Gloss;
            float _Shininess;
            float _FresnelPower;
            
            sampler2D _NormalMap1;
            float4 _NormalMap1_ST;
            sampler2D _NormalMap2;
            float4 _NormalMap2_ST;
            float _NormalScale;

            float _Alpha;
            samplerCUBE _SkyBox;
            float _SkyBoxReflectSmooth;

            
            sampler2D _FoamTex;
            float _FoamPower;

            static float3 SampleNormal(sampler2D normalMap,float2 uv){
                float4 packedNormal = tex2D(normalMap, uv);
                float3 waterNormal = UnpackNormal(packedNormal);
                return float3(waterNormal.x,waterNormal.z,waterNormal.y);     
            }

            

            float3 SampleWaterNormal(float2 uv){
                float2 velocity = float2(1,0) * 0.02;
                float t = _Time.y ;
                float3 n1 = SampleNormal(_NormalMap1,(uv + velocity.yx * t  * 1.2) * _NormalScale);
                float3 n2 = SampleNormal(_NormalMap2,(uv + velocity.xy * t ) * _NormalScale); 
                float3 n = n2 + n1  ;
                n = normalize(n);
                return n;
            }

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.positionWS = vertexInput.positionWS;
                output.uv = input.uv;
                output.normalWS = vertexNormalInput.normalWS;
                output.positionCS = vertexInput.positionCS;
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
            	
				 float2 screenUV = input.positionCS.xy * (_ScreenParams.zw - 1);
                float2 uv = input.uv;
                float3 positionWS = input.positionWS;

                float time = _Time.y;

                float waterSurfaceDepth = input.positionCS.z;
                float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
                Light mainLight = GetMainLight(shadowCoord);

                //反射
                
                float3 waterNormal = SampleWaterNormal(uv);

                float3 viewDir = normalize(_WorldSpaceCameraPos - input.positionWS);
                
                //主光源
                half3 specTerm = WaterSpecular(viewDir,waterNormal,_Gloss,_Shininess);
                half3 ambientTerm = GetAmbientLight();

                float3 reflectionTerm = specTerm;

                //skybox
                float3 Water_Skybox = SampleSkybox(_SkyBox,waterNormal,viewDir,_SkyBoxReflectSmooth);

                return float4(Water_Skybox + reflectionTerm,_Alpha);
            }
            ENDHLSL
        }
    }
}