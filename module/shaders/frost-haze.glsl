// Frost Haze — atmospheric frost veil at screen edges
//
// Simulates subtle frost condensation at the terminal edges, like
// looking through slightly fogged glass on a cold day. Nord frost
// blue tint with ultra-slow animated noise. Purely cosmetic
// atmosphere that does not affect readability.
//
// Shared functions: hashCell, valueNoise (see nord-common.glsl)

// ─── Color Palette ─────────────────────────────────────────────────────
const vec3  HAZE_COLOR   = vec3(0.53, 0.75, 0.86);  // Nord frost blue

// ─── Haze Parameters ───────────────────────────────────────────────────
const float HAZE_OPACITY = 0.035;  // barely there
const float EDGE_START   = 0.55;   // where haze begins (0=center, 1=edge)
const float EDGE_POWER   = 2.5;    // falloff sharpness
const float NOISE_SCALE  = 4.0;    // noise detail level
const float DRIFT_SPEED  = 0.03;   // ultra slow movement

// ─── Helpers ───────────────────────────────────────────────────────────

// Internal cell hash for value noise (different constants to avoid
// correlation with hash21).
float hashCell(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Smooth interpolated 2D value noise.
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);  // smoothstep interpolation

    float a = hashCell(i);
    float b = hashCell(i + vec2(1.0, 0.0));
    float c = hashCell(i + vec2(0.0, 1.0));
    float d = hashCell(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian motion — 3 octaves of value noise.
float fbm(vec2 p) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        val += amp * valueNoise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return val;
}

// ─── Main ──────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // Radial distance from center (0 at center, ~1.41 at corners)
    vec2 centered = uv * 2.0 - 1.0;
    float edgeDist = length(centered);

    // Early exit — center of screen has no haze
    if (edgeDist < EDGE_START * 0.9) {
        fragColor = original;
        return;
    }

    // Edge mask — haze only at edges
    float edgeMask = smoothstep(EDGE_START, 1.2, edgeDist);
    edgeMask = pow(edgeMask, EDGE_POWER);

    // Animated noise for organic frost pattern
    float drift = iTime * DRIFT_SPEED;
    float n = fbm(uv * NOISE_SCALE + vec2(drift, drift * 0.7));

    // Combine edge mask with noise
    float haze = edgeMask * n * HAZE_OPACITY;

    vec3 result = mix(original.rgb, HAZE_COLOR, haze);

    fragColor = vec4(result, original.a);
}
