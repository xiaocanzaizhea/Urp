using UnityEngine;

public class CustomShadowMap : MonoBehaviour
{
    private Camera _lightCamera;
    public GameObject lightObj; // 光源对象
    public Material DepthMat;   // 用于渲染深度的材质
    public float qulity = 1.0f; // RenderTexture 的质量系数
    private RenderTexture lightDepthTexture;
    

    void Start()
    {
        _lightCamera = CreateLightCamera();
    }

    void Update()
    {
        // 将光源相机与光源对象同步
        _lightCamera.transform.parent = lightObj.transform;
        _lightCamera.transform.localPosition = Vector3.zero;
        _lightCamera.transform.localRotation = Quaternion.identity;
        
        // 计算并设置全局矩阵
        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(_lightCamera.projectionMatrix, true);
        Shader.SetGlobalMatrix("_worldToLightClipMat", projectionMatrix * _lightCamera.worldToCameraMatrix);
        

        // 使用指定的 shader 渲染深度图
        _lightCamera.RenderWithShader(DepthMat.shader, "depth");
    }

    public Camera CreateLightCamera()
    {
        GameObject goLightCamera = new GameObject("Shadow Camera");
        Camera LightCamera = goLightCamera.AddComponent<Camera>();
        
        LightCamera.backgroundColor = Color.black;
        LightCamera.clearFlags = CameraClearFlags.Depth;
        LightCamera.Render();
        LightCamera.orthographic = true;
        LightCamera.orthographicSize = 6f;
        LightCamera.nearClipPlane = 0.3f;
        LightCamera.farClipPlane = 50;
        LightCamera.enabled = false;

        if (!LightCamera.targetTexture)
            LightCamera.targetTexture = CreateTextureFor(LightCamera);
        lightDepthTexture = LightCamera.targetTexture;

        Shader.SetGlobalTexture("_LightDepthTexture", lightDepthTexture);
        
        return LightCamera;
    }

    private RenderTexture CreateTextureFor(Camera cam)
    {
        RenderTexture rt = new RenderTexture((int)(1024 * qulity), (int)(1024 * qulity), 32, RenderTextureFormat.Depth);
        rt.hideFlags = HideFlags.DontSave;
        rt.name = "_ObjectDepthTexture";
        return rt;
    }
}