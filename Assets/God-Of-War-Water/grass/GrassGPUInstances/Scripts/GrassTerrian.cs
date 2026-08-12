using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Random = UnityEngine.Random;


namespace URPLearn{

    [ExecuteInEditMode]
    public class GrassTerrian : MonoBehaviour
    {
        private void Update()
        {
            if (Input.GetMouseButton(0)) {
                Ray ray = mainCamera.ScreenPointToRay(Input.mousePosition);
                if (Physics.Raycast(ray, out RaycastHit hit, Mathf.Infinity, terrainLayer)) {
                    Vector2 uv = hit.textureCoord;
                    PaintBrush(uv);
                }
            }
        }
        

        private static HashSet<GrassTerrian> _actives = new HashSet<GrassTerrian>();

        public static IReadOnlyCollection<GrassTerrian> actives{
            get{
                return _actives;
            }
        }

        [SerializeField]                    //设置材质
        private Material _material;

        [SerializeField]                    //设置mesh
        private Vector2 _grassQuadSize = new Vector2(0.1f,0.6f);

        [SerializeField]                    //设置草的数量
        private int _grassCountPerMeter = 100;

        public Material material{                                      
            get{
                return _material;
            }
        }


        private int _seed;                                                  

        private ComputeBuffer _grassBuffer;                                 //computebuffer是什么 ComputeBuffer 是 Unity 引擎中用于在 GPU 和 CPU 之间传递数据的缓冲区。下面我们逐部分解析这段代码：
        
        private int _grassCount;
        
        public Texture2D brushTexture; // 笔刷纹理
    public int brushSize = 10; // 笔刷大小
    public float brushStrength = 1f; // 笔刷强度
    // Start is called before the first frame update
    
    public Camera mainCamera; // 主摄像机
    public LayerMask terrainLayer; // 地形层
    
    private Texture2D CreateBrushTexture() {
        var texture = new Texture2D(brushSize, brushSize, TextureFormat.RFloat, false);
        for (int x = 0; x < brushSize; x++) {
            for (int y = 0; y < brushSize; y++) {
                float distance = Vector2.Distance(new Vector2(x, y), new Vector2(brushSize / 2, brushSize / 2));
                float strength = Mathf.Clamp01(1 - distance / (brushSize / 2));
                texture.SetPixel(x, y, new Color(strength, 0, 0, 0));
            }
        }
        texture.Apply();
        return texture;
    }
    
    private void PaintBrush(Vector2 uv) {
        int x = (int)(uv.x * brushTexture.width);
        int y = (int)(uv.y * brushTexture.height);
        for (int i = -brushSize / 2; i <= brushSize / 2; i++) {
            for (int j = -brushSize / 2; j <= brushSize / 2; j++) {
                int px = x + i;
                int py = y + j;
                if (px >= 0 && px < brushTexture.width && py >= 0 && py < brushTexture.height) {
                    float strength = brushTexture.GetPixel(px, py).r;
                    brushTexture.SetPixel(px, py, new Color(strength + brushStrength, 0, 0, 0));
                }
            }
        }
        brushTexture.Apply();
    }
    
    private bool IsPositionInBrush(Vector3 position) {
        Vector2 uv = GetUVFromPosition(position);
        float strength = brushTexture.GetPixel((int)(uv.x * brushTexture.width), (int)(uv.y * brushTexture.height)).r;
        return strength > 0.5f;
    }

    private Vector2 GetUVFromPosition(Vector3 position) {
        // 将世界坐标转换为 UV 坐标
        var terrain = GetComponent<Terrain>();
        if (terrain != null) {
            Vector3 terrainSize = terrain.terrainData.size;
            return new Vector2(position.x / terrainSize.x, position.z / terrainSize.z);
        }
        return Vector2.zero;
    }

        private void Awake() {
             _seed = System.Guid.NewGuid().GetHashCode();  //初始化种子                    
        }


        public int grassCount{
            get{
                return _grassCount;
            }
        }
        
        
        
        public ComputeBuffer grassBuffer{
            get{
                if(_grassBuffer != null){
                    return _grassBuffer;
                }
                var filter = GetComponent<MeshFilter>();
                var terrianMesh = filter.sharedMesh;
                var matrix = transform.localToWorldMatrix;
                var grassIndex = 0;
                List<GrassInfo> grassInfos = new List<GrassInfo>();
                var maxGrassCount = 100000;
                Random.InitState(_seed);

                var indices = terrianMesh.triangles;
                var vertices = terrianMesh.vertices;

                for(var j = 0; j < indices.Length / 3; j ++){
                    var index1 = indices[j * 3];
                    var index2 = indices[j * 3 + 1];
                    var index3 = indices[j * 3 + 2];
                    var v1 = vertices[index1];
                    var v2 = vertices[index2];
                    var v3 = vertices[index3];

                    //面得到法向
                    var normal = GrassUtil.GetFaceNormal(v1,v2,v3);

                    //计算up到faceNormal的旋转四元数
                    var upToNormal = Quaternion.FromToRotation(Vector3.up,normal);              //没懂

                    //三角面积
                    var arena = GrassUtil.GetAreaOfTriangle(v1,v2,v3);

                    //计算在该三角面中，需要种植的数量
                    var countPerTriangle = Mathf.Max(1,_grassCountPerMeter * arena);

                    for(var i = 0; i < countPerTriangle; i ++){
                        
                        var positionInTerrian = GrassUtil.RandomPointInsideTriangle(v1,v2,v3);
                        float rot = Random.Range(0,180);
                        var localToTerrian = Matrix4x4.TRS(positionInTerrian,  upToNormal * Quaternion.Euler(0,rot,0) ,Vector3.one);

                        Vector2 texScale = Vector2.one;
                        Vector2 texOffset = Vector2.zero;
                        Vector4 texParams = new Vector4(texScale.x,texScale.y,texOffset.x,texOffset.y);
                        

                        var grassInfo = new GrassInfo(){
                            localToTerrian = localToTerrian,
                            texParams = texParams
                        };
                        grassInfos.Add(grassInfo);
                        grassIndex ++;
                        if(grassIndex >= maxGrassCount){
                            break;
                        }
                    }
                    if(grassIndex >= maxGrassCount){
                        break;
                    }
                }
               
                _grassCount = grassIndex;
                _grassBuffer = new ComputeBuffer(_grassCount,64 + 16);
                _grassBuffer.SetData(grassInfos);
                return _grassBuffer;
            }
        }

        private MaterialPropertyBlock _materialBlock;
        
        public void UpdateMaterialProperties(){
            materialPropertyBlock.SetMatrix(ShaderProperties.TerrianLocalToWorld,transform.localToWorldMatrix);
            materialPropertyBlock.SetBuffer(ShaderProperties.GrassInfos,grassBuffer);
            materialPropertyBlock.SetVector(ShaderProperties.GrassQuadSize,_grassQuadSize);
        }

        public MaterialPropertyBlock materialPropertyBlock{
            get{
                if(_materialBlock == null){
                    _materialBlock = new MaterialPropertyBlock();
                }
                return _materialBlock;
            }
        }

        [ContextMenu("ForceRebuildGrassInfoBuffer")]
        private void ForceUpdateGrassBuffer(){
            if(_grassBuffer != null){
                _grassBuffer.Dispose();
                _grassBuffer = null;
            }
            UpdateMaterialProperties();
        }

        void OnEnable(){
            _actives.Add(this);
        }

        void OnDisable(){
            _actives.Remove(this);
            if(_grassBuffer != null){
                _grassBuffer.Dispose();
                _grassBuffer = null;
            }
        }


        public struct GrassInfo{                    //???
            public Matrix4x4 localToTerrian;
            public Vector4 texParams;
        }


        private class ShaderProperties{                     //?

            public static readonly int TerrianLocalToWorld = Shader.PropertyToID("_TerrianLocalToWorld");
            public static readonly int GrassInfos = Shader.PropertyToID("_GrassInfos");
            public static readonly int GrassQuadSize = Shader.PropertyToID("_GrassQuadSize");

        }




    }
}
