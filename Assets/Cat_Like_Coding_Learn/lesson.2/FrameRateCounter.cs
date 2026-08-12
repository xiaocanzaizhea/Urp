using System;
using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class FrameRateCounter : MonoBehaviour
{
    [SerializeField]
    TextMeshProUGUI display;
    
    [SerializeField, Range(0.1f, 2f)]
    float sampleDuration = 1f;
    
    public enum DisplayMode { FPS, MS }
    
    [SerializeField]
    DisplayMode displayMode = DisplayMode.FPS;

    int frames;
    float duration, bestDuration = float.MaxValue, worstDuration;
    void Update()
    {
        float frameDuration = Time.unscaledDeltaTime;
        frames += 1;
        duration += frameDuration;

        if (frameDuration > worstDuration)  //最差帧
        {
            worstDuration = frameDuration;
        }

        if (frameDuration < bestDuration)  //最好帧
        {
            bestDuration = frameDuration;
        }

        if (duration >= sampleDuration)
        {
            if (displayMode == DisplayMode.FPS)
            {
                display.SetText(
                    "FPS\n{0:0}\n{1:0}\n{2:0}",
                    1f / bestDuration,
                    frames / duration,
                    1f / worstDuration
                );
            }

            if (displayMode == DisplayMode.MS)
            {
                display.SetText(
                    "MS\n{0:1}\n{1:1}\n{2:1}",
                    1000f * bestDuration,
                    1000f * duration / frames,
                    1000f * worstDuration
                );
            }
            frames = 0;
            duration = 0f;
            bestDuration = float.MaxValue;
            worstDuration = 0f;
        }
        
    }
}
