// Sonic Boom — shockwave with gravitational collapse
//
// EXPANSION  (0–0.40s)  Rings bloom outward, sparks scatter
// EXHAUSTION (0.35–0.50s) Rings thin and dim, energy draining away
// TURBULENCE (0.45–0.60s) Edges fracture, ring breathes erratically
// COLLAPSE   (0.55–0.95s) Gravitational reversal — sparks spiral inward,
//                          rings compress with accelerating ferocity
// SINGULARITY(0.90–1.15s) Silent convergence, faint afterimage lingers

// ─── Palette ───────────────────────────────────────────────────────
const vec3  FROST0    = vec3(0.56, 0.74, 0.73);
const vec3  FROST1    = vec3(0.53, 0.75, 0.87);
const vec3  AURORA_G  = vec3(0.64, 0.75, 0.55);
const vec3  AURORA_P  = vec3(0.71, 0.56, 0.68);
const vec3  WHITE     = vec3(0.93, 0.94, 0.96);
const vec3  DEEP_BLUE = vec3(0.28, 0.35, 0.52);
const vec3  HOT_CORE  = vec3(0.80, 0.88, 0.95);   // compressed matter glow

// ─── Rings ─────────────────────────────────────────────────────────
const float R1_MAX = 130.0;   const float R1_W = 4.0;   const float R1_I = 0.22;
const float R2_MAX = 90.0;    const float R2_W = 6.0;   const float R2_I = 0.11;
const float R3_MAX = 55.0;    const float R3_W = 12.0;  const float R3_I = 0.05;
const float R1_DISTORT = 5.0;
const float R2_DELAY   = 0.04;   const float R2_CHROMA = 3.5;
const float R3_DELAY   = 0.08;

// ─── Sparks / Glow ────────────────────────────────────────────────
const float SPARK_N = 20.0;     const float SPARK_I = 0.35;   const float SPARK_SZ = 2.2;
const float SPARK_DIST = 110.0; const float SPARK_SPREAD = 0.6;
const float GLOW_R  = 28.0;     const float GLOW_I  = 0.06;

// ─── Collapse ─────────────────────────────────────────────────────
const float GRAV_DISTORT = 8.0;
const float AFTERIMAGE_I = 0.025;   // ghost ring persistence

// ─── Phase timing (seconds) ──────────────────────────────────────
const float T_TOTAL    = 1.15;
const float T_EXPAND   = 0.40;
const float T_EXHAUST  = 0.35;   // energy starts draining
const float T_TURB     = 0.45;
const float T_COLLAPSE = 0.55;
const float T_SINGULAR = 0.90;
const float T_DELAY    = 0.025;

// ─── Derived ─────────────────────────────────────────────────────
#define N_EXPAND   (T_EXPAND   / T_TOTAL)
#define N_EXHAUST  (T_EXHAUST  / T_TOTAL)
#define N_TURB     (T_TURB     / T_TOTAL)
#define N_COLLAPSE (T_COLLAPSE / T_TOTAL)
#define N_SINGULAR (T_SINGULAR / T_TOTAL)

// ─── Core math ───────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) { return c.xy + vec2(c.z * 0.5, -c.w * 0.5); }
float gaussian(float d, float w) { return exp(-0.5 * d * d / (w * w)); }
float ringAt(float d, float r, float w) { return gaussian(abs(d - r), w); }
float hash(float n) { return fract(sin(n) * 43758.5453123); }

// ─── Phase system ────────────────────────────────────────────────

float collapseProgress(float n) {
    return clamp((n - N_COLLAPSE) / (1.0 - N_COLLAPSE), 0.0, 1.0);
}

// Radius: 0→1→0 with exhaustion dip before collapse
float phaseCurve(float n) {
    if (n < N_EXPAND) {
        float e = n / N_EXPAND;
        return 1.0 - (1.0 - e) * (1.0 - e);   // ease-out
    }
    if (n < N_COLLAPSE) return 1.0;
    float c = collapseProgress(n);
    return 1.0 - c * c * c;                     // cubic ease-in (gravity)
}

// Energy envelope: full during expansion, dips during exhaustion,
// reignites during collapse with compressed intensity
float energyEnvelope(float n) {
    // Exhaustion dip: energy drains at peak expansion
    float drain = 1.0 - 0.4 * smoothstep(N_EXHAUST, N_COLLAPSE, n)
                      * (1.0 - smoothstep(N_COLLAPSE, N_COLLAPSE + 0.08, n));
    // Collapse reignition
    float cp = collapseProgress(n);
    float reignite = 1.0 + cp * cp * 1.5;
    return drain * reignite;
}

// Fracture noise — organic wobble + sharp angular breaks
float fracture(float n, float t, float angle) {
    float onset = smoothstep(N_TURB, N_COLLAPSE + 0.1, n);
    float fade  = 1.0 - smoothstep(0.75, 1.0, collapseProgress(n));

    // Organic wobble (low frequency, smooth)
    float wobble = sin(angle * 3.0 + t * 8.0) * 0.4
                 + sin(angle * 5.0 - t * 12.0) * 0.3;
    // Sharp fracture (high frequency, violent)
    float shatter = sin(angle * 11.0 + t * 19.0) * 0.35
                  + sin(angle * 17.0 - t * 31.0) * 0.25;

    // Blend: wobble dominates early, shatter takes over
    float violence = smoothstep(N_TURB, N_COLLAPSE + 0.15, n);
    float noise = mix(wobble, wobble + shatter, violence);

    return onset * fade * noise;
}

// Ring breathing — erratic intensity flicker during turbulence
float ringBreathe(float n, float t) {
    float turb = smoothstep(N_TURB, N_COLLAPSE, n)
               * (1.0 - smoothstep(N_COLLAPSE + 0.15, N_SINGULAR, n));
    float flicker = sin(t * 45.0) * 0.3 + sin(t * 67.0) * 0.2 + sin(t * 23.0) * 0.15;
    return 1.0 + turb * flicker * 0.4;
}

void turbulentRing(float n, float t, float angle,
                   inout float radius, inout float width) {
    float f = fracture(n, t, angle);
    float ramp = smoothstep(0.28, 0.6, n);
    radius += f * 14.0 * ramp;
    width  += abs(f) * 5.0 * ramp;
}

// ─── Main ────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float elapsed = iTime - iTimeCursorChange;
    if (elapsed < T_DELAY || elapsed > T_TOTAL + T_DELAY + R3_DELAY + 0.5) {
        fragColor = texture(iChannel0, fragCoord / iResolution.xy);
        return;
    }

    vec2  uv     = fragCoord / iResolution.xy;
    vec2  center = cursorCenter(iCurrentCursor);
    vec2  delta  = fragCoord - center;
    float dist   = length(delta);
    vec2  dir    = dist > 0.5 ? normalize(delta) : vec2(0.0, 1.0);
    float angle  = atan(delta.y, delta.x);

    float t    = elapsed - T_DELAY;
    float n    = t / T_TOTAL;
    float ph   = phaseCurve(n);
    float en   = energyEnvelope(n);
    float cp   = collapseProgress(n);
    float br   = ringBreathe(n, t);
    bool  col  = n > N_COLLAPSE;
    float cDir = col ? -1.0 : 1.0;

    // ── Ring 1: primary shockwave ────────────────────────────────
    float r1r = ph * R1_MAX;
    float r1w = R1_W;
    turbulentRing(n, t, angle, r1r, r1w);

    // Exhaustion: ring thins out at peak
    r1w *= mix(1.0, 0.6, smoothstep(N_EXHAUST, N_COLLAPSE, n)
                        * (1.0 - smoothstep(N_COLLAPSE, N_COLLAPSE + 0.1, n)));

    float r1 = ringAt(dist, max(r1r, 0.0), r1w);

    // UV distortion: outward → inward, with gravitational lensing
    float distStr = col ? R1_DISTORT * (1.0 + cp) * 0.6 : R1_DISTORT;
    float uvShift = r1 * distStr / iResolution.x * cDir;

    float grav = 0.0;
    if (col && dist > 1.0) {
        grav = -GRAV_DISTORT * cp * cp * cp / (dist * 0.1) / iResolution.x;
        grav *= smoothstep(R1_MAX * 1.4, 0.0, dist);
    }

    vec2 dUV = clamp(uv + dir * (uvShift + grav), vec2(0.0), vec2(1.0));
    vec4 orig = texture(iChannel0, dUV);
    float ring1 = r1 * R1_I * en * br;

    // ── Ring 2: chromatic split ──────────────────────────────────
    vec3 ring2 = vec3(0.0);
    if (t > R2_DELAY) {
        float r2r = ph * R2_MAX;
        float r2w = R2_W;
        turbulentRing(n, t, angle + 1.0, r2r, r2w);
        float chroma = R2_CHROMA * cDir * (1.0 + cp * 0.5);
        ring2 = vec3(
            ringAt(length(delta + dir * chroma), r2r, r2w) * 0.85,
            ringAt(dist, r2r, r2w),
            ringAt(length(delta - dir * chroma), r2r, r2w) * 1.15
        ) * R2_I * en * br;
    }

    // ── Ring 3: ghost aurora ────────────────────────────────────
    float r3v = 0.0;
    vec3  ring3 = vec3(0.0);
    if (t > R3_DELAY) {
        float r3r = ph * R3_MAX;
        float r3w = R3_W;
        float f3 = fracture(n, t, angle + 2.0);
        r3r += f3 * 16.0 * smoothstep(0.22, 0.55, n);
        r3w += abs(f3) * 8.0 * smoothstep(0.28, 0.65, n);
        r3v = ringAt(dist, max(r3r, 0.0), r3w);

        float hue = fract(angle / 6.2832 + 0.5 + t * 0.05);  // slow rotation
        vec3 aurora = mix(AURORA_G, AURORA_P, smoothstep(0.25, 0.75, hue));
        aurora = mix(aurora, FROST0, smoothstep(0.75, 1.0, hue));
        if (col) aurora = mix(aurora, DEEP_BLUE, cp * 0.65);

        ring3 = aurora * r3v * R3_I * en;
    }

    // ── Sparks — spiral inward during collapse ──────────────────
    float sparks = 0.0;
    if (t > 0.0 && n < N_SINGULAR + 0.05) {
        float sFade = 1.0 - smoothstep(0.7, N_SINGULAR, n);
        for (float i = 0.0; i < SPARK_N; i += 1.0) {
            float seed = hash(i * 137.0 + 0.5);
            float sa = (i / SPARK_N) * 6.2832 + seed * 1.5;
            float sr = ph * SPARK_DIST * (1.0 + (seed - 0.5) * SPARK_SPREAD);

            // Spiral: add angular velocity during collapse (drain effect)
            if (col) {
                sa += cp * cp * 2.5 * (seed > 0.5 ? 1.0 : -1.0);
                sr += fracture(n, t, sa) * 6.0;
            }

            vec2  sp = center + vec2(cos(sa), sin(sa)) * max(sr, 0.0);
            float sd = length(fragCoord - sp);
            float sz = SPARK_SZ * max(ph, 0.12) * (col ? 0.5 : 1.0);

            if (sd < sz * 3.0)
                sparks += gaussian(sd, sz) * sFade * SPARK_I * en;
        }
    }

    // ── Afterglow — drains, rekindles, heats ────────────────────
    float glow = GLOW_I * smoothstep(GLOW_R, 0.0, dist)
               * (1.0 - smoothstep(0.0, 0.4, n));
    if (col) {
        float shrink = GLOW_R * (1.0 - cp * 0.8);
        glow += GLOW_I * 3.0 * cp * cp * smoothstep(shrink, 0.0, dist);
    }

    // ── Singularity: silent convergence, no flash ───────────────
    // Just an intensifying point glow that swallows everything
    float singularity = 0.0;
    if (n > N_SINGULAR) {
        float s = (n - N_SINGULAR) / (1.0 - N_SINGULAR);
        float focusR = 8.0 * (1.0 - s * s);
        singularity = 0.3 * smoothstep(focusR, 0.0, dist) * (1.0 - s);
    }

    // ── Afterimage: ghost ring that lingers after silence ────────
    float afterimage = 0.0;
    if (n > 0.95) {
        float ai = (n - 0.95) / 0.05;   // 0→1 over last 5% of cycle
        float ghostR = 18.0 + ai * 8.0;  // slowly drifts outward
        afterimage = AFTERIMAGE_I * ringAt(dist, ghostR, 6.0) * (1.0 - ai);
    }
    // Extended afterimage past T_TOTAL
    float postN = (elapsed - T_DELAY) / T_TOTAL;
    if (postN > 1.0 && postN < 1.45) {
        float fade = 1.0 - (postN - 1.0) / 0.45;
        float ghostR = 26.0 + (postN - 1.0) * 15.0;
        afterimage += AFTERIMAGE_I * 0.6 * ringAt(dist, ghostR, 8.0) * fade * fade;
    }

    // ── Compose ─────────────────────────────────────────────────
    // Color temperature: frost → deep blue → hot white at singularity
    vec3 tint = FROST1;
    if (col) tint = mix(FROST1, DEEP_BLUE, min(cp * 1.0, 0.55));
    if (n > N_SINGULAR) {
        float s = (n - N_SINGULAR) / (1.0 - N_SINGULAR);
        tint = mix(tint, HOT_CORE, s * 0.4);
    }

    vec3 fx = tint * ring1
            + ring2
            + ring3
            + mix(FROST1, WHITE, 0.5) * sparks
            + mix(FROST0, HOT_CORE, cp * 0.3) * glow
            + HOT_CORE * singularity
            + FROST1 * afterimage;

    float total = ring1 + dot(ring2, vec3(0.33))
                + r3v * R3_I * en + sparks + glow + singularity + afterimage;

    vec3 result = mix(orig.rgb, orig.rgb + fx, smoothstep(0.0, 0.002, total));
    fragColor = vec4(result, orig.a);
}
