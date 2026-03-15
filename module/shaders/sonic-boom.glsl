// Sonic Boom — shockwave with black-hole collapse
//
// EXPANSION  (0–0.40s)  Rings expand, sparks fly, flash detonates
// TURBULENCE (0.35–0.55s) Ring edges fracture, intensity spikes
// COLLAPSE   (0.50–0.95s) Gravitational reversal — cubic infall
// SINGULARITY(0.90–1.10s) Implosion flash, aftershock ripple, silence

// ─── Palette ───────────────────────────────────────────────────────
const vec3  FROST0    = vec3(0.56, 0.74, 0.73);
const vec3  FROST1    = vec3(0.53, 0.75, 0.87);
const vec3  AURORA_G  = vec3(0.64, 0.75, 0.55);
const vec3  AURORA_P  = vec3(0.71, 0.56, 0.68);
const vec3  WHITE     = vec3(0.93, 0.94, 0.96);
const vec3  DEEP_BLUE = vec3(0.28, 0.35, 0.52);

// ─── Rings ─────────────────────────────────────────────────────────
const float R1_MAX    = 120.0;  const float R1_W = 4.5;   const float R1_I = 0.28;
const float R2_MAX    = 85.0;   const float R2_W = 7.0;   const float R2_I = 0.14;
const float R3_MAX    = 50.0;   const float R3_W = 14.0;  const float R3_I = 0.06;
const float R1_DISTORT = 6.0;
const float R2_DELAY   = 0.035;  const float R2_CHROMA = 4.5;
const float R3_DELAY   = 0.07;

// ─── Flash / Sparks / Glow / Singularity ───────────────────────────
const float FLASH_I = 0.35;  const float FLASH_R = 22.0;  const float FLASH_DUR = 0.10;
const float SPARK_N = 24.0;  const float SPARK_I = 0.50;  const float SPARK_SZ = 2.8;
const float SPARK_DIST = 100.0;  const float SPARK_SPREAD = 0.7;
const float GLOW_R  = 30.0;  const float GLOW_I  = 0.08;
const float IMP_I   = 0.55;  const float IMP_R   = 14.0;  const float IMP_DISTORT = 10.0;

// ─── Phase timing (seconds) ───────────────────────────────────────
const float T_TOTAL   = 1.10;
const float T_EXPAND  = 0.40;
const float T_TURB    = 0.32;
const float T_COLLAPSE = 0.48;
const float T_SINGULAR = 0.90;
const float T_DELAY    = 0.025;

// ─── Derived (normalized 0–1) ──────────────────────────────────────
#define N_EXPAND   (T_EXPAND   / T_TOTAL)
#define N_TURB     (T_TURB     / T_TOTAL)
#define N_COLLAPSE (T_COLLAPSE / T_TOTAL)
#define N_SINGULAR (T_SINGULAR / T_TOTAL)

// ─── Core math ─────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) { return c.xy + vec2(c.z * 0.5, -c.w * 0.5); }

float gaussian(float d, float w) { return exp(-0.5 * d * d / (w * w)); }

float ringAt(float dist, float radius, float width) {
    return gaussian(abs(dist - radius), width);
}

float hash(float n) { return fract(sin(n) * 43758.5453123); }

// ─── Phase system ──────────────────────────────────────────────────

// Collapse progress: 0 before collapse, 0→1 during collapse
float collapseProgress(float n) {
    return clamp((n - N_COLLAPSE) / (1.0 - N_COLLAPSE), 0.0, 1.0);
}

// Radius curve: 0→1→0 (expand, peak, collapse)
// Expansion: quadratic ease-out.  Collapse: cubic ease-in (gravity).
float phaseCurve(float n) {
    if (n < N_EXPAND) {
        float e = n / N_EXPAND;
        return 1.0 - (1.0 - e) * (1.0 - e);
    }
    if (n < N_COLLAPSE) return 1.0;  // turbulent peak
    float c = collapseProgress(n);
    return 1.0 - c * c * c;
}

// Intensity multiplier: 1x during expansion, ramps to 3x at singularity
float intensityRamp(float n) {
    float c = collapseProgress(n);
    return 1.0 + c * c * 2.0;
}

// Angular fracture noise: clean during expansion, violent during collapse
float fracture(float n, float t, float angle) {
    float onset = smoothstep(N_TURB, N_COLLAPSE, n);
    float violence = onset * (1.0 - smoothstep(0.7, 1.0, collapseProgress(n)));
    float noise = sin(angle * 7.0 + t * 15.0) * 0.5
                + sin(angle * 13.0 - t * 23.0) * 0.3
                + sin(angle * 19.0 + t * 37.0) * 0.2;
    return violence * noise;
}

// Apply turbulence to a ring: jitter radius and widen shape
void turbulentRing(float n, float t, float angle,
                   inout float radius, inout float width) {
    float f = fracture(n, t, angle);
    float ramp = smoothstep(0.3, 0.6, n);
    radius += f * 12.0 * ramp;
    width  += abs(f) * 6.0 * ramp;
}

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float elapsed = iTime - iTimeCursorChange;
    if (elapsed < T_DELAY || elapsed > T_TOTAL + T_DELAY + R3_DELAY) {
        fragColor = texture(iChannel0, fragCoord / iResolution.xy);
        return;
    }

    // Pixel geometry
    vec2  uv     = fragCoord / iResolution.xy;
    vec2  center = cursorCenter(iCurrentCursor);
    vec2  delta  = fragCoord - center;
    float dist   = length(delta);
    vec2  dir    = dist > 0.5 ? normalize(delta) : vec2(0.0, 1.0);
    float angle  = atan(delta.y, delta.x);

    // Time
    float t    = elapsed - T_DELAY;
    float n    = t / T_TOTAL;           // normalized 0–1
    float ph   = phaseCurve(n);         // radius curve 0→1→0
    float ci   = intensityRamp(n);      // collapse intensity
    float cp   = collapseProgress(n);   // 0 before, 0→1 during collapse
    bool  col  = n > N_COLLAPSE;        // collapsing?
    float cDir = col ? -1.0 : 1.0;     // direction flip

    // ── Ring 1: primary shockwave + UV distortion ──────────────────
    float r1r = ph * R1_MAX;
    float r1w = R1_W;
    turbulentRing(n, t, angle, r1r, r1w);
    float r1 = ringAt(dist, max(r1r, 0.0), r1w);

    float distStr = col ? R1_DISTORT * ci * 0.7 : R1_DISTORT;
    float uvShift = r1 * distStr / iResolution.x * cDir;

    // Gravitational lensing: radial pull during collapse
    float grav = 0.0;
    if (col && dist > 1.0) {
        grav = -IMP_DISTORT * cp * cp * cp / (dist * 0.08) / iResolution.x;
        grav *= smoothstep(R1_MAX * 1.5, 0.0, dist);
    }

    vec2 dUV = clamp(uv + dir * (uvShift + grav), vec2(0.0), vec2(1.0));
    vec4 orig = texture(iChannel0, dUV);
    float ring1 = r1 * R1_I * ci;

    // ── Ring 2: chromatic split ────────────────────────────────────
    vec3 ring2 = vec3(0.0);
    if (t > R2_DELAY) {
        float r2r = ph * R2_MAX;
        float r2w = R2_W;
        turbulentRing(n, t, angle + 1.0, r2r, r2w);
        float chroma = R2_CHROMA * cDir * ci;
        ring2 = vec3(
            ringAt(length(delta + dir * chroma), r2r, r2w) * 0.8,
            ringAt(dist, r2r, r2w),
            ringAt(length(delta - dir * chroma), r2r, r2w) * 1.2
        ) * R2_I * ci;
    }

    // ── Ring 3: ghost aurora ──────────────────────────────────────
    float ring3Val = 0.0;
    vec3  ring3 = vec3(0.0);
    if (t > R3_DELAY) {
        float r3r = ph * R3_MAX;
        float r3w = R3_W;
        float f3 = fracture(n, t, angle + 2.0);
        r3r += f3 * 15.0 * smoothstep(0.25, 0.6, n);
        r3w += abs(f3) * 10.0 * smoothstep(0.3, 0.7, n);
        ring3Val = ringAt(dist, max(r3r, 0.0), r3w);

        float hue = fract(angle / 6.2832 + 0.5);
        vec3 aurora = mix(AURORA_G, AURORA_P, smoothstep(0.3, 0.7, hue));
        aurora = mix(aurora, FROST0, smoothstep(0.7, 1.0, hue));
        if (col) aurora = mix(aurora, DEEP_BLUE, cp * 0.7);

        ring3 = aurora * ring3Val * R3_I * ci;
    }

    // ── Flash (expansion only) ────────────────────────────────────
    float ft = t / FLASH_DUR;
    float flash = (ft > 0.0 && ft < 1.0)
        ? FLASH_I * smoothstep(FLASH_R, 0.0, dist) * (1.0 - ft * ft)
        : 0.0;

    // ── Sparks — follow phase curve, reverse during collapse ──────
    float sparks = 0.0;
    if (t > 0.0 && n < N_SINGULAR) {
        float sFade = 1.0 - smoothstep(0.7, N_SINGULAR, n);
        for (float i = 0.0; i < SPARK_N; i += 1.0) {
            float seed = hash(i * 137.0 + 0.5);
            float sa   = (i / SPARK_N) * 6.2832 + seed * 1.5;
            float sr   = ph * SPARK_DIST * (1.0 + (seed - 0.5) * SPARK_SPREAD);
            if (col) sr += fracture(n, t, sa) * 8.0;

            vec2  sp  = center + vec2(cos(sa), sin(sa)) * max(sr, 0.0);
            float sd  = length(fragCoord - sp);
            float sz  = SPARK_SZ * max(ph, 0.15) * (col ? 0.6 : 1.0);

            if (sd < sz * 3.0)
                sparks += gaussian(sd, sz) * sFade * SPARK_I * ci;
        }
    }

    // ── Afterglow — expansion fade + collapse rekindle ────────────
    float glow = GLOW_I * smoothstep(GLOW_R, 0.0, dist)
               * (1.0 - smoothstep(0.0, 0.35, n));
    if (col) {
        float shrink = GLOW_R * (1.0 - cp * 0.7);
        glow += GLOW_I * 2.5 * cp * cp * smoothstep(shrink, 0.0, dist);
    }

    // ── Singularity implosion ─────────────────────────────────────
    float implode = 0.0;
    if (n > N_SINGULAR) {
        float s = (n - N_SINGULAR) / (1.0 - N_SINGULAR);
        float curve = s < 0.5 ? 4.0 * s * s : 4.0 * (1.0 - s) * (1.0 - s);
        implode = IMP_I * smoothstep(IMP_R * (1.0 - s), 0.0, dist) * curve;

        // Aftershock micro-ripple
        if (s > 0.5) {
            float rt = (s - 0.5) * 2.0;
            implode += ringAt(dist, rt * 40.0, 2.0) * (1.0 - rt) * 0.08;
        }
    }

    // ── Compose ───────────────────────────────────────────────────
    vec3 tint = col ? mix(FROST1, DEEP_BLUE, min(cp * 1.2, 0.6)) : FROST1;

    vec3 fx = tint * ring1
            + ring2
            + ring3
            + WHITE * (flash + implode)
            + mix(FROST1, WHITE, 0.6) * sparks
            + mix(FROST0, AURORA_G, 0.3) * glow;

    float total = ring1 + dot(ring2, vec3(0.33))
                + ring3Val * R3_I * ci + flash + sparks + glow + implode;

    vec3 result = mix(orig.rgb, orig.rgb + fx, smoothstep(0.0, 0.003, total));
    fragColor = vec4(result, orig.a);
}
