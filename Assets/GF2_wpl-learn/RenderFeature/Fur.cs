using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class Fur : ScriptableRendererFeature
{
    [System.Serializable]
    public class FilterSettings
    {
        public RenderQueueType RenderQueueType;//渲染队列类型
        
        public LayerMask LayerMask;  //层掩码，用于指定那些层的物体要渲染

        public string[] PassNames; //pass列表

        public FilterSettings()
        {
            RenderQueueType = RenderQueueType.Opaque;
            LayerMask = ~0; //~0是Everthing
            PassNames = new string[] { "BasicsPass", "FurPass" };
        }
    }

    [System.Serializable]
    public class PassSettings
    {
        [Header("毛发设置")] [Tooltip("毛发层数")] [Range(1, 200)]
        public int FurLayerNum = 20;

        [Tooltip("渲染队列最小值")] [Range(1000, 5000)]   //Tooltip是鼠标放上去显示的名称
        public int QueueMin = 2000;
        
        [Tooltip("渲染队列最大值")][Range(1000, 5000)]
        public int QueueMax = 2000;

        [Space(10)] public RenderPassEvent PassEvent = RenderPassEvent.AfterRenderingSkybox;
        public FilterSettings filterSettings = new FilterSettings();
    }
    public PassSettings settings = new PassSettings();  //实例化就是显示在面板上
    
    
    
    
    class CustomRenderPass : ScriptableRenderPass
    {
        RenderQueueType renderQueueType;
        private FilteringSettings filter;
        public int PassLayerNum; //毛发层数
        List<ShaderTagId> m_ShaderTagIdList;
        public CustomRenderPass(PassSettings settings)
        {
            PassLayerNum = settings.FurLayerNum;  //外面传入赋值
            renderQueueType = settings.filterSettings.RenderQueueType;
            m_ShaderTagIdList = new List<ShaderTagId>();
            RenderQueueRange queue = new RenderQueueRange();   //渲染队列
            queue.lowerBound = settings.QueueMin;
            queue.upperBound = settings.QueueMax;
            string[] shaderTags = settings.filterSettings.PassNames;
            filter = new FilteringSettings(queue, settings.filterSettings.LayerMask);    
            if (shaderTags.Length > 0 && shaderTags != null)
            {
                foreach (var passName in shaderTags)
                {
                    m_ShaderTagIdList.Add(new ShaderTagId(passName));
                }
            }
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent) ? 
                SortingCriteria.CommonTransparent    //使用透明渲染排序
                :renderingData.cameraData.defaultOpaqueSortFlags;  //使用不透明排序标准
 
            DrawingSettings baseDrawingSettings, FurDrawingSettings;
            if (m_ShaderTagIdList.Count > 0)
            {
                baseDrawingSettings = CreateDrawingSettings(m_ShaderTagIdList[0], ref renderingData, sortingCriteria);
            }
            else return;

            if (m_ShaderTagIdList.Count > 1)
            {
                FurDrawingSettings = CreateDrawingSettings(m_ShaderTagIdList[1], ref renderingData, sortingCriteria);
            }
            else return;
            
            CommandBuffer cmd = CommandBufferPool.Get("Fur");
            cmd.Clear();
            cmd.SetGlobalFloat("_FUR_LAYER", 0);  //将毛发层数归0
            context.ExecuteCommandBuffer(cmd);
            context.DrawRenderers(renderingData.cullResults, ref baseDrawingSettings, ref filter); //绘制基础层

            for (int i = 0; i < PassLayerNum; i++)
            {
                cmd.Clear();
                cmd.SetGlobalFloat("_FUR_LAYER", i / (PassLayerNum - 1.0f));
                context.ExecuteCommandBuffer(cmd);
                context.DrawRenderers(renderingData.cullResults, ref FurDrawingSettings, ref filter);
            }
            CommandBufferPool.Release(cmd); //释放cmd
        }
        
    }

    CustomRenderPass m_ScriptablePass;

    
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(settings);
        m_ScriptablePass.renderPassEvent = settings.PassEvent;
    }

    
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


