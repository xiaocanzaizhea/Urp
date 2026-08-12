using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Graph : MonoBehaviour
{
    [SerializeField]
    Transform pointPrefab;
    
    [SerializeField, Range(10, 200)]
    int resolution = 10;

    [SerializeField]
    FunctionLibrary.FunctionName function;
    
    public enum TransitionMode { Cycle, Random }
    
    [SerializeField]
    TransitionMode transitionMode;
    
    [SerializeField, Min(0f)]//隔几秒换一个， 过度平滑值
    float functionDuration = 1f, transitionDuration = 1f;
    
    

    Transform[] points;
    
    float duration;

    bool transitioning;  //是否平滑过度

    private FunctionLibrary.FunctionName transitionFunction;
    
    void Awake () {
        float step = 2f / resolution;
        var scale = Vector3.one * step;
       
        points = new Transform[resolution * resolution];
        for (int i = 0; i < points.Length; i++) {
            
            Transform point = points[i] = Instantiate(pointPrefab);
            
            point.localScale = scale;
            point.SetParent(transform, false);
        }
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
        
        
        
        if (transitioning) {
            UpdateFunctionTransition();
        }
        else {
            UpdateFunction();
        }
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

    void UpdateFunction()
    {
        FunctionLibrary.Function f = FunctionLibrary.GetFunction(function);
        float time = Time.time;
        float step = 2f / resolution;
        //对我们的方块数组进行y轴上的动画
        float v = 0.5f * step - 1f;
        for (int i = 0, x = 0, z = 0; i < points.Length; i++,x++)
        {
            if (x == resolution)
            {
                x = 0;
                z += 1;
                v = (z + 0.5f) * step - 1f;
            }

            float u = (x + 0.5f) * step - 1f;
            points[i].localPosition = f(u, v, time);
            
            Transform point = points[i];
            Vector3 position = point.localPosition; //先取出来然后进行赋值
            point.localPosition = position;
        }
    }
    void UpdateFunctionTransition () {
        FunctionLibrary.Function
            from = FunctionLibrary.GetFunction(transitionFunction),
            to = FunctionLibrary.GetFunction(function);
        float progress = duration / transitionDuration;
        float time = Time.time;
        float step = 2f / resolution;
        //对我们的方块数组进行y轴上的动画
        float v = 0.5f * step - 1f;
        for (int i = 0, x = 0, z = 0; i < points.Length; i++,x++)
        {
            if (x == resolution)
            {
                x = 0;
                z += 1;
                v = (z + 0.5f) * step - 1f;
            }

            float u = (x + 0.5f) * step - 1f;
            points[i].localPosition = FunctionLibrary.Morph(
                u, v, time, from, to, progress
            );
            
            Transform point = points[i];
            Vector3 position = point.localPosition; //先取出来然后进行赋值
            point.localPosition = position;
        }
    }
}
