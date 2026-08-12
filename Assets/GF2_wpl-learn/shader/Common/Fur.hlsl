#ifndef FUR_INCLUDE
#define FUR_INCLUDE

#include "Assets/GF2_wpl-learn/shader/Common/common.hlsl"
struct a2v
{
    float4 vertex 	:POSITION;
    float3 normal 	:NORMAL;
    float4 tangent 	:TANGENT;
    float4 color  	:COLOR;
    float2 texcoord0 		:TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID 
};
struct v2f
{
    float4 pos		:SV_POSITION;
    float3 posWS   	:TEXCOORD0;
    float3 nDirWS     	:TEXCOORD1;
    float3 tDirWS    	:TEXCOORD2;
    float3 bDirWS  	:TEXCOORD3;
    float4 color 			:TEXCOORD4;
    float4 uv0				:TEXCOORD5;
    float4 uv1  			:TEXCOORD6;
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

//顶点Shader
v2f vert (a2v v) {
    v2f o;  //定义返回值
    //传递UV
    o.uv0.xy = TRANSFORM_TEX(v.texcoord0, _BaseColorTex);  //颜色贴图uv
    o.uv0.zw = TRANSFORM_TEX(v.texcoord0, _NormalTex);     //法线贴图uv
    o.uv1.xy = TRANSFORM_TEX(v.texcoord0, _MRAFurTex);     //属性贴图uv
    o.uv1.zw = TRANSFORM_TEX(v.texcoord0, _FurNoise);      //毛发遮罩uv  

    //计算顶点位移
    half3 direction = lerp(v.normal, _FurDirection * _GravityStrength + v.normal * (1 - _GravityStrength), _FUR_LAYER);  //毛发挤出方向
    v.vertex.xyz += direction * _FurLength * _FUR_LAYER;    //顶点位移

    //传递其它数据
    o.pos = TransformObjectToHClip(v.vertex.xyz);           //MVP变换(模型空间>>世界空间>>视觉空间>>裁剪空间)
    o.nDirWS = TransformObjectToWorldNormal(v.normal.xyz);  //世界空间法线
    o.tDirWS = TransformObjectToWorld(v.tangent.xyz);       //世界空间切线
    o.bDirWS = cross(o.nDirWS, o.tDirWS) * v.tangent.w;     //世界空间副切线
    o.posWS = TransformObjectToWorld(v.vertex.xyz);         //世界空间顶点
    
    return o;       
}

//片元Shader
half4 frag (v2f i) : SV_TARGET {

    Light mainLight = GetMainLight();

    
    // VectorPrepare
    float3 lightDirWS = SafeNormalize(mainLight.direction);
    float3 camDirWS = GetCameraPositionWS();
    float3 viewDirWS = SafeNormalize(camDirWS - i.posWS);
    float3 normalWS = SafeNormalize(i.nDirWS);
    float3 viewNormal = normalize(TransformWorldToViewDir(normalWS));
    
    float3 halfDir = SafeNormalize(lightDirWS + viewDirWS);
    float halfLambert = dot(normalWS, lightDirWS) * 0.5 + 0.5;
    float NdotL = saturate(dot(normalWS, lightDirWS));
    float NdotV = saturate(dot(normalWS, viewDirWS));
    float NdotH = saturate(dot(normalWS, halfDir));
    float HdotV = saturate(dot(halfDir,  viewDirWS));
    float LdotF = 1 - saturate(dot(lightDirWS, float3(0,0,-1)));

    
    //采样贴图
    half4 baseColor = _Color * SAMPLE_TEXTURE2D(_BaseColorTex, sampler_BaseColorTex, i.uv0.xy);    //颜色贴图
    half3 emission = _Emissive * baseColor.rgb * baseColor.a;                                   //自发光贴图
    float3 normalTex = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, i.uv0.zw));    //切线空间法线(采样法线贴图并解码)
    half4 MRAFurTex = SAMPLE_TEXTURE2D(_MRAFurTex, sampler_MRAFurTex, i.uv1.xy);                   //属性贴图

    
    //准备向量
    Light mlight = GetMainLight();                                      //光源
    half3 lDirWS= normalize(mlight.direction);                          //世界光源方向(平行光)
    normalTex.xy = normalTex.xy * _Normal;                              //法线强度
    float3x3 TBN = float3x3(i.tDirWS, i.bDirWS, i.nDirWS);              //构建TBN矩阵
    half3 nDirWS = normalize(mul(normalTex, TBN));                      //切线空间法线转世界空间法线
    half3 vDirWS = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);   //世界观察方向
    half3 hDir = normalize(vDirWS + lDirWS) ;                           //半角向向
    float3 vrDirWS = reflect(-vDirWS, nDirWS);                          //反射向量
    
    //计算颜色
    half3 PBRMaterial = 0.8;                 //PBR
    half3 col = saturate(lerp(lerp(_ShadowColor.rgb, 1, _FUR_LAYER), 1, saturate(1 - _ShadowStrength))) * mainLight.color * 13 ;    //毛发阴影颜色和强度
    float mask = (NdotL * 0.99 + 0.01);
    col *= mask;
    
                //Aaddtionnal Light
                float3 addDiffColor = 0;
                float3 addSpecColor = 0;
                float3 addresult = 0;
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                        Light light = GetAdditionalLight(0, i.posWS.xyz);
                        //diff
                        addDiffColor += LightingLambert(light.color, light.direction, normalWS); // sat(NoL) * LightColor
                        //spec
                        float3 halfAdd = normalize(light.direction+viewDirWS);
                        float NdotAddH = saturate(dot(normalWS,halfAdd));
                        float NdotAddL = saturate(dot(normalWS,light.direction));
                        float NdotAddV = 0.5 - saturate(dot(viewDirWS,normalWS));
                        NdotAddV = step(0.1,NdotAddV);
                        addSpecColor += DistributionGGX(NdotAddH,0.1) * light.color  * NdotAddL;

                        float pos = light.distanceAttenuation /10 ;
                        
                        //不进行着色，改成着色边缘
                        addresult += pos * light.color;
                        
                }
               

                

    
    //alpha compute
    half alpha = 1 - _FUR_LAYER * _FUR_LAYER;                                               //层数透明度
    alpha += (dot(vDirWS, nDirWS) - _vanishingEdge);                                        //边缘透明度渐变
    alpha = max(0, alpha);                                                                  //取最大
    half FurThickness = SAMPLE_TEXTURE2D(_FurNoise, sampler_FurNoise, i.uv1.zw) * MRAFurTex.a; //采样毛发遮罩
    FurThickness = step(lerp(0, _FurThickness, _FUR_LAYER), FurThickness);                  //毛发粗细
    alpha *= FurThickness;                                                                  //透明度
    
    float3 normal = normalize(mul(UNITY_MATRIX_V, float4(i.nDirWS,0)).xyz);
    half3 SH = saturate(normal.y *0.25+0.35) ;
    
    half Occlusion = _FUR_LAYER*_FUR_LAYER; //伽马转线性最精简版

    Occlusion +=0.04 ;

    half3 SHL = lerp (_OcclusionColor*SH,SH,Occlusion);

    //输出
    return half4(col + SHL + addresult, alpha);
}

#endif