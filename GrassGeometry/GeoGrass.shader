
// @Cyanilux
Shader "Unlit/GeoGrass" {
	Properties {
		_Color ("Colour", Color) = (0.2,0.8,0.5,1)
		_Color2 ("Colour2", Color) = (0.5,0.9,0.6,1)
		_Width ("Width", Float) = 0.1
		_Height ("Height", Float) = 0.8
		_RandomWidth ("Random Width", Float) = 0.1
		_RandomHeight ("Random Height", Float) = 0.1
		_WindStrength("Wind Strength", Float) = 0.1
		_TessellationUniform("Tessellation Uniform", Range(1, 10)) = 1
		// Note, _TessellationUniform can go higher, but the material preview window causes it to be very laggy.
		// I'd probably just use a manually subdivided plane mesh if higher tessellations are needed.
		// Also, tessellation is uniform across entire plane. Might be good to look into tessellation based on camera distance.

		[Toggle(DISTANCE_DETAIL)] _DistanceDetail ("Toggle Blade Detail based on Camera Distance", Float) = 0
	}
	SubShader {
		Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
		LOD 300

		Cull Off

		Pass {
			Name "ForwardLit"
			Tags {"LightMode" = "UniversalForward"}

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library, (apparently)
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x gles
			#pragma target 4.5
			
			#pragma vertex vert
			#pragma fragment frag

			#pragma require geometry
			#pragma geometry geom

			#pragma require tessellation
			#pragma hull hull
			#pragma domain domain

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _SHADOWS_SOFT

			#pragma shader_feature_local _ DISTANCE_DETAIL

			// Defines

			#define SHADERPASS_FORWARD
			#define BLADE_SEGMENTS 3

			// Includes

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

			#include "Grass.hlsl"
			#include "Tessellation.hlsl"
			
			// Fragment

			float4 frag (GeometryOutput input, bool isFrontFace : SV_IsFrontFace) : SV_Target {
				input.normalWS = isFrontFace ? input.normalWS : -input.normalWS;

				#if SHADOWS_SCREEN
					float4 clipPos = TransformWorldToHClip(input.positionWS);
					float4 shadowCoord = ComputeScreenPos(clipPos);
				#else
					float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
				#endif

				float3 ambient = SampleSH(input.normalWS);
				
				Light mainLight = GetMainLight(shadowCoord);
				float NdotL = saturate(saturate(dot(input.normalWS, mainLight.direction)) + 0.8);
				float up = saturate(dot(float3(0,1,0), mainLight.direction) + 0.5);

				float3 shading = NdotL * up * mainLight.shadowAttenuation * mainLight.color + ambient;
				
				return lerp(_Color, _Color2, input.uv.y) * float4(shading, 1);
			}

			ENDHLSL
		}
		
		// Used for rendering shadowmaps
		//UsePass "Universal Render Pipeline/Lit/ShadowCaster"

		Pass {
			Name "ShadowCaster"
			Tags {"LightMode" = "ShadowCaster"}

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library, (apparently)
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x gles
			#pragma target 4.5

			#pragma vertex vert
			#pragma fragment emptyFrag

			#pragma require geometry
			#pragma geometry geom

			#pragma require tessellation
			#pragma hull hull
			#pragma domain domain

			#define BLADE_SEGMENTS 3
			#define SHADERPASS_SHADOWCASTER

			#pragma shader_feature_local _ DISTANCE_DETAIL

			//#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
			
			#include "Grass.hlsl"
			#include "Tessellation.hlsl"

			half4 emptyFrag(GeometryOutput input) : SV_TARGET{
				return 0;
			}

			ENDHLSL
		}

		// Used for depth prepass
		// If shadows cascade are enabled we need to perform a depth prepass. 
		// We also need to use a depth prepass in some cases camera require depth texture
		// e.g, MSAA is enabled and we can't resolve with Texture2DMS
		//UsePass "Universal Render Pipeline/Lit/DepthOnly"

		// Note, can't UsePass + SRP Batcher due to UnityPerMaterial CBUFFER having incosistent size between subshaders..
		// Had to comment this out for now so it doesn't break SRP Batcher.
		
		// Instead will do this :
		Pass {
			Name "DepthOnly"
			Tags {"LightMode" = "DepthOnly"}

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library, (apparently)
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x gles
			#pragma target 4.5

			#pragma vertex vert
			#pragma fragment emptyFrag

			#pragma require geometry
			#pragma geometry geom

			#pragma require tessellation
			#pragma hull hull
			#pragma domain domain

			#define BLADE_SEGMENTS 3
			#define SHADERPASS_DEPTHONLY

			#pragma shader_feature_local _ DISTANCE_DETAIL

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			#include "Grass.hlsl"
			#include "Tessellation.hlsl"

			half4 emptyFrag(GeometryOutput input) : SV_TARGET{
				return 0;
			}

			ENDHLSL
		}

	}
}