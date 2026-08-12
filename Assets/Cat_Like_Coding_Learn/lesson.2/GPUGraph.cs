using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GPUGraph : MonoBehaviour
{
    [SerializeField]
    ComputeShader computeShader;
    
    [SerializeField]
    Material material;

    [SerializeField]
    Mesh mesh;

    private const int maxResolution = 1000;
    
    [SerializeField, Range(10, maxResolution)]
    int resolution = 10;

    [SerializeField]
    FunctionLibrary.FunctionName function;
    
    public enum TransitionMode { Cycle, Random }
    
    [SerializeField]
    TransitionMode transitionMode;
    
    [SerializeField, Min(0f)]//隔几秒换一个， 过度平滑值
    float functionDuration = 1f, transitionDuration = 1f;
    
    float duration;

    bool transitioning;  //是否平滑过度

    private FunctionLibrary.FunctionName transitionFunction;
    
    ComputeBuffer positionsBuffer;
    
    static readonly int positionsId = Shader.PropertyToID("_Positions"),
        resolutionId = Shader.PropertyToID("_Resolution"),
        stepId = Shader.PropertyToID("_Step"),
        timeId = Shader.PropertyToID("_Time"),
        trasnsitionId = Shader.PropertyToID("_TransitionProgress");

    void UpdateFunctionOnGPU()
    {//先取出我们的变量id，然后用setint进行赋值
        float step = 2f / resolution;
        computeShader.SetInt(resolutionId, resolution);
        computeShader.SetFloat(stepId, step);
        computeShader.SetFloat(timeId, Time.time);
        if (transitioning)
        {
            computeShader.SetFloat(trasnsitionId, Mathf.SmoothStep(0f, 1f, duration / transitionDuration));
        }
        
        var kernelIndex = (int)function + (int)(transitioning ? transitionFunction : function) * FunctionLibrary.FunctionCount;
        computeShader.SetBuffer(kernelIndex, positionsId, positionsBuffer); //
        int groups = Mathf.CeilToInt(resolution / 8f);
        computeShader.Dispatch(kernelIndex,groups,groups,1);  //调度x方向y方向group个数线程组
        
        material.SetBuffer(positionsId, positionsBuffer);
        material.SetFloat(stepId, step);
        var bounds = new Bounds(Vector3.zero, Vector3.one * (2f + 2f / resolution));
        Graphics.DrawMeshInstancedProcedural(mesh, 0, material, bounds, resolution * resolution);//
        //用material处理mesh绘制
    }

    private void Awake()
    {
        positionsBuffer = new ComputeBuffer(maxResolution * maxResolution, 3 * 4);
    }

    void Update()
    {
        duration += Time.deltaTime;
        if (transitioning)
        {
            if (duration >= transitionDuration) {
                duration -= transitionDuration;
                transitioning = false;
            }
        }
        else if (duration >= functionDuration)// 隔几秒换函数
        {
            duration -= functionDuration;
            transitioning = true;
            transitionFunction = function;
            PickNextFunction();
        }
        
        UpdateFunctionOnGPU();
    }

    private void OnEnable()
    {
        positionsBuffer = new ComputeBuffer(resolution * resolution, 3 * 4);
    }

    private void OnDisable()
    {
        positionsBuffer.Release();
        positionsBuffer = null;
    }

    void PickNextFunction () {
        function = transitionMode == TransitionMode.Cycle ?
            FunctionLibrary.GetNextFunctionName(function) :
            FunctionLibrary.GetRandomFunctionNameOtherThan(function);
    }

    public static Vector3 Morph(//平滑
        float u, float v, float t, FunctionLibrary.Function from, FunctionLibrary.Function to, float progress
    )
    {
        return Vector3.LerpUnclamped(
            from(u, v, t), to(u, v, t), Mathf.SmoothStep(0f, 1f, progress)
        );
    }

    
}
