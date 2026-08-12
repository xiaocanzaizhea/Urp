using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CelHairShadow_Stencil : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        public Color hairShadowColor;
        [Range(0, 0.1f)]
        public float offset = 0.02f;
        [Range(0, 255)]
        public int stencilReference = 1;
        public CompareFunction stencilComparison;

        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingTransparents;
        public LayerMask hairLayer;
        [Range(1000, 5000)]
        public int queueMin = 2000;

        [Range(1000, 5000)]
        public int queueMax = 3000;
        public Material material;

    }
    public Setting setting = new Setting();
    class CustomRenderPass : ScriptableRenderPass
    {
        public ShaderTagId shaderTag = new ShaderTagId("UniversalForward");
        public Setting setting;

        FilteringSettings filtering;
        public CustomRenderPass(Setting setting)
        {
            this.setting = setting;

            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(setting.queueMax, setting.queueMin);
            queue.upperBound = Mathf.Max(setting.queueMax, setting.queueMin);
            filtering = new FilteringSettings(queue, setting.hairLayer);
        }
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            setting.material.SetColor("_Color", setting.hairShadowColor);
            setting.material.SetInt("_StencilRef", setting.stencilReference);
            setting.material.SetInt("_StencilComp", (int)setting.stencilComparison);
            setting.material.SetFloat("_Offset", setting.offset);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var draw = CreateDrawingSettings(shaderTag, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
            draw.overrideMaterial = setting.material;
            draw.overrideMaterialPassIndex = 0;

            //获取主光源方向，并转换到相机空间
            var visibleLight = renderingData.cullResults.visibleLights[0];
            Vector2 lightDirSS = renderingData.cameraData.camera.worldToCameraMatrix * (visibleLight.localToWorldMatrix.GetColumn(2));
            setting.material.SetVector("_LightDirSS", lightDirSS);

            CommandBuffer cmd = CommandBufferPool.Get("DrawHairShadow");
            context.ExecuteCommandBuffer(cmd);
            context.DrawRenderers(renderingData.cullResults, ref draw, ref filtering);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {

        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(setting);

        m_ScriptablePass.renderPassEvent = setting.passEvent;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (setting.material != null)
            renderer.EnqueuePass(m_ScriptablePass);
    }
}