Shader "Unlit/wpl_Fur2"
{
    Properties
    {
        //面板参数
        [Header(Basics)]  //基础
        [Space(10)]
        _BaseColorTex( "颜色贴图(BaseColor)" , 2D) = "white" {}
        _Color( "漫反射颜色" , Color) = (1.0, 1.0, 1.0, 1.0)
        [HDR]_Emissive( "自发光颜色" , Color) = (1.0, 1.0, 1.0, 1.0)
        _RimOffset("_RimOffset",Float) = 1
        _EmissionIntensity("_EmissionIntensity",Float) = 1
        [Space(15)]
        
        _NormalTex( "法线贴图(Normal)" , 2D) = "bump" {}
        _Normal( "法线强度" , Float) = 1.0
        [Space(15)]
        
        _MRAFurTex( "属性贴图(MRAFur)" , 2D) = "white" {}
        _Metallic( "金属度强度" , Float) = 1.0
        _Roughness( "粗糙度强度" , Float) = 1.0
        _AOStrength( "AO强度" , Float) = 1.0
        [Space(15)]
        
        [Header(Fur)]  //毛发
        [Space(10)]
        _FurNoise( "毛发遮罩" , 2D) = "bump" {}
        _FurLength( "毛发长度" , Float) = 1.0
        _FurThickness("毛发粗细", Range(0,1)) = 0.5
        _vanishingEdge( "边缘消失" , Range(0, 1)) = 0.5
        _ShadowColor("阴影颜色", Color) = (0,0,0,0)
        _ShadowStrength( "阴影强度" , Range(0.0, 2.0)) = 1.0
        _GravityStrength("重力强度", Range(0,1)) = 0.25
        _FurDirection( "毛发朝向" , Vector) = (0.0, -1.0, 0.0, 0.0)
        _OcclusionColor("AO",Color) = (0.8,0.8,0.8,1)
        
        _FresnelLV("_FresnelLV",Float) = 0.5
        _LightFilter("平行光毛发穿透",  Range(-0.5,0.5)) = 0.0
        
    }
    SubShader
    {
        HLSLINCLUDE
        //导入库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"        //默认库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"    //光照库
        CBUFFER_START(UnityPerMaterial)  //常量缓冲区开头
            float _EmissionIntensity;
            float _RimOffset;
            //声明面板参数
            half4 _BaseColorTex_ST; //颜色贴图变换偏移
            half4 _Color;           //漫反射颜色
            half4 _Emissive;        //自发光颜色
            half4 _NormalTex_ST;    //法线贴图变换偏移
            half _Normal;           //法线强度
            half4 _MRAFurTex_ST;    //属性贴图变换偏移
            half _Metallic;         //金属度强度
            half _Roughness;        //粗糙度强度
            half _AOStrength;       //AO强度
            half4 _FurNoise_ST;     //毛发遮罩变换偏移
            half _FurLength;        //毛发长度
            half _FurThickness;     //毛发粗细
            half _vanishingEdge;    //边缘消失
            half4 _ShadowColor;     //阴影颜色
            half _ShadowStrength;   //阴影强度
            half _GravityStrength;  //重力强度
            half4 _FurDirection;    //毛发方向
            float _FUR_LAYER;       //毛发层数   renderfeature定义的参数
            float4 _OcclusionColor;
            float _FresnelLV;
            float _LightFilter;
        CBUFFER_END  //常量缓冲区结尾
            //声明贴图
            TEXTURE2D(_BaseColorTex);       //BaseColor
            SAMPLER(sampler_BaseColorTex);
            TEXTURE2D(_NormalTex);          //Normal
            SAMPLER(sampler_NormalTex);
            TEXTURE2D(_MRAFurTex);          //MRAFur
            SAMPLER(sampler_MRAFurTex);
            TEXTURE2D(_FurNoise);          //毛发遮罩
            SAMPLER(sampler_FurNoise);
        ENDHLSL

        //基础渲染
        Pass {  //pass语义段
            Name "BasicsPass"                       //pass名字
            Tags { "LightMode" = "BasicsPass" }     //渲染标签
                
            HLSLPROGRAM  //Shader开头
            #pragma vertex vert     //定义顶点Shader
            #pragma fragment frag   //定义片元Shader
            
            #include "Assets/GF2_wpl-learn/shader/Common/Fur.hlsl"  //导入文件
            

            ENDHLSL  //Shader结尾
        }

        //渲染毛发Pass
        Pass {  //pass语义段
            Name "FurPass"                      //pass名字
            Tags { "LightMode" = "FurPass" }    //渲染标签
            Cull Off                            ///关闭背面剔除
            ZWrite Off                          //关闭深度写入
            Blend SrcAlpha OneMinusSrcAlpha     //透明度混合
                
            HLSLPROGRAM  //Shader开头
            #pragma vertex vert     //定义顶点Shader
            #pragma fragment frag   //定义片元Shader

            #include "Assets/GF2_wpl-learn/shader/Common/Fur.hlsl"  //导入文件
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            ENDHLSL  //Shader结尾
        }

        UsePass "Character/Outline/GF2Outline"
    }
}
