Shader "Water/WaterRing"
{
    Properties
    {
        _RingWidth("_RingWidth",Range(0,20)) = 0.5
        _RingRange("_RingRange",Range(0,1)) = 0.5
        _RingSmoothness("_RingSmoothness",Range(0,0.1)) = 0.01
        
        _BumpPower("_BumpPower",Float) = 0.5
        
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
            
            float _RingWidth;
            float _RingRange;
            float _RingSmoothness;
            float _BumpPower;
            
            half doubleSmoothstep(float4 uv)
            {
                float dis = distance(uv, 0.5);
                float halfWidth = _RingWidth * 0.5;
                float range = _RingRange;
                float smoothness = _RingSmoothness;
                float threshold1 = range - halfWidth;
                float threshold2 = range + halfWidth;

                float value = smoothstep(threshold1, threshold1 + smoothness, dis);
                float value2 = smoothstep(threshold2, threshold2 + smoothness, dis);

                return value - value2;
            }
            

           struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float4 uv           : TEXCOORD0;
                float2 uvLM         : TEXCOORD1;
                float4 color        :COLOR;
            };
            
            struct Varyings
            {
                float4 uv                       : TEXCOORD0;
                float3 positionWS               : TEXCOORD1;
                half3  normalWS                 : TEXCOORD3;
                float4 positionCS               : SV_POSITION;
                float4 color                    :TEXCOORD2;
            };
            

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.positionWS = vertexInput.positionWS;
                output.uv = input.uv;
                output.color = input.color;
                output.normalWS = vertexNormalInput.normalWS;
                output.positionCS = vertexInput.positionCS;
                return output;
            }

            half4 frag (Varyings i) : SV_Target
            {
            	
				float normalCenter = doubleSmoothstep(i.uv);
                // 波纹法线
                float color0 = doubleSmoothstep(i.uv + half4(-1, 0, 0, 0) * 0.004);
                float color1 = doubleSmoothstep(i.uv + half4(1, 0, 0, 0) * 0.004);
                float color2 = doubleSmoothstep(i.uv + half4(0, -1, 0, 0) * 0.004);
                float color3 = doubleSmoothstep(i.uv + half4(0, 1, 0, 0) * 0.004);

                float2 ddxy = float2(color0 - color1, color2 - color3);
                float3 normal = float3((ddxy * _BumpPower), 1.0);
                normal = normalize(normal);
                float4 finalColor = float4((normal * 0.5 + 0.5) * normalCenter * i.color.a, normalCenter * i.color.a);
                return finalColor;
            }
            ENDHLSL
        }
    }
}