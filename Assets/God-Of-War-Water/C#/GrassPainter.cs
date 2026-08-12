using System.Collections.Generic;
using UnityEngine;
// 定义草信息结构体
public struct GrassInfo
{
    public Matrix4x4 localToTerrian;
    public Vector4 texParams;
}
public class GrassPainter : MonoBehaviour
{
    // 草的计算缓冲区
    private ComputeBuffer _grassBuffer;
    // 实际生成的草的数量
    private int _grassCount;
    // 每平方米草的数量
    private int _grassCountPerMeter = 10; 
    // 随机种子
    private int _seed = 123; 
    // 最大草数量
    private int maxGrassCount = 10000; 
    // 笔刷大小
    public float brushSize = 5f;
    // 笔刷是否为添加草模式
    public bool isAddingGrass = true;
    // 存储草状态的二维数组
    private bool[,] grassState;
    // 草缓冲区属性
    public ComputeBuffer grassBuffer
    {
        get
        {
            if (_grassBuffer != null)
            {
                return _grassBuffer;
            }
            var filter = GetComponent<MeshFilter>();
            var terrianMesh = filter.sharedMesh;
            var matrix = transform.localToWorldMatrix;
            var grassIndex = 0;
            List<GrassInfo> grassInfos = new List<GrassInfo>();
            Random.InitState(_seed);
            var indices = terrianMesh.triangles;
            var vertices = terrianMesh.vertices;
            // 初始化草状态数组
            grassState = new bool[terrianMesh.vertices.Length, terrianMesh.vertices.Length];
            for (var j = 0; j < indices.Length / 3; j++)
            {
                var index1 = indices[j * 3];
                var index2 = indices[j * 3 + 1];
                var index3 = indices[j * 3 + 2];
                var v1 = vertices[index1];
                var v2 = vertices[index2];
                var v3 = vertices[index3];
                // 面得到法向
                var normal = GetFaceNormal(v1, v2, v3);
                // 计算up到faceNormal的旋转四元数
                var upToNormal = Quaternion.FromToRotation(Vector3.up, normal);
                // 三角面积
                var arena = GetAreaOfTriangle(v1, v2, v3);
                // 计算在该三角面中，需要种植的数量
                var countPerTriangle = Mathf.Max(1, _grassCountPerMeter * arena);
                for (var i = 0; i < countPerTriangle; i++)
                {
                    var positionInTerrian = RandomPointInsideTriangle(v1, v2, v3);
                    float rot = Random.Range(0, 180);
                    var localToTerrian = Matrix4x4.TRS(positionInTerrian, upToNormal * Quaternion.Euler(0, rot, 0), Vector3.one);
                    Vector2 texScale = Vector2.one;
                    Vector2 texOffset = Vector2.zero;
                    Vector4 texParams = new Vector4(texScale.x, texScale.y, texOffset.x, texOffset.y);
                    var grassInfo = new GrassInfo()
                    {
                        localToTerrian = localToTerrian,
                        texParams = texParams
                    };
                    // 检查草状态，如果该位置允许生成草则添加
                    if (ShouldGenerateGrass(positionInTerrian))
                    {
                        grassInfos.Add(grassInfo);
                        grassIndex++;
                    }
                    if (grassIndex >= maxGrassCount)
                    {
                        break;
                    }
                }
                if (grassIndex >= maxGrassCount)
                {
                    break;
                }
            }
            _grassCount = grassIndex;
            _grassBuffer = new ComputeBuffer(_grassCount, 64 + 16);
            _grassBuffer.SetData(grassInfos);
            return _grassBuffer;
        }
    }
    void Update()
    {
        // 处理鼠标左键点击
        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            if (Physics.Raycast(ray, out hit))
            {
                // 更新草状态
                UpdateGrassState(hit.point);
                // 重新生成草
                RegenerateGrass();
            }
        }
    }
    // 更新草状态
    void UpdateGrassState(Vector3 position)
    {
        var filter = GetComponent<MeshFilter>();
        var vertices = filter.sharedMesh.vertices;
        for (int i = 0; i < vertices.Length; i++)
        {
            var vertex = vertices[i];
            float distance = Vector3.Distance(vertex, position);
            if (distance < brushSize)
            {
                grassState[i, i] = isAddingGrass;
            }
        }
    }
    // 重新生成草
    void RegenerateGrass()
    {
        if (_grassBuffer != null)
        {
            _grassBuffer.Release();
            _grassBuffer = null;
        }
        // 重新获取草缓冲区，触发重新生成
        var buffer = grassBuffer;
    }
    // 判断是否应该生成草
    bool ShouldGenerateGrass(Vector3 position)
    {
        var filter = GetComponent<MeshFilter>();
        var vertices = filter.sharedMesh.vertices;
        for (int i = 0; i < vertices.Length; i++)
        {
            var vertex = vertices[i];
            if (Vector3.Distance(vertex, position) < 0.1f)
            {
                return grassState[i, i];
            }
        }
        return false;
    }
    // 计算三角形法向量
    Vector3 GetFaceNormal(Vector3 v1, Vector3 v2, Vector3 v3)
    {
        Vector3 edge1 = v2 - v1;
        Vector3 edge2 = v3 - v1;
        return Vector3.Cross(edge1, edge2).normalized;
    }
    // 计算三角形面积
    float GetAreaOfTriangle(Vector3 v1, Vector3 v2, Vector3 v3)
    {
        Vector3 edge1 = v2 - v1;
        Vector3 edge2 = v3 - v1;
        return 0.5f * Vector3.Cross(edge1, edge2).magnitude;
    }
    // 在三角形内随机生成点
    Vector3 RandomPointInsideTriangle(Vector3 v1, Vector3 v2, Vector3 v3)
    {
        float r1 = Random.value;
        float r2 = Random.value;
        if (r1 + r2 > 1)
        {
            r1 = 1 - r1;
            r2 = 1 - r2;
        }
        return v1 + r1 * (v2 - v1) + r2 * (v3 - v1);
    }
}