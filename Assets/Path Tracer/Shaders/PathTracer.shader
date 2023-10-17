Shader "Unlit/PathTracer"
{
	Properties
	{
	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}

			//a ray.
			struct Ray {
				float3 origin;
				float3 dir;
			};

			//material struct // must match the struct in manager script
			struct PathTracingMaterial
			{
				float4 color;
				float4 emissionColor;
				float emissionStrength;
				float smoothness;
			};

			//our hit struct // fill this struct when we hit a object
			struct HitInfo {
				bool didHit;
				float dst;
				float3 hitPoint;
				float3 normal;
				PathTracingMaterial material;
			};


			//sphere object // contains object information to find objects to hit
			struct Sphere {
				float3 position;
				float radius;
				PathTracingMaterial material;
			};

			//Path Tracer
			//holds are camera width & height as well as the near clip
			float3 ViewParams;

			//cam matrix
			float4x4 CamLocalToWorldMatrix;

			//How many rays are we gonna shoot per pixel
			float RaysPerPixel;
			//How many bounces are rays allowed to have
			float BouncesPerRay;

			//a boolean for whether or not we want to use a skybox in our scene
			float useSkybox;

			//sets our shadow color (sets the dark pixels to this color)
			float4 shadowColor;

			//Frame number to offset the random numbers for random directions each frame
			float Frame;

			//a buffer of all the spheres in our scene, set by the manager script
			StructuredBuffer<Sphere> Spheres;
			//amount of spheres in the buffer
			int NumSpheres;

			//skybox values
			float4 GroundColor;
			float4 SkyColorHorizon;
			float4 SkyColorZenith;
			float SunFocus;
			float SunIntensity;

			//gets environment lighting if ray doesn't hit anything
			float3 GetEnvironmentLight(Ray ray)
			{
				if (useSkybox)
				{
					float skyGradientT = pow(smoothstep(0, .4f, ray.dir.y), .35);
					float groundTosky = smoothstep(-0.01, 0, ray.dir.y);
					float3 skyGradient = lerp(SkyColorHorizon, SkyColorZenith, skyGradientT);

					float sun = pow(max(0, dot(ray.dir, _WorldSpaceLightPos0.xyz)), SunFocus) * SunIntensity;
					float3 composite = lerp(GroundColor, skyGradient, skyGradientT) + sun * (groundTosky >= 1);
					return composite;
				}

				return 0;
			}

			//sets a hit info struct if we the ray we shoot hits a sphere
			//quadratic formula
			HitInfo RaySphere(Ray ray, float3 sphereCentre, float sphereRadius)
			{
				HitInfo hitInfo = (HitInfo)0;

				//gets our ray origin at the pixel
				float3 offsetRayOrigin = ray.origin - sphereCentre;

			    
				float a = dot(ray.dir, ray.dir);
				float b = 2 * dot(offsetRayOrigin, ray.dir);
				float c = dot(offsetRayOrigin, offsetRayOrigin) - sphereRadius * sphereRadius;

				//quadratic forumla
				float discriminant = b * b - 4 * a * c;

				//means we have more than 1 solution
				if (discriminant >= 0)
				{
					float dst = (-b - sqrt(discriminant)) / (2 * a);

					if (dst >= 0)
					{
						hitInfo.didHit = true;
						hitInfo.dst = dst;
						hitInfo.hitPoint = ray.origin + ray.dir * dst;
						hitInfo.normal = normalize(hitInfo.hitPoint - sphereCentre);
					}
				}
				return hitInfo;
			}

			//this is what we'll actually call if we want to check our ray
			HitInfo CalculateRayCollision(Ray ray)
			{
				//basic closest algorithm

				HitInfo closestHit = (HitInfo)0;

				//set distance to infinite
				closestHit.dst = 1.#INF;

				//loop through the objects in our scene
				for (int i = 0; i < NumSpheres; i++)
				{
					Sphere sphere = Spheres[i];

					//hit the sphere with our ray
					HitInfo hitInfo = RaySphere(ray, sphere.position, sphere.radius);

					if (hitInfo.didHit && hitInfo.dst < closestHit.dst)
					{
						closestHit = hitInfo;
						closestHit.material = sphere.material;
					}
				}

				return closestHit;
			}


			//could use my own random function but this is way better + 10x more tested than anything i could come up with
			float randomValue(inout uint state)
			{
				state = state * 747796405 + 2891336453;
				uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
				result = (result >> 22) ^ result;
				return result / 4294967295.0;
			}

			//making random values in a normal distribution (not mine)
			float randomValueNormal(inout uint state)
			{
				float theta = 2 * 3.1415926 * randomValue(state);
				float rtho = sqrt(-2 * log(randomValue(state)));
				return rtho * cos(theta);
			}

			//one of the ways to do this
			float3 randomDirection(inout uint state)
			{
				float x = randomValueNormal(state);
				float y = randomValueNormal(state);
				float z = randomValueNormal(state);

				return normalize(float3(x, y, z));
			}		

			//our main function of the path tracer
			//this takes the ray we shoot, a seed for are random number generator, and returns the pixel color.
			//rng state is used for a random direction after the ray bounces
			//light does not need to be modified, we average it for smoother noise
			float3 Trace(Ray ray, inout uint rngState)
			{
				float3 incomingLight = 0;
				float3 rayColor = 1;

				for (int i = 0; i <= BouncesPerRay; i++)
				{
					HitInfo hitInfo = CalculateRayCollision(ray);

					if (hitInfo.didHit)
					{
						ray.origin = hitInfo.hitPoint;
						float3 diffuseDir = normalize(hitInfo.normal + randomDirection(rngState));
						float3 specularDir = reflect(ray.dir, hitInfo.normal);

						ray.dir = lerp(diffuseDir, specularDir, hitInfo.material.smoothness);

						PathTracingMaterial material = hitInfo.material;

						float3 emittedLight = material.emissionColor * material.emissionStrength;
						incomingLight += emittedLight * rayColor ;
						rayColor *= material.color;

						float p = max(rayColor.r, max(rayColor.g, rayColor.b));
						if (randomValue(rngState) >= p) {
							break;
						}
						rayColor *= 1.0f / p;					
					}
					else
					{
						incomingLight += GetEnvironmentLight(ray) * rayColor;
						break;
					}
				}

				return incomingLight;
			}


			//ran for each pixel
			fixed4 frag(v2f i) : SV_Target
			{
			   //setting the seed of our rng
			   uint2 numPixels = _ScreenParams.xy;
			   uint2 pixelCoord = i.uv * numPixels;
			   uint pixelIndex = pixelCoord.y * numPixels.x + pixelCoord.x;
			   uint rngState = pixelIndex + Frame * 719393;

			   //viewpoint of the pixel
			   float3 viewPointLocal = float3(i.uv - 0.5f, 1) * ViewParams;
			   float3 viewPoint = mul(CamLocalToWorldMatrix, float4(viewPointLocal, 1));

			   //setting up our ray using the viewpoint we just calculated
			   Ray ray;
			   ray.origin = _WorldSpaceCameraPos;
			   ray.dir = normalize(viewPoint - ray.origin);

			   //going to average the light we get from the amount of samples we set per pixel
			   float3 totalLight = 0;
			   for (int raysPerPix = 0; raysPerPix < RaysPerPixel; raysPerPix++)
			   {
				   totalLight += Trace(ray, rngState);
			   }

			   //getting the average
			   float3 pixelCol = totalLight / RaysPerPixel;
		
			   //setting our shadow color // little jank ill admit
			   if (pixelCol.x + pixelCol.y + pixelCol.z < 0.1)
			   {
				   pixelCol = shadowColor / 10;
			   }

			   //setting the pixel
			   return float4(pixelCol, 1);
			}
			ENDCG
		}
	}
}
