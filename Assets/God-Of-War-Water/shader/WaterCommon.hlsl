#ifndef WATER_LEARN
#define WATER_LEARN

//环境光
half3 GetAmbientLight(){
    return half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
}
//计算水体的高光
half3 WaterSpecular(float3 viewDir,float3 normal,float gloss,float shininess){
    Light mainLight = GetMainLight();
    float3 halfDir = normalize(mainLight.direction + viewDir);
    float nl = max(0,dot(halfDir,normal));
    return gloss * pow(nl,shininess) * mainLight.color;
}

//天空盒采样
half3 SampleSkybox(samplerCUBE cube,float3 normal,float3 viewDir,float smooth){
    float3 adjustNormal = float3(normal);
    adjustNormal.xz /= smooth;
    float3 refDir = reflect(-viewDir,adjustNormal);
    half4 color = texCUBE(cube,refDir);
    return color.rgb;
}



#endif