using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ObjectMaskRenderFeature : ScriptableRendererFeature
{
    // 定义 RenderPass
    class ObjectMaskRenderPass : ScriptableRenderPass
    {
        private RTHandle maskTexture; // Mask 渲染目标
        private Material maskMaterial; // Mask 材质
        private FilteringSettings filteringSettings; // 过滤设置（渲染哪些物体）

        public ObjectMaskRenderPass(Material maskMaterial)
        {
            this.maskMaterial = maskMaterial;
            // 设置过滤条件：渲染 "Default" 层的不透明物体
            this.filteringSettings = new FilteringSettings(RenderQueueRange.opaque, LayerMask.GetMask("Mask"));
        }

        // 初始化 RTHandle
        public void Setup(RTHandle maskTexture)
        {
            this.maskTexture = maskTexture;
        }

        // 在渲染之前配置渲染目标
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            // 设置渲染目标
            ConfigureTarget(maskTexture);
            // 清除渲染目标为黑色
            ConfigureClear(ClearFlag.Color, Color.black);
        }

        // 执行渲染
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // 获取命令缓冲区
            CommandBuffer cmd = CommandBufferPool.Get("ObjectMaskPass");

            // 将 _ObjectMaskTexture 设置为全局纹理
            cmd.SetGlobalTexture("_ObjectMaskTexture", maskTexture.nameID);

            // 创建绘制设置
            var drawSettings = CreateDrawingSettings(new ShaderTagId("UniversalForward"), ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
            drawSettings.overrideMaterial = maskMaterial; // 使用 Mask 材质
            drawSettings.overrideMaterialPassIndex = 0;   // 使用材质的第一个 Pass

            // 绘制物体
            context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);

            // 提交命令缓冲区
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        // 清理临时渲染目标
        public override void FrameCleanup(CommandBuffer cmd)
        {
            // 不需要手动释放 RTHandle，URP 会自动管理
        }
    }

    // RenderFeature 的设置
    [System.Serializable]
    public class ObjectMaskSettings
    {
        public Material maskMaterial; // Mask 材质
    }

    public ObjectMaskSettings settings = new ObjectMaskSettings();
    private ObjectMaskRenderPass maskRenderPass;
    private RTHandle maskTexture; // RTHandle 用于管理渲染目标

    // 初始化 RenderFeature
    public override void Create()
    {
        maskRenderPass = new ObjectMaskRenderPass(settings.maskMaterial)
        {
            renderPassEvent = RenderPassEvent.AfterRenderingOpaques // 在渲染不透明物体之后执行
        };

        // 创建 RenderTextureDescriptor
        RenderTextureDescriptor maskDescriptor = new RenderTextureDescriptor(
            width: 512, // 纹理宽度
            height: 512, // 纹理高度
            colorFormat: GraphicsFormat.R8_UNorm, // 使用 R8 格式存储 Mask
            depthBufferBits: 0 // 不需要深度缓冲区
        );

        // 使用 RTHandles.Alloc 创建 RTHandle
        maskTexture = RTHandles.Alloc(
            width: maskDescriptor.width,
            height: maskDescriptor.height,
            colorFormat: maskDescriptor.graphicsFormat,
            filterMode: FilterMode.Bilinear, // 纹理过滤模式
            wrapMode: TextureWrapMode.Clamp, // 纹理环绕模式
            dimension: TextureDimension.Tex2D, // 纹理维度
            name: "_ObjectMaskTexture" // 纹理名称
        );
    }

    // 将 RenderPass 添加到渲染管线
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.maskMaterial == null)
        {
            Debug.LogWarning("Mask Material is missing.");
            return;
        }

        // 设置 RTHandle
        maskRenderPass.Setup(maskTexture);
        renderer.EnqueuePass(maskRenderPass); // 将 Pass 加入渲染队列
    }

    // 释放 RTHandle
    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            maskTexture?.Release(); // 释放 RTHandle
        }
    }
}