using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using static PathTrace;
using static UnityEngine.GraphicsBuffer;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class PathTrace : MonoBehaviour
{
    [SerializeField] Shader rtShader;
    [SerializeField] Shader temporalShader;
    [SerializeField] Material rtMaterial;

    [SerializeField] private Color shadowColor = Color.black;
    [SerializeField] private Color GroundColor = Color.black;
    [SerializeField] private Color SkyColorHorizon = Color.black;
    [SerializeField] private Color SkyColorZenith = Color.black;
    [SerializeField] private float SunFocus = 1;
    [SerializeField] private float SunIntensity = 1;

    [SerializeField] private int RaysPerPixel = 1;
    [SerializeField] private int BouncesPerRay = 1;

    [SerializeField] private bool useInScene;
    [SerializeField] private bool updateSpheres;
    [SerializeField] private bool useTemporal;
    [SerializeField] private bool UseSkybox = true;

    ComputeBuffer sphereBuffer;

    Material temporalMaterials;

    RenderTexture resultTexture;

    int numRenderedFrames;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        bool isSceneCam = Camera.current.name == "SceneCamera";

        if (isSceneCam)
        {
            rtMaterial.SetColor("shadowColor", shadowColor);

            rtMaterial.SetFloat("RaysPerPixel", RaysPerPixel);
            rtMaterial.SetFloat("BouncesPerRay", BouncesPerRay);

            if (useInScene)
            {
                SetSpheres();
                updateCameraParameters(Camera.current);
                Graphics.Blit(null, destination, rtMaterial);
            }
            else
            {
                Graphics.Blit(source, destination);
            }
        }
        else
        {
            if (updateSpheres)
            {
                SetSpheres();
            }
            Temporal();
            updateCameraParameters(Camera.current);
            updateShader();

            ShaderHelper.CreateRenderTexture(ref resultTexture, Screen.width, Screen.height, FilterMode.Bilinear, ShaderHelper.RGBA_SFloat, "Result");
            RenderTexture prevFrameCopy = RenderTexture.GetTemporary(source.width, source.height, 0, ShaderHelper.RGBA_SFloat);
            Graphics.Blit(resultTexture, prevFrameCopy);

            if (useTemporal)
            {
                if (numRenderedFrames > 20)
                {
                    numRenderedFrames = 10;
                }
            }
            RenderTexture currentFrame = RenderTexture.GetTemporary(source.width, source.height, 0, ShaderHelper.RGBA_SFloat);
            Graphics.Blit(null, currentFrame, rtMaterial);

            temporalMaterials.SetInt("_Frame", numRenderedFrames);
            temporalMaterials.SetTexture("_PrevFrame", prevFrameCopy);
            Graphics.Blit(currentFrame, resultTexture, temporalMaterials);

            Graphics.Blit(resultTexture, destination);

            RenderTexture.ReleaseTemporary(currentFrame);
            RenderTexture.ReleaseTemporary(prevFrameCopy);
            RenderTexture.ReleaseTemporary(currentFrame);

            numRenderedFrames += 1;
        }
    }

    

    #region Structures
    //must match struct in shader
    [Serializable]
    public struct RayTracingMaterial
    {
        public Color colour;
        public Color emissionColor;
        public float emissionStrength;
        public float smoothness;
    }
    public struct Sphere
    {
        public Vector3 position;
        public float radius;
        public RayTracingMaterial material;
    }

    #endregion

    #region Constructing Varibles

    //find all the spheres in our scene
    [ContextMenu("Cache Objects")]
    void SetSpheres()
    {
        PathTracedObject[] sphereObjects = FindObjectsOfType<PathTracedObject>();
        Sphere[] spheres = new Sphere[sphereObjects.Length];

        for (int i = 0; i < sphereObjects.Length; i++)
        {
            spheres[i] = new Sphere()
            {
                position = sphereObjects[i].transform.position,
                radius = sphereObjects[i].transform.localScale.x * 0.5f,
                material = sphereObjects[i].material
            };
        }

        ShaderHelper.CreateStructuredBuffer(ref sphereBuffer, spheres);

        rtMaterial.SetBuffer("Spheres", sphereBuffer);
        rtMaterial.SetInt("NumSpheres", sphereObjects.Length);

    }

    void updateShader()
    {
        rtMaterial.SetColor("GroundColor", GroundColor);
        rtMaterial.SetColor("SkyColorHorizon", SkyColorHorizon);
        rtMaterial.SetColor("SkyColorZenith", SkyColorZenith);
        rtMaterial.SetColor("shadowColor", shadowColor);
        rtMaterial.SetFloat("RaysPerPixel", RaysPerPixel);
        rtMaterial.SetFloat("BouncesPerRay", BouncesPerRay);
        rtMaterial.SetFloat("Frame", numRenderedFrames);
        rtMaterial.SetFloat("SunFocus", SunFocus);
        rtMaterial.SetFloat("SunIntensity", SunIntensity);
        rtMaterial.SetFloat("useSkybox", Convert.ToSingle(UseSkybox));
    }
    void updateCameraParameters(Camera cam)
    {
        float planeHeight = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
        float planeWidth = planeHeight * cam.aspect;
        // Send data to shader     

        rtMaterial.SetVector("ViewParams", new Vector3(planeWidth, planeHeight, cam.nearClipPlane));
        rtMaterial.SetMatrix("CamLocalToWorldMatrix", cam.transform.localToWorldMatrix);
    }
    void Temporal()
    {
        ShaderHelper.InitMaterial(temporalShader, ref temporalMaterials);
    }

    #endregion
}
