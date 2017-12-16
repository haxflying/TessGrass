Shader "Unlit/tesselation_practice_01"
{
	Properties
	{
		[Header(Tessellation)]
		_MainTex ("Texture", 2D) = "white" {}
		_DisplacementMap("DisplacementMap", 2D) = "black" {}
		_Displacement("Displacement",Range(0,5)) = 1
		_TessellationUniform("TessllationUniform",Range(1,64)) = 1
		[Space(20)]
		[Header(Distance Division)]
		[Toggle(DISTANCE_DEVISION)]_DistanceDivision("Use Distance Division", Float) = 0
		_MinTessDistance("Min Tess Distance", Float) = 5
		_MaxTessDistance("Max Tess Distance", Float) = 25	
		[Space(20)]
		[Header(Grass Color)]
		_GrassColor ("Grass Base Color", Color) = (1,1,1,1)
		_GrassDistribution("Grass Color Distribution", 2D) = "white" {}
		_DistributionScale("Distribution Force", Range(0,1)) = 0.5
		[Space(20)]
		[Header(Grass Properties)]
		_NoiseTex("Base", 2D) = "white" {}
		_Length("Grass Length", Range(0.1,1.5)) = 1.0
		_Gravity("Gravity", Range(0.0,1.0)) = 0.3
		_Width("Grass Width", Range(0.01,0.4)) = 0.1	
		_WindDirection("Wind Direction", Vector) = (1,0,0,1)
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase"}
		LOD 100

		Pass
		{
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma hull HullProgram
			#pragma domain DomainProgram
			#pragma geometry GeometryProgram
			#pragma target 4.6
			#include "UnityCG.cginc"
			#include "Tessellation.cginc"

			#pragma  multi_compile __ DISTANCE_DEVISION
			//same as #pragma  shader_feature DISTANCE_DEVISION

			#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
			patch[0].fieldName * barycentricCoordinates.x + \
			patch[1].fieldName * barycentricCoordinates.y + \
			patch[2].fieldName * barycentricCoordinates.z;

			struct appdata{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct VertexData
			{
				float4 vertex : TEXCOORD0;
				float2 uv : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				float3 normal : TEXCOORD3;
			};

			struct gsInput
			{
				float4 pos : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float2 uv : TEXCOORD2;				
			};

			struct g2f
			{
				float3 normal : TEXCOORD0;
				float3 color : TEXCOORD1;
				float4 vertex : SV_POSITION;
			};

			struct TessellationFactors{
				float edge[3] : SV_TessFactor;
				float inside : SV_InsideTessFactor;
			};

			/***********var difinition*************/
			sampler2D _MainTex,_DisplacementMap, _GrassDistribution;
			float4 _MainTex_ST;
			float _TessellationUniform;
			float _Displacement;
			float _MinTessDistance, _MaxTessDistance;
			float _Length;
			float _Width;
			float _Gravity;
			float4 _WindDirection;
			float _DistributionScale;

			sampler2D _NoiseTex;
			float4 _NoiseTex_ST;
			float4 _GrassDistribution_ST;
			fixed4 _GrassColor;
			fixed4 _LightColor0;
			/**************************************/

			VertexData vert(appdata v)
			{
				VertexData data;
				data.vertex = v.vertex;
				data.uv = v.uv;
				data.normal = v.normal;
				data.worldPos = mul(unity_ObjectToWorld, v.vertex);
				return data;
			}			

			float4 tessDistance (VertexData v0, VertexData v1, VertexData v2) {
	            float minDist = _MinTessDistance;
	            float maxDist = _MaxTessDistance;
	            return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, minDist, maxDist, _TessellationUniform);
	        }

			TessellationFactors ConstantFunction(InputPatch<VertexData, 3> patch)
			{
				TessellationFactors f;	
				float4 tf = _TessellationUniform;
				#if DISTANCE_DEVISION
				//根据顶点与相机距离做不同细分	
				/*
				float l = length(patch[0].worldPos - _WorldSpaceCameraPos.xyz);
				l = max(1,l);		
				_TessellationUniform = max(1,_TessellationUniform/l);
				*/
				tf = tessDistance(patch[0],patch[1],patch[1]);
				#endif
				f.edge[0] = tf.x;
				f.edge[1] = tf.y;
				f.edge[2] = tf.z;
				f.inside = tf.w;
				return f;
			}

			[UNITY_domain("tri")] //告诉GPU要处理三角形
			[UNITY_outputcontrolpoints(3)] //告诉GPU每个patch三个顶点
			[UNITY_outputtopology("triangle_cw")] //告诉GPU 新创建三角形以顶点顺时针为正面
			[UNITY_partitioning("fractional_even")] //定义GPU细分patch的方法 : integer, pow2, fractional_even
			[UNITY_patchconstantfunc("ConstantFunction")] //定义每个patch细分数量的方法函数
			VertexData HullProgram(InputPatch<VertexData, 3> patch, uint id: SV_OutputControlPointID)
			{
				return patch[id];
			}

			gsInput TessVert (VertexData v)
			{
				gsInput o;
				o.pos = mul(unity_ObjectToWorld, v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.normal = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			[UNITY_domain("tri")] //告诉GPU要处理三角形
			gsInput DomainProgram(TessellationFactors factors, OutputPatch<VertexData, 3> patch, 
				float3 barycentricCoordinates : SV_DomainLocation)
			{
				VertexData data;
				MY_DOMAIN_PROGRAM_INTERPOLATE(vertex);
				MY_DOMAIN_PROGRAM_INTERPOLATE(uv);
				MY_DOMAIN_PROGRAM_INTERPOLATE(normal);
				float height = tex2Dlod(_DisplacementMap, float4(data.uv,0,0)).r * _Displacement;
				data.vertex += float4(0,1,0,0) * height;
				return TessVert(data);
			}

			[maxvertexcount(36)]
			void GeometryProgram(triangle gsInput p[3], inout TriangleStream<g2f> triStream)
			{
				g2f o;					
				
				float step = 6;

				float distance = max(1,length(p[0].pos - _WorldSpaceCameraPos.xyz) / _MinTessDistance);
				step = floor(step / distance);

				float length = _Length;
				float g = _Gravity;
				float w = _Width;
				float4 e1 = normalize(p[1].pos - p[0].pos);	
				float4 e2 = normalize(p[2].pos - p[0].pos);
				float4 normal = float4(normalize(cross(e1,e2)),0.0);				
				float4 tang = float4(normalize(p[2].pos-p[1].pos).xyz,0.0);
				float4 c = fixed4((p[0].pos.xyz + p[1].pos.xyz + p[2].pos.xyz)/3.0,1.0);

				fixed4 color = tex2Dlod(_GrassDistribution, c.xzyw * 0.1 * float4(_GrassDistribution_ST.xy,0,0) + float4(_GrassDistribution_ST.zw,0,0));
				//_NoiseTex_ST.z += sin(0.02*_Time.y);
				//float4 noise = tex2Dlod(_NoiseTex, float4(p[0].pos.xz * _NoiseTex_ST.xy + _NoiseTex_ST.zw,0,0));
				float4 noise = tex2Dlod(_NoiseTex, float4((((p[0].uv + sin(0.02*_Time.y))* _NoiseTex_ST.xy) + _NoiseTex_ST.zw)  * _WindDirection.xy * _WindDirection.w, 0, 0));

				length = length * noise.r;
				normal = normalize(float4((normal+(noise*2-1)).xyz,0.0));

				tang.xz += (2 *noise.rg - float2(1,1));

				float3 nor = 0;
				for(float i = 0; i < step; i++)
				{
					
					float t0 = i/step;
					float t1 = (i+1)/step;					
					float t2 = (i+2)/step;
					float4 p0 = normalize(normal - float4(0,length*t0,0,0)*g*t0)*(length*t0);
					float4 p1 = normalize(normal - float4(0,length*t1,0,0)*g*t1)*(length*t1);
					float4 p2 = normalize(normal - float4(0,length*t2,0,0)*g*t2)*(length*t2);

					float4 w0 = tang*lerp(w, 0,t0);
					float4 w1 = tang*lerp(w, 0,t1);

					//normal for each vertex
					nor =normalize(cross(w0, p1-p0).xyz);

					//f1
					o.vertex = mul(UNITY_MATRIX_VP,c+p0-w0);
					o.normal = nor;
					o.color = color;
					triStream.Append(o);

					o.vertex = mul(UNITY_MATRIX_VP,c+p0+w0);
					o.normal = nor;
					o.color = color;
					triStream.Append(o);

					o.vertex = mul(UNITY_MATRIX_VP,c+p1-w1);
					o.normal = nor;
					o.color = color;
					triStream.Append(o);

					triStream.RestartStrip();

					nor =normalize(cross(w1, p2-p1).xyz);
					//f3
					o.vertex = mul(UNITY_MATRIX_VP,c+p1-w1);
					o.normal = nor;
					o.color = color;
					triStream.Append(o);

					o.vertex = mul(UNITY_MATRIX_VP,c+p0+w0);
					o.normal = nor;
					o.color = color;
					triStream.Append(o);

					o.vertex = mul(UNITY_MATRIX_VP,c+p1+w1);
					o.normal = nor;
					o.color = color;
					triStream.Append(o);
					
					triStream.RestartStrip();					
				}

				//the landscape
				o.vertex = mul(UNITY_MATRIX_VP, p[0].pos);
				o.normal = normal;
				o.color = color;
				triStream.Append(o);

				o.vertex = mul(UNITY_MATRIX_VP, p[1].pos);
				o.normal = normal;
				o.color = color;
				triStream.Append(o);

				o.vertex = mul(UNITY_MATRIX_VP, p[2].pos);
				o.normal = normal;
				o.color = color;
				triStream.Append(o);
			}

			fixed4 frag (g2f i, fixed facing : VFACE) : SV_Target
			{
				i.normal *= facing > 0 ? 1 : -1;
				float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				float3 lambert = float(max(0.0,dot(i.normal, lightDirection))) * max(0.0, dot(lightDirection, float3(0,1,0))) * _LightColor0.rgb;
				float3 lightning = (ambient + lambert) * (_GrassColor.rgb + i.color * _DistributionScale);
				return fixed4(lightning,1.0);
			}
			ENDCG
		}
	}
}
