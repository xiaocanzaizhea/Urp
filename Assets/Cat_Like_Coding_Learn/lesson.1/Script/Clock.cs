using System;
using UnityEngine;

public class Clock : MonoBehaviour
{
    const float hoursToDegrees = -30f,minutesToDegrees = -6f, secondsToDegrees = -6f;  //const初始化后就不能更改，保证程序周期不会变化
    [SerializeField]
    Transform hoursPivot,MinutesPivot,secondsPivot;

    void Update()
    {
        TimeSpan time = DateTime.Now.TimeOfDay;
        hoursPivot.localRotation = Quaternion.Euler(0f , 0f , hoursToDegrees * (float)time.TotalHours);
        MinutesPivot.localRotation = Quaternion.Euler(0f , 0f , minutesToDegrees * (float)time.TotalMinutes);
        secondsPivot.localRotation = Quaternion.Euler(0f , 0f , secondsToDegrees * (float)time.TotalSeconds);
    }
}