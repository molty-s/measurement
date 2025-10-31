using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;

public class DownwardHeightMeter : MonoBehaviour
{
    [Header("Refs")]
    public ARRaycastManager raycastManager;   // XR Originに付ける
    public Camera arCamera;                   // XR Origin の子 "AR Camera"
    public TextMeshProUGUI resultLabel;       // Canvas の Text (TMP)

    [Header("Settings")]
    public float cameraOffsetMeters = 0.018f; // 端末カメラ位置の補正(例:1.8cm)
    public float targetMeters = 0.914f;       // 3ft = 0.914m
    public int smoothingWindow = 5;

    private readonly List<float> recent = new();

    void Update()
    {
        if (raycastManager == null || arCamera == null || resultLabel == null) return;

        // 画面中央からレイキャスト（床に向けて端末を下向きに）
        var center = new Vector2(Screen.width * 0.5f, Screen.height * 0.5f);
        var hits = new List<ARRaycastHit>();
        if (raycastManager.Raycast(center, hits, TrackableType.PlaneWithinPolygon))
        {
            var hit = hits[0];
            Vector3 cam = arCamera.transform.position;
            Vector3 p = hit.pose.position;

            float raw = Vector3.Distance(cam, p);
            float height = Mathf.Max(0, raw - cameraOffsetMeters);

            Push(height);
            float smoothed = Avg();

            float deltaCm = (smoothed - targetMeters) * 100f;
            string sign = deltaCm >= 0 ? "+" : "−";
            string color =
                Mathf.Abs(deltaCm) <= 1f ? "#39D353" :
                Mathf.Abs(deltaCm) <= 3f ? "#F1E05A" : "#FF4D4F";

            resultLabel.text = $"<color={color}>高さ {smoothed:F3} m（{sign}{Mathf.Abs(deltaCm):F1} cm）</color>";
        }
        else
        {
            resultLabel.text = "床が認識できません。明るくして床をスキャン（A4用紙も有効）。";
        }
    }

    private void Push(float v)
    {
        recent.Add(v);
        if (recent.Count > Mathf.Max(1, smoothingWindow)) recent.RemoveAt(0);
    }
    private float Avg()
    {
        if (recent.Count == 0) return 0;
        float s = 0; foreach (var v in recent) s += v; return s / recent.Count;
    }
}
