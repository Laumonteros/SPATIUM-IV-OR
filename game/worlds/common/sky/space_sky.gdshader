shader_type sky;
// Cielo espacial de SPATIUM IV: estrellas reales, disco solar y un planeta/luna visible.
//
// - Estrellas: NASA SVS "Deep Star Maps 2020" (proyección equirectangular, coordenadas ecuatoriales).
// - El planeta del cielo (la Tierra vista desde la Luna) se dibuja como una esfera iluminada por
//   el mismo sol de la escena, así que su FASE es físicamente coherente con la dirección del sol.
// - Tamaño angular real de la Tierra desde la Luna: ~1,9° de diámetro. `planet_scale` lo amplía
//   por legibilidad (valor ADAPTADO, documentado en docs/fuentes_y_licencias.md).

group_uniforms Estrellas;
uniform sampler2D star_map : source_color, filter_linear_mipmap, repeat_enable;
uniform float star_brightness : hint_range(0.0, 8.0) = 1.6;
uniform float star_contrast : hint_range(0.5, 3.0) = 1.6;
uniform vec3 star_rotation = vec3(0.0, 0.0, 0.0); // radianes (orientación del cielo)
// Ángulo que cubre un píxel (rad). Lo actualiza el juego según el FOV: las
// estrellas puntuales quedan nítidas a cualquier zoom y aparecen más al acercar.
uniform float pixel_angle = 0.0017;
uniform float milky_way_strength : hint_range(0.0, 2.0) = 0.55;
uniform float point_star_strength : hint_range(0.0, 4.0) = 1.0;

group_uniforms Planetas;
// Venus, Marte, Júpiter, Saturno (direcciones y radios los carga el juego desde
// data/sky/celestial_bodies.json; el tamaño está ampliado, ver fuentes).
uniform vec3 body_dir[4];
uniform float body_radius[4];
uniform float body_dist_au[4]; // distancia aproximada al observador (UA), para la fase

group_uniforms Sol;
uniform float sun_angular_radius = 0.0047; // rad (0,27°, valor real)
uniform float sun_disk_intensity = 9.0;
uniform float sun_glow_intensity = 0.35;

group_uniforms Planeta;
uniform bool planet_enabled = true;
uniform vec3 planet_direction = vec3(0.35, 0.32, -0.88);
uniform float planet_angular_radius = 0.0166; // rad (Tierra desde la Luna: 0,95°)
uniform float planet_scale : hint_range(1.0, 6.0) = 2.4;
uniform sampler2D planet_day : source_color, filter_linear_mipmap;
uniform sampler2D planet_clouds : source_color, filter_linear_mipmap;
uniform float planet_rotation = 1.2;
uniform float planet_tilt = 0.41; // 23,4° de inclinación axial
uniform vec3 atmosphere_color : source_color = vec3(0.35, 0.6, 1.0);
uniform float planet_intensity = 2.2;

mat3 rot_xyz(vec3 r) {
	float cx = cos(r.x), sx = sin(r.x), cy = cos(r.y), sy = sin(r.y), cz = cos(r.z), sz = sin(r.z);
	mat3 mx = mat3(vec3(1, 0, 0), vec3(0, cx, sx), vec3(0, -sx, cx));
	mat3 my = mat3(vec3(cy, 0, -sy), vec3(0, 1, 0), vec3(sy, 0, cy));
	mat3 mz = mat3(vec3(cz, sz, 0), vec3(-sz, cz, 0), vec3(0, 0, 1));
	return mz * my * mx;
}

vec2 dir_to_equirect(vec3 d) {
	float lon = atan(d.x, -d.z);
	float lat = asin(clamp(d.y, -1.0, 1.0));
	return vec2(0.5 + lon / TAU, 0.5 - lat / PI);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Color aproximado de una estrella según su temperatura (t: 0 = roja fría, 1 = azul caliente)
vec3 star_tint(float t) {
	vec3 cold = vec3(1.0, 0.68, 0.45);
	vec3 sun_like = vec3(1.0, 0.95, 0.86);
	vec3 hot = vec3(0.68, 0.8, 1.0);
	return t < 0.55 ? mix(cold, sun_like, t / 0.55) : mix(sun_like, hot, (t - 0.55) / 0.45);
}

// Una capa de estrellas puntuales: una (o ninguna) estrella por celda de una grilla 3D.
// Sin atmósfera no hay centelleo: las estrellas de la Luna no titilan.
// b_min/b_max: rango de brillo de la capa (pocas brillantes, muchas tenues).
vec3 star_layer(vec3 dir, float cells, float density, float seed, float b_min, float b_max) {
	vec3 id = floor(dir * cells);
	vec3 h = hash33(id + seed);
	if (h.x > density) {
		return vec3(0.0);
	}
	vec3 j = hash33(id + seed + 17.0);
	vec3 sdir = normalize((id + 0.25 + 0.5 * j) / cells);
	float d = length(dir - sdir);
	float b = mix(b_min, b_max, pow(h.y, 12.0));
	float sigma = pixel_angle * 0.55;
	float core = exp(-d * d / (2.0 * sigma * sigma));
	float halo = exp(-d / (pixel_angle * 0.9)) * 0.06 * smoothstep(1.2, 3.0, b);
	return star_tint(h.z) * b * (core + halo);
}

vec3 stars(vec3 dir) {
	vec3 sd = rot_xyz(star_rotation) * dir;
	// Vía Láctea y polvo (NASA Deep Star Maps) desenfocados: solo resplandor de fondo
	vec3 band = textureLod(star_map, dir_to_equirect(sd), 2.5).rgb;
	band = pow(band, vec3(star_contrast)) * star_brightness * milky_way_strength;
	// con aumento (binoculares) aparecen estrellas más débiles
	float zoom = smoothstep(0.0011, 0.0005, pixel_angle);
	float dense = clamp(dot(band, vec3(0.33)) * 5.0, 0.0, 1.0);
	vec3 pts = star_layer(sd, 34.0, 0.45, 1.0, 0.35, 4.0)          // brillantes y medias
		+ star_layer(sd, 70.0, 0.5, 7.0, 0.16, 0.6)                 // tenues
		+ star_layer(sd, 70.0, 0.6 * dense, 29.0, 0.14, 0.4);       // cúmulos de la Vía Láctea
	if (zoom > 0.0) {
		pts += (star_layer(sd, 180.0, 0.45, 13.0, 0.12, 0.45)
			+ star_layer(sd, 260.0, 0.7 * dense, 23.0, 0.1, 0.3)) * zoom;
	}
	return band + pts * point_star_strength;
}

// Planetas del sistema solar (procedurales): color, bandas, casquete o anillos,
// iluminados por el mismo sol (la fase es coherente con su posición).
vec4 solar_body(vec3 dir, int i, vec3 sun_dir) {
	vec3 pd = normalize(body_dir[i]);
	float radius = max(body_radius[i], 0.00001);
	float ring_k = i == 3 ? 2.3 : 1.0;
	float ang = length(dir - pd);
	float reach = max(radius * ring_k * 1.05, pixel_angle * 4.0);
	if (ang > reach) {
		return vec4(0.0);
	}
	vec3 up = abs(pd.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, pd));
	vec3 up2 = cross(pd, right);
	vec3 off = dir - pd * dot(dir, pd);
	vec2 p = vec2(dot(off, right), dot(off, up2)) / radius;
	float r2 = dot(p, p);
	vec3 col = vec3(0.0);
	float a = 0.0;
	float glow = exp(-ang * ang / (2.0 * pow(pixel_angle * 0.9, 2.0)));
	vec3 base = i == 0 ? vec3(1.0, 0.95, 0.82) : (i == 1 ? vec3(0.85, 0.42, 0.22) : (i == 2 ? vec3(0.92, 0.84, 0.7) : vec3(0.93, 0.85, 0.62)));
	if (r2 < 1.0) {
		vec3 n = normalize(right * p.x + up2 * p.y - pd * sqrt(1.0 - r2));
		float lat = p.y;
		vec3 surf = base;
		if (i == 0) { // Venus: capa de nubes casi sin detalle
			surf *= 0.92 + 0.08 * sin(lat * 9.0 + p.x * 2.0);
		} else if (i == 1) { // Marte: manchas oscuras y casquete polar
			float m = hash33(floor(vec3(p * 5.0, 3.0))).x;
			surf = mix(surf, vec3(0.45, 0.22, 0.12), smoothstep(0.55, 0.9, m) * 0.6);
			surf = mix(surf, vec3(0.95), smoothstep(0.8, 0.9, lat));
		} else if (i == 2) { // Júpiter: bandas y Gran Mancha Roja
			float bands = sin(lat * 15.0 + sin(p.x * 3.0 + lat * 4.0) * 0.4);
			surf = mix(vec3(0.95, 0.9, 0.8), vec3(0.72, 0.52, 0.36), smoothstep(-0.2, 0.6, bands));
			float spot = length((p - vec2(0.35, -0.38)) * vec2(1.0, 1.8));
			surf = mix(surf, vec3(0.78, 0.36, 0.24), smoothstep(0.17, 0.11, spot));
		} else { // Saturno: bandas suaves
			surf *= 0.9 + 0.1 * sin(lat * 11.0);
		}
		// el Sol ilumina al planeta desde su propia posición (Sol a 1 UA de la Luna)
		vec3 to_sun = normalize(sun_dir - pd * max(body_dist_au[i], 0.1));
		float ndl = dot(n, to_sun);
		float lit = smoothstep(-0.05, 0.2, ndl);
		col = surf * lit * 2.2;
		a = smoothstep(1.0, 0.94, r2);
	}
	if (i == 3) { // anillos (abiertos ~20°): la mitad delantera tapa el disco
		vec2 q = vec2(p.x, p.y / 0.34);
		float rr = length(q);
		float ring = smoothstep(1.25, 1.3, rr) * smoothstep(2.3, 2.2, rr) * (0.75 + 0.25 * sin(rr * 40.0));
		ring *= 1.0 - smoothstep(1.72, 1.78, rr) * smoothstep(1.86, 1.8, rr) * 0.85; // división de Cassini
		bool front = p.y < 0.0;
		if (ring > 0.0 && (front || r2 >= 1.0)) {
			col = mix(col, vec3(0.9, 0.82, 0.62) * 1.8, ring * 0.9);
			a = max(a, ring * 0.9);
		}
	}
	// a escala de píxel (sin aumento), el disco se ve como un punto brillante
	float point = 1.0 - smoothstep(pixel_angle * 1.5, pixel_angle * 4.0, radius);
	col = mix(col, base * 3.0 * glow, point);
	a = mix(a, glow, point);
	return vec4(col, a);
}

// Devuelve rgb del planeta y su cobertura (alpha) en la dirección `dir`.
vec4 planet(vec3 dir, vec3 sun_dir) {
	vec3 pd = normalize(planet_direction);
	float radius = planet_angular_radius * planet_scale;
	float ang = acos(clamp(dot(dir, pd), -1.0, 1.0));
	float edge = radius * 1.12;
	if (ang > edge) {
		return vec4(0.0);
	}
	// Base local del disco
	vec3 up = abs(pd.y) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, pd));
	vec3 up2 = cross(pd, right);
	vec3 off = dir - pd * dot(dir, pd);
	vec2 p = vec2(dot(off, right), dot(off, up2)) / sin(radius);
	float r2 = dot(p, p);
	// Halo atmosférico fuera del disco
	if (r2 > 1.0) {
		float rr = sqrt(r2);
		float halo = smoothstep(1.12, 1.0, rr);
		vec3 n_edge = normalize(right * p.x / rr + up2 * p.y / rr);
		float lit = clamp(dot(n_edge, sun_dir) + 0.25, 0.0, 1.0);
		return vec4(atmosphere_color * halo * halo * lit * 0.6 * planet_intensity, 0.0);
	}
	// Normal de la esfera (hacia el observador = -pd)
	vec3 n = normalize(right * p.x + up2 * p.y - pd * sqrt(1.0 - r2));
	// Coordenadas de superficie con rotación e inclinación
	mat3 spin = rot_xyz(vec3(planet_tilt, planet_rotation, 0.0));
	vec3 sn = spin * n;
	vec2 uv = vec2(0.5 + atan(sn.x, sn.z) / TAU, 0.5 - asin(clamp(sn.y, -1.0, 1.0)) / PI);
	vec3 day = texture(planet_day, uv).rgb;
	float cloud = texture(planet_clouds, uv).r;
	// sombra de las nubes sobre la superficie
	float cloud_shadow = texture(planet_clouds, uv + vec2(0.003, 0.002)).r;
	day *= 1.0 - cloud_shadow * 0.35;
	vec3 surf = mix(day, vec3(1.0), cloud * 0.85);
	float ndl = dot(n, sun_dir);
	float light = smoothstep(-0.08, 0.25, ndl);
	float fres = pow(1.0 - clamp(dot(-n, -pd), 0.0, 1.0), 3.0);
	// océanos: reflejo especular del sol
	float ocean = smoothstep(0.02, 0.12, day.b - max(day.r, day.g * 0.9)) * (1.0 - cloud);
	vec3 hv = normalize(sun_dir - pd);
	float spec = pow(max(dot(n, hv), 0.0), 60.0) * ocean * 1.6;
	// terminador cálido (luz filtrada por la atmósfera)
	float dusk = exp(-abs(ndl) * 9.0) * 0.35;
	vec3 col = surf * light + vec3(1.0, 0.55, 0.3) * dusk * clamp(ndl + 0.2, 0.0, 1.0)
		+ vec3(1.0, 0.95, 0.85) * spec * light
		+ atmosphere_color * fres * clamp(ndl + 0.3, 0.0, 1.0) * 0.8;
	// Borde suavizado (antialias)
	float aa = smoothstep(1.0, 0.97, r2);
	return vec4(col * planet_intensity, aa);
}

// Sol visto sin atmósfera: disco blanco con oscurecimiento hacia el borde
// (limb darkening), corona suave continua y seis rayos de difracción tenues
// del lente. El brillo es moderado para que el bloom no genere anillos.
vec3 sun(vec3 dir, vec3 sun_dir, vec3 light_col) {
	float sa = acos(clamp(dot(dir, sun_dir), -1.0, 1.0));
	float r = sa / sun_angular_radius;
	vec3 tint = vec3(1.0, 0.97, 0.92);
	float mu = sqrt(max(0.0, 1.0 - min(r * r, 1.0)));
	float limb = 1.0 - 0.55 * (1.0 - mu) - 0.15 * (1.0 - mu * mu);
	float disk = smoothstep(1.04, 0.96, r) * limb;
	float rr = max(r - 1.0, 0.0);
	float corona = 1.1 * exp(-rr * 1.8) + 0.18 * exp(-sa * 10.0) + 0.035 * exp(-sa * 2.2);
	corona *= sun_glow_intensity / 0.35;
	// rayos de difracción (6 puntas), solo cerca del disco
	vec3 up = abs(sun_dir.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tx = normalize(cross(up, sun_dir));
	vec3 ty = cross(sun_dir, tx);
	float ang = atan(dot(dir, ty), dot(dir, tx));
	float spikes = pow(abs(cos(ang * 3.0)), 90.0) * exp(-rr * 0.22) * 0.22 * step(0.0, dot(dir, sun_dir));
	return light_col * tint * (disk * sun_disk_intensity + (corona + spikes) * (1.0 - disk));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);
	vec3 col = vec3(0.0);
	if (!AT_CUBEMAP_PASS) {
		col += stars(dir);
		// Sol
		if (LIGHT0_ENABLED) {
			col += sun(dir, sun_dir, LIGHT0_COLOR);
		}
		for (int i = 0; i < 4; i++) {
			vec4 bd = solar_body(dir, i, sun_dir);
			col = mix(col, bd.rgb, clamp(bd.a, 0.0, 1.0));
		}
		if (planet_enabled) {
			vec4 pl = planet(dir, sun_dir);
			col = mix(col, pl.rgb, pl.a) + (pl.a <= 0.0 ? pl.rgb : vec3(0.0));
		}
	}
	// En el pase de cubemap (reflejos/luz ambiente) el cielo lunar es negro.
	COLOR = col;
}
