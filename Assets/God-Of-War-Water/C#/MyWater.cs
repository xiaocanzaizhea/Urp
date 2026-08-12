using System;
 using System.Collections.Generic;
 using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;
using Random = UnityEngine.Random;

[ExecuteAlways]
public class MyWater : MonoBehaviour
{
    public List<Mesh> mMeshs = new List<Mesh>();//水平面的模型组
    public Material mWaterMaterial;//水材质

    public PlanarReflections _planarReflections;
    
    
    // Start is called before the first frame update
    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += BeginCameraRendering;

        if (!gameObject.TryGetComponent(out _planarReflections))
        {
            _planarReflections = gameObject.AddComponent<PlanarReflections>();
        }
        _planarReflections.hideFlags = HideFlags.HideAndDontSave | HideFlags.HideInInspector;
    }

    private void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= BeginCameraRendering;
    }

    private void BeginCameraRendering(ScriptableRenderContext src, Camera cam)
    {
        if (cam.cameraType == CameraType.Preview)
            return;
        if (mWaterMaterial == null || mMeshs == null)
            return;

        const float quantizeValue = 6.25f;
        const float forwards = 10f;
        const float yOffset = -0.25f;

        //按照相机的位置朝向绘制水平面Mesh
        Vector3 waterPos = cam.transform.TransformPoint(Vector3.forward * forwards);
        waterPos.y = yOffset;
        waterPos.x = quantizeValue * (int)(waterPos.x / quantizeValue);
        waterPos.z = quantizeValue * (int)(waterPos.z / quantizeValue);
        Matrix4x4 trsMatrix = Matrix4x4.TRS(waterPos, Quaternion.identity, Vector3.one);
        foreach (var mesh in mMeshs)
        {
            Graphics.DrawMesh(mesh,
                trsMatrix,
                mWaterMaterial,
                gameObject.layer,
                cam,
                0,
                null,
                ShadowCastingMode.Off,
                true,
                null,
                LightProbeUsage.Off,
                null);
        }
    }
    
    
}