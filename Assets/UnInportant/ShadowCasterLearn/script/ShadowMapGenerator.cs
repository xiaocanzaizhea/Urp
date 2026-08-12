using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ShadowMapGenerator : MonoBehaviour
{
    public Light lightSource;
    public RenderTexture depthMap;
    public Shader depthShader;

    private Camera lightCamera;
    void Start()
    {
        CreateLightCamera();//创建光源相机
        
    }

    // Update is called once per frame
    void Update()
    {
        // 更新光源相机的位置和方向
        lightCamera.transform.position = lightSource.transform.position;
        lightCamera.transform.rotation = lightSource.transform.rotation;
    }
    
    void CreateLightCamera()
    {
        // 创建光源相机
        lightCamera = new GameObject("LightCamera").AddComponent<Camera>();
        lightCamera.transform.position = lightSource.transform.position;
        lightCamera.transform.rotation = lightSource.transform.rotation;
        lightCamera.orthographic = lightSource.type == LightType.Directional;
        lightCamera.nearClipPlane = 0.1f;
        lightCamera.farClipPlane = 50f;
        lightCamera.targetTexture = depthMap;
        lightCamera.SetReplacementShader(depthShader, "");
    }
}
//光源裁剪空间与裁剪空间的区别
//