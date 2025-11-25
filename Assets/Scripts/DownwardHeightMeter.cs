using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;

public class DownwardHeightMeter : MonoBehaviour
{
    [Header("Refs")]
    [SerializeField] private ARRaycastManager raycastManager;   // XR Origin に付いている
    [SerializeField] private ARPlaneManager planeManager;       // ★ 追加: XR Origin の ARPlaneManager
    [SerializeField] private Camera arCamera;                   // XR Origin の子 "Main Camera"
    [SerializeField] private TextMeshProUGUI resultLabel;       // Canvas の Text (TMP)

    [Header("Settings")]
    [Tooltip("端末カメラ位置の補正（m）。端末のカメラが上端にあるぶんだけ差し引く。")]
    public float cameraOffsetMeters = 0.0f;   // まずは 0 で様子を見るのがおすすめ
    [Tooltip("目標高さ（m）。例: テニスネット3ft = 約0.914m。")]
    public float targetMeters = 0.914f;
    [Tooltip("移動平均に使うサンプル数。値が大きいほど表示がなめらかになる。")]
    public int smoothingWindow = 5;

    // PlaneWithinPolygon + PlaneEstimated を対象にする
    private const TrackableType RaycastTypes =
        TrackableType.PlaneWithinPolygon | TrackableType.PlaneEstimated;

    // 毎フレーム new しないように共有バッファを持つ
    private static readonly List<ARRaycastHit> hits = new();
    private readonly List<float> recent = new();

    // 「高さに使っている平面」の ID（今表示したい Plane）
    private TrackableId? currentPlaneId = null;

    void Update()
    {
        if (raycastManager == null || arCamera == null || resultLabel == null) return;

        // 画面中央から床に向けてレイキャスト
        Vector2 center = new(Screen.width * 0.5f, Screen.height * 0.5f);

        if (raycastManager.Raycast(center, hits, RaycastTypes))
        {
            var hit = hits[0];

            bool isConfirmedPlane =
                (hit.hitType & TrackableType.PlaneWithinPolygon) != 0;
            bool isEstimatedPlane =
                !isConfirmedPlane && (hit.hitType & TrackableType.PlaneEstimated) != 0;

            Vector3 camPos = arCamera.transform.position;
            Vector3 hitPos = hit.pose.position;

            // 垂直方向の高さ（Y座標の差）を使う
            float rawHeight = Mathf.Abs(camPos.y - hitPos.y);

            // 端末カメラのオフセットを補正して、0未満にならないように
            float height = Mathf.Max(0f, rawHeight - cameraOffsetMeters);

            // ★ 確定した平面が取れたときだけ、その Plane だけ表示する
            if (isConfirmedPlane && planeManager != null)
            {
                ShowOnlyPlane(hit.trackableId);
            }

            if (isConfirmedPlane)
            {
                // ★ 確定した平面のときだけスムージングして本気の値にする
                Push(height);
                float smoothed = Avg();

                // 目標との差を cm で
                float deltaCm = (smoothed - targetMeters) * 100f;
                string sign = deltaCm >= 0 ? "+" : "−";

                // 目標との差で色を変える
                string color =
                    Mathf.Abs(deltaCm) <= 1f ? "#39D353" :   // ±1cm 以内 → 緑
                    Mathf.Abs(deltaCm) <= 3f ? "#F1E05A" :   // ±3cm 以内 → 黄
                    "#FF4D4F";                               // それ以上 → 赤

                resultLabel.text =
                    $"<color={color}>高さ {smoothed:F3} m（確定）\n" +
                    $"目標との差 {sign}{Mathf.Abs(deltaCm):F1} cm</color>";
            }
            else if (isEstimatedPlane)
            {
                // ★ 推定Planeの間はそのままの値＋「推定中」表示
                resultLabel.text =
                    $"高さ {height:F3} m（推定中…）";
                // 推定中の値はスムージングには入れない（確定値をきれいに保つため）
            }
        }
        else
        {
            currentPlaneId = null; // 平面が取れなかったのでリセット
            resultLabel.text =
                "床を検出しています… \n端末をゆっくり動かして床をスキャンしてください。";
        }
    }

    /// <summary>
    /// 測定に使っている trackableId の平面「だけ」表示し、それ以外を非表示にする
    /// </summary>
    private void ShowOnlyPlane(TrackableId id)
    {
        if (planeManager == null) return;

        // 同じ平面なら何もしない（毎フレーム全部いじるのを避ける）
        if (currentPlaneId.HasValue && currentPlaneId.Value == id) return;
        currentPlaneId = id;

        foreach (var plane in planeManager.trackables)
        {
            bool active = plane.trackableId == id;
            plane.gameObject.SetActive(active);
        }
    }

    private void Push(float v)
    {
        recent.Add(v);
        int max = Mathf.Max(1, smoothingWindow);
        if (recent.Count > max)
        {
            recent.RemoveAt(0);
        }
    }

    private float Avg()
    {
        if (recent.Count == 0) return 0f;
        float sum = 0f;
        for (int i = 0; i < recent.Count; i++)
        {
            sum += recent[i];
        }
        return sum / recent.Count;
    }
}
