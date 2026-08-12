Shader "Unlit/wpl_eyesblend"
{
    Properties
    {
        _ReverseACESIntensity           ("ReverseACESIntensity", Range(0,1))         = 0.5
        _MainTex ("Texture", 2D) = "white" {}
        [HDR]_Color("Color", color) = (1,1,1,1)
        _Alpha("Alpha", range(0, 1)) = 1.0
        [Header(Blend Mode)]
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendSrc("Blend src", int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendDst("Blend dst", int) = 1
        [Enum(UnityEngine.Rendering.BlendOp)]
        _BlendOp("BlendOp", int) = 21
    }
    SubShader
    {
        Tags {"RenderType" = "Transparent"  "Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            BlendOp [_BlendOp]
            Blend [_BlendSrc] [_BlendDst]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };


            float4 _MainTex_ST;
            float4 _Color;
            float _Alpha,_ReverseACESIntensity;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

			float3 reverseACES(float3 color)
            {
                return  3.4475 * color * color * color - 2.7866 * color * color + 1.2281 * color - 0.0056;
            }  

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                float3 reverseACESBaseColor = reverseACES(col.rgb);
                float3 BaseColor = lerp(col.rgb,reverseACESBaseColor,_ReverseACESIntensity);

                return half4(BaseColor.rgb * _Color.rgb, _Alpha);
            }
            ENDHLSL
        }
    }
}
