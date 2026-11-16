// Material estándar con curvatura de planeta (CurvedWorld).
// Equivale al subconjunto de StandardMaterial3D que usa SPATIUM IV: color y textura,
// rugosidad/metálico, mapa de normales, emisión, proyección triplanar (rocas),
// color de vértice, transparencia y sin sombreado. Las variantes se eligen con
// #define antes de incluir este archivo (ver curved_world.gd).

global uniform float planet_curvature;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo_texture = false;
uniform bool use_vertex_color = false;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_roughness_texture = false;
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_normal = false;
uniform float normal_scale = 1.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float triplanar_sharpness = 1.0;

#ifdef TRIPLANAR
varying vec3 v_tri_pos;
varying vec3 v_tri_w;
#endif

void vertex() {
#ifdef TRIPLANAR
	vec3 n = pow(abs(NORMAL), vec3(triplanar_sharpness));
	v_tri_w = n / max(dot(n, vec3(1.0)), 0.0001);
	v_tri_pos = VERTEX * uv1_scale + uv1_offset;
	v_tri_pos *= vec3(1.0, -1.0, 1.0);
#else
	UV = UV * uv1_scale.xy + uv1_offset.xy;
#endif
	// curvatura del planeta: baja según la distancia horizontal a la cámara principal
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = w.xz - MAIN_CAM_INV_VIEW_MATRIX[3].xz;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(0.0, -dot(d, d) * planet_curvature, 0.0);
}

vec4 sample_tex(sampler2D s, vec2 uv) {
#ifdef TRIPLANAR
	return texture(s, v_tri_pos.xy) * v_tri_w.z + texture(s, v_tri_pos.xz) * v_tri_w.y + texture(s, v_tri_pos.zy * vec2(-1.0, 1.0)) * v_tri_w.x;
#else
	return texture(s, uv);
#endif
}

void fragment() {
	vec4 base = albedo;
	if (use_albedo_texture) {
		base *= sample_tex(texture_albedo, UV);
	}
	if (use_vertex_color) {
		base *= COLOR;
	}
	ALBEDO = base.rgb;
#ifdef TRANSPARENT
	ALPHA = base.a;
#endif
#ifndef UNSHADED
	float r = roughness;
	if (use_roughness_texture) {
		r *= dot(sample_tex(texture_roughness, UV), roughness_channel);
	}
	ROUGHNESS = r;
	METALLIC = metallic;
	SPECULAR = specular;
	if (use_normal) {
		NORMAL_MAP = sample_tex(texture_normal, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
#endif
	EMISSION = emission * emission_energy;
}
