// Sonic Boom — shockwave with gravitational collapse and nova aftermath
//
// EXPANSION  (0–0.40s)  Rings bloom outward, sparks scatter
// EXHAUSTION (0.35–0.50s) Rings thin and dim, energy draining away
// TURBULENCE (0.45–0.60s) Edges fracture, ring breathes erratically
// COLLAPSE   (0.55–0.95s) Gravitational reversal — sparks spiral inward,
//                          rings compress, heat shimmer distorts the air
// SINGULARITY(0.90–1.15s) Silent convergence, chromatic afterimage lingers
// GATHERING  (1.15–2.50s) Energy slowly accumulates at center
// INSTABILITY(2.50–3.50s) Gathered energy flickers, UV shakes, can't hold
// NOVA       (3.50–3.70s) Explosion — particles launched outward
// DRIFT      (3.70–8.00s) Particles coast to screen edges, slowly fading

// ─── Palette ───────────────────────────────────────────────────────
const vec3  FROST0    = vec3(0.56, 0.74, 0.73);
const vec3  FROST1    = vec3(0.53, 0.75, 0.87);
const vec3  AURORA_G  = vec3(0.64, 0.75, 0.55);
const vec3  AURORA_P  = vec3(0.71, 0.56, 0.68);
const vec3  AURORA_R  = vec3(0.75, 0.38, 0.42);
const vec3  WHITE     = vec3(0.93, 0.94, 0.96);
const vec3  DEEP_BLUE = vec3(0.28, 0.35, 0.52);
const vec3  HOT_CORE  = vec3(0.80, 0.88, 0.95);

// ─── Rings ─────────────────────────────────────────────────────────
const float R1_MAX = 130.0;   const float R1_W = 4.0;   const float R1_I = 0.22;
const float R2_MAX = 90.0;    const float R2_W = 6.0;   const float R2_I = 0.11;
const float R3_MAX = 55.0;    const float R3_W = 12.0;  const float R3_I = 0.05;
const float R1_DISTORT = 5.0;
const float R2_DELAY   = 0.04;   const float R2_CHROMA = 3.5;
const float R3_DELAY   = 0.08;

// ─── Particles ─────────────────────────────────────────────────────
const float SPARK_N = 20.0;     const float SPARK_I = 0.35;   const float SPARK_SZ = 2.2;
const float SPARK_DIST = 110.0; const float SPARK_SPREAD = 0.6;
const float DUST_N  = 8.0;      const float DUST_I  = 0.018;  const float DUST_SZ = 1.4;
const float GLOW_R  = 28.0;     const float GLOW_I  = 0.06;

// ─── Atmospheric ───────────────────────────────────────────────────
const float GRAV_DISTORT   = 8.0;
const float SHIMMER_AMP    = 1.2;
const float AFTERIMAGE_I   = 0.022;
const float AFTERIMAGE_SEP = 0.8;   // chromatic separation (px)

// ─── Phase timing (seconds, relative to cursor change) ─────────────
const float T_TOTAL   = 1.15;  const float T_DELAY   = 0.025;
const float T_EXPAND  = 0.40;  const float T_EXHAUST = 0.35;
const float T_TURB    = 0.45;  const float T_COLLAPSE = 0.55;
const float T_SINGULAR = 0.90;

// ─── Post-singularity timing (absolute seconds from T_DELAY) ──────
const float T_GATHER    = 1.15;
const float T_UNSTABLE  = 2.50;
const float T_NOVA      = 3.50;
const float T_DRIFT     = 3.70;
const float T_ANIM_END  = 8.00;

// ─── Nova parameters ──────────────────────────────────────────────
const float NOVA_N       = 45.0;    // drift particles
const float NOVA_V_MIN   = 60.0;    // min launch velocity px/s
const float NOVA_V_MAX   = 180.0;   // max launch velocity px/s
const float NOVA_DRAG    = 0.88;    // velocity retention per second (friction)
const float NOVA_FLASH_I = 0.35;    // center flash peak intensity
const float NOVA_RING_V  = 280.0;   // shockwave ring speed px/s
const float NOVA_RING_W  = 3.0;     // shockwave ring width
const float GATHER_WISPS = 5.0;     // orbiting energy wisps during gathering

#define N_EXPAND   (T_EXPAND   / T_TOTAL)
#define N_EXHAUST  (T_EXHAUST  / T_TOTAL)
#define N_TURB     (T_TURB     / T_TOTAL)
#define N_COLLAPSE (T_COLLAPSE / T_TOTAL)
#define N_SINGULAR (T_SINGULAR / T_TOTAL)

// ═══════════════════════════════════════════════════════════════════
// Primitives
// ═══════════════════════════════════════════════════════════════════

vec2  cursorCenter(vec4 c) { return c.xy + vec2(c.z * 0.5, -c.w * 0.5); }
float gaussian(float d, float w) { return exp(-0.5 * d * d / (w * w)); }
float ringAt(float d, float r, float w) { return gaussian(abs(d - r), w); }
float hash(float n) { return fract(sin(n) * 43758.5453123); }

// ═══════════════════════════════════════════════════════════════════
// Original phase system (expansion → singularity)
// ═══════════════════════════════════════════════════════════════════

float collapseProgress(float n) {
    return clamp((n - N_COLLAPSE) / (1.0 - N_COLLAPSE), 0.0, 1.0);
}

float singularityProgress(float n) {
    return clamp((n - N_SINGULAR) / (1.0 - N_SINGULAR), 0.0, 1.0);
}

// Radius: 0 → 1 → 0 (ease-out expand, cubic ease-in collapse)
float phaseCurve(float n) {
    if (n < N_EXPAND) { float e = n / N_EXPAND; return 1.0 - (1.0 - e) * (1.0 - e); }
    if (n < N_COLLAPSE) return 1.0;
    float c = collapseProgress(n);
    return 1.0 - c * c * c;
}

// Energy: drains at exhaustion, reignites during collapse
float energyEnvelope(float n) {
    float drain = 1.0 - 0.4 * smoothstep(N_EXHAUST, N_COLLAPSE, n)
                      * (1.0 - smoothstep(N_COLLAPSE, N_COLLAPSE + 0.08, n));
    float cp = collapseProgress(n);
    return drain * (1.0 + cp * cp * 1.5);
}

// Ring width loss at peak expansion (energy exhaustion)
float exhaustionThin(float n) {
    return mix(1.0, 0.6, smoothstep(N_EXHAUST, N_COLLAPSE, n)
                       * (1.0 - smoothstep(N_COLLAPSE, N_COLLAPSE + 0.1, n)));
}

// ═══════════════════════════════════════════════════════════════════
// Turbulence
// ═══════════════════════════════════════════════════════════════════

float fracture(float n, float t, float angle) {
    float onset = smoothstep(N_TURB, N_COLLAPSE + 0.1, n);
    float fade  = 1.0 - smoothstep(0.75, 1.0, collapseProgress(n));
    float wobble  = sin(angle * 3.0 + t * 8.0) * 0.4 + sin(angle * 5.0 - t * 12.0) * 0.3;
    float shatter = sin(angle * 11.0 + t * 19.0) * 0.35 + sin(angle * 17.0 - t * 31.0) * 0.25;
    return onset * fade * mix(wobble, wobble + shatter, smoothstep(N_TURB, N_COLLAPSE + 0.15, n));
}

float ringBreathe(float n, float t) {
    float turb = smoothstep(N_TURB, N_COLLAPSE, n)
               * (1.0 - smoothstep(N_COLLAPSE + 0.15, N_SINGULAR, n));
    return 1.0 + turb * 0.4 * (sin(t * 45.0) * 0.3 + sin(t * 67.0) * 0.2 + sin(t * 23.0) * 0.15);
}

float arcThickness(float angle, float t) {
    return 1.0 + 0.15 * sin(angle * 4.0 + t * 3.0) + 0.10 * sin(angle * 7.0 - t * 5.0);
}

void turbulentRing(float n, float t, float angle, inout float r, inout float w) {
    float f = fracture(n, t, angle);
    float ramp = smoothstep(0.28, 0.6, n);
    r += f * 14.0 * ramp;
    w += abs(f) * 5.0 * ramp;
    w *= arcThickness(angle, t);
}

// ═══════════════════════════════════════════════════════════════════
// Atmospheric effects
// ═══════════════════════════════════════════════════════════════════

// Heat shimmer — UV wobble in inter-ring space
vec2 heatShimmer(float n, float t, float dist, float ph, vec2 fc, vec2 res) {
    if (n <= N_TURB || n >= N_SINGULAR + 0.05) return vec2(0.0);
    float strength = smoothstep(N_TURB, N_COLLAPSE + 0.1, n)
                   * (1.0 - smoothstep(N_SINGULAR - 0.05, N_SINGULAR + 0.05, n));
    float zone = smoothstep(10.0, 30.0, dist)
               * smoothstep(R1_MAX * ph + 20.0, R1_MAX * ph - 10.0, dist);
    vec2 s = vec2(sin(fc.y * 0.08 + t * 11.0) + sin(fc.x * 0.06 - t * 7.0),
                  sin(fc.x * 0.07 + t * 9.0)  + sin(fc.y * 0.05 - t * 13.0));
    return s * SHIMMER_AMP * strength * zone / res;
}

// Aurora color blend with collapse blueshift
vec3 auroraColor(float angle, float t, float cp, bool col) {
    float hue = fract(angle / 6.2832 + 0.5 + t * 0.05);
    vec3 c = mix(AURORA_G, AURORA_P, smoothstep(0.25, 0.75, hue));
    c = mix(c, FROST0, smoothstep(0.75, 1.0, hue));
    if (col) c = mix(c, DEEP_BLUE, cp * 0.65);
    return c;
}

// Chromatic ghost ring — RGB channel separation
vec3 chromaticRing(float dist, float radius, float width, float sep, float fade) {
    return vec3(
        ringAt(dist - sep, radius, width) * 0.9,
        ringAt(dist,       radius, width),
        ringAt(dist + sep, radius, width) * 1.1
    ) * AFTERIMAGE_I * fade;
}

// Color temperature: frost → deep blue → hot white
vec3 phaseTint(float cp, float sp) {
    vec3 c = FROST1;
    if (cp > 0.0) c = mix(FROST1, DEEP_BLUE, min(cp, 0.55));
    if (sp > 0.0) c = mix(c, HOT_CORE, sp * 0.4);
    return c;
}

// ═══════════════════════════════════════════════════════════════════
// Post-singularity: gathering → instability → nova → drift
// ═══════════════════════════════════════════════════════════════════

// Per-event seed — different each cursor change
float eventSeed(float tCursorChange) {
    return fract(tCursorChange * 137.531 + 0.7);
}

// Gathering: slow energy buildup at center with orbiting wisps
float gatherGlow(float t, float dist) {
    float p = smoothstep(T_GATHER, T_UNSTABLE, t);
    float pulse = 1.0 + 0.15 * sin(t * 3.14 * mix(0.5, 4.0, p * p));
    return p * pulse * 0.12 * smoothstep(22.0, 0.0, dist);
}

// Gathering wisps — small bright dots orbiting tight around center
float gatherWisps(float t, float dist, vec2 fragCoord, vec2 ctr) {
    if (t < T_GATHER || t > T_NOVA) return 0.0;
    float p = smoothstep(T_GATHER, T_UNSTABLE, t);
    float acc = 0.0;
    for (float i = 0.0; i < GATHER_WISPS; i += 1.0) {
        float phase = (i / GATHER_WISPS) * 6.2832;
        float speed = mix(1.5, 6.0, p);
        float orbit = mix(18.0, 5.0, p * p);   // tighten as instability grows
        float a = phase + t * speed + sin(t * 2.3 + i * 1.7) * 0.4;
        vec2 wp = ctr + vec2(cos(a), sin(a)) * orbit;
        float wd = length(fragCoord - wp);
        if (wd < 6.0) acc += gaussian(wd, 1.2) * p * 0.20;
    }
    return acc;
}

// Instability: flicker multiplier + UV shake offset
float instabilityFlicker(float t, float ev) {
    if (t < T_UNSTABLE || t > T_NOVA + 0.1) return 1.0;
    float p = smoothstep(T_UNSTABLE, T_NOVA, t);
    // Hash-based flicker — frequency accelerates as instability grows
    float freq = mix(12.0, 45.0, p * p);
    float flick = hash(floor(t * freq) * 73.0 + ev * 1000.0);
    return mix(1.0, mix(0.3, 1.6, flick), p * 0.8);
}

vec2 instabilityShake(float t) {
    if (t < T_UNSTABLE || t > T_NOVA + 0.05) return vec2(0.0);
    float p = smoothstep(T_UNSTABLE, T_NOVA, t);
    float amp = p * p * 2.5;
    return vec2(sin(t * 67.0 + 1.0) + sin(t * 97.0), sin(t * 83.0) + sin(t * 113.0)) * amp;
}

// Nova flash — bright center burst
float novaFlash(float t, float dist) {
    if (t < T_NOVA || t > T_NOVA + 0.25) return 0.0;
    float rise = smoothstep(T_NOVA, T_NOVA + 0.04, t);
    float fall = 1.0 - smoothstep(T_NOVA + 0.04, T_NOVA + 0.25, t);
    return rise * fall * NOVA_FLASH_I * smoothstep(50.0, 0.0, dist);
}

// Nova shockwave ring — fast expanding ring
float novaRing(float t, float dist) {
    if (t < T_NOVA || t > T_NOVA + 0.8) return 0.0;
    float dt = t - T_NOVA;
    float radius = dt * NOVA_RING_V;
    float fade = 1.0 - smoothstep(0.0, 0.8, dt);
    return ringAt(dist, radius, NOVA_RING_W + dt * 4.0) * 0.15 * fade;
}

// Drift particles — launched at nova, coast outward with friction
vec3 driftParticles(float t, vec2 fragCoord, vec2 ctr, float ev, vec2 res) {
    if (t < T_NOVA) return vec3(0.0);
    float dt = t - T_NOVA;
    float fade = 1.0 - smoothstep(T_DRIFT, T_ANIM_END, t);
    if (fade <= 0.0) return vec3(0.0);

    // -ln(NOVA_DRAG) for friction integral
    float dragLog = -log(NOVA_DRAG);

    vec3 acc = vec3(0.0);
    for (float i = 0.0; i < NOVA_N; i += 1.0) {
        float s1 = hash(ev * 1000.0 + i * 73.0);    // angle
        float s2 = hash(ev * 2000.0 + i * 137.0);   // velocity
        float s3 = hash(ev * 3000.0 + i * 41.0);    // size
        float s4 = hash(ev * 4000.0 + i * 97.0);    // color hue
        float s5 = hash(ev * 5000.0 + i * 59.0);    // slight angle wobble

        float a = s1 * 6.2832 + s5 * 0.3;
        float vel = mix(NOVA_V_MIN, NOVA_V_MAX, s2);

        // Distance = integral of vel * drag^t from 0 to dt
        float friction_t = pow(NOVA_DRAG, dt);
        float traveled = vel * (1.0 - friction_t) / dragLog;

        // Slight curve — particles don't go perfectly straight
        float curve = sin(dt * 0.8 + s5 * 6.0) * 4.0 * s5;
        vec2 pos = ctr + vec2(cos(a), sin(a)) * traveled
                       + vec2(-sin(a), cos(a)) * curve;

        float pd = length(fragCoord - pos);
        float sz = mix(0.8, 2.2, s3);

        if (pd > sz * 5.0) continue;

        // Edge dissolve — fade as particles approach screen edge
        float edgeDist = min(min(pos.x, pos.y), min(res.x - pos.x, res.y - pos.y));
        float edgeFade = smoothstep(0.0, 50.0, edgeDist);

        // Brightness decays with friction (particles dim as they slow)
        float brightness = gaussian(pd, sz) * 0.22 * fade * edgeFade * max(friction_t, 0.15);

        // Color: per-particle random from palette
        vec3 color;
        if (s4 < 0.25)      color = FROST0;
        else if (s4 < 0.45) color = FROST1;
        else if (s4 < 0.65) color = AURORA_G;
        else if (s4 < 0.80) color = AURORA_P;
        else                 color = mix(WHITE, HOT_CORE, s4);

        acc += color * brightness;
    }
    return acc;
}

// ═══════════════════════════════════════════════════════════════════
// Main
// ═══════════════════════════════════════════════════════════════════

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float elapsed = iTime - iTimeCursorChange;
    if (elapsed < T_DELAY || elapsed > T_ANIM_END + T_DELAY + 0.5) {
        fragColor = texture(iChannel0, fragCoord / iResolution.xy);
        return;
    }

    // ── Geometry ─────────────────────────────────────────────────
    vec2  ctr   = cursorCenter(iCurrentCursor);
    vec2  d     = fragCoord - ctr;
    float dist  = length(d);
    vec2  dir   = dist > 0.5 ? normalize(d) : vec2(0.0, 1.0);
    float angle = atan(d.y, d.x);

    // ── Phase state ─────────────────────────────────────────────
    float t   = elapsed - T_DELAY;
    float n   = t / T_TOTAL;
    float ph  = phaseCurve(n);
    float en  = energyEnvelope(n);
    float cp  = collapseProgress(n);
    float sp  = singularityProgress(n);
    float br  = ringBreathe(n, t);
    bool  col = n > N_COLLAPSE;

    // Per-event randomization seed
    float ev = eventSeed(iTimeCursorChange);

    // ── UV distortion layers ────────────────────────────────────
    vec2 shimmer = heatShimmer(n, t, dist, ph, fragCoord, iResolution.xy);

    // Instability UV shake (post-singularity)
    vec2 shake = instabilityShake(t) / iResolution.xy;

    float r1r = ph * R1_MAX, r1w = R1_W;
    turbulentRing(n, t, angle, r1r, r1w);
    r1w *= exhaustionThin(n);
    float r1 = ringAt(dist, max(r1r, 0.0), r1w);

    float cDir    = col ? -1.0 : 1.0;
    float distStr = col ? R1_DISTORT * (1.0 + cp) * 0.6 : R1_DISTORT;
    float uvShift = r1 * distStr / iResolution.x * cDir;
    float grav    = 0.0;
    if (col && dist > 1.0) {
        grav  = -GRAV_DISTORT * cp * cp * cp / (dist * 0.1) / iResolution.x;
        grav *= smoothstep(R1_MAX * 1.4, 0.0, dist);
    }

    vec2 uv = fragCoord / iResolution.xy;
    vec4 orig = texture(iChannel0, clamp(uv + dir * (uvShift + grav) + shimmer + shake,
                                         vec2(0.0), vec2(1.0)));

    // ── Ring 1: primary ─────────────────────────────────────────
    float ring1 = r1 * R1_I * en * br;

    // ── Ring 2: chromatic ───────────────────────────────────────
    vec3 ring2 = vec3(0.0);
    if (t > R2_DELAY && t < T_GATHER) {
        float r2r = ph * R2_MAX, r2w = R2_W;
        turbulentRing(n, t, angle + 1.0, r2r, r2w);
        float chroma = R2_CHROMA * cDir * (1.0 + cp * 0.5);
        ring2 = vec3(ringAt(length(d + dir * chroma), r2r, r2w) * 0.85,
                     ringAt(dist, r2r, r2w),
                     ringAt(length(d - dir * chroma), r2r, r2w) * 1.15)
              * R2_I * en * br;
    }

    // ── Ring 3: aurora ──────────────────────────────────────────
    float r3v = 0.0;
    vec3  ring3 = vec3(0.0);
    if (t > R3_DELAY && t < T_GATHER) {
        float r3r = ph * R3_MAX, r3w = R3_W;
        float f3  = fracture(n, t, angle + 2.0);
        r3r += f3 * 16.0 * smoothstep(0.22, 0.55, n);
        r3w += abs(f3) * 8.0 * smoothstep(0.28, 0.65, n);
        r3w *= arcThickness(angle + 0.5, t);
        r3v  = ringAt(dist, max(r3r, 0.0), r3w);
        ring3 = auroraColor(angle, t, cp, col) * r3v * R3_I * en;
    }

    // ── Sparks ──────────────────────────────────────────────────
    float sparks = 0.0;
    if (t > 0.0 && n < N_SINGULAR + 0.05) {
        float sFade = 1.0 - smoothstep(0.7, N_SINGULAR, n);
        for (float i = 0.0; i < SPARK_N; i += 1.0) {
            float seed = hash(i * 137.0 + 0.5);
            float sa = (i / SPARK_N) * 6.2832 + seed * 1.5;
            float sr = ph * SPARK_DIST * (1.0 + (seed - 0.5) * SPARK_SPREAD);
            if (col) {
                sa += cp * cp * 2.5 * (seed > 0.5 ? 1.0 : -1.0);
                sr += fracture(n, t, sa) * 6.0;
            }
            float sd = length(fragCoord - ctr - vec2(cos(sa), sin(sa)) * max(sr, 0.0));
            float sz = SPARK_SZ * max(ph, 0.12) * (col ? 0.5 : 1.0);
            if (sd < sz * 3.0) sparks += gaussian(sd, sz) * sFade * SPARK_I * en;
        }
    }

    // ── Dust ────────────────────────────────────────────────────
    float dust = 0.0;
    if (t > 0.1 && n < 1.3) {
        float life = smoothstep(0.1, 0.25, n) * (1.0 - smoothstep(0.9, 1.3, n));
        for (float i = 0.0; i < DUST_N; i += 1.0) {
            float seed = hash(i * 73.0 + 11.0);
            float da = (i / DUST_N) * 6.2832 + seed * 3.0 + sin(t * 1.5 + seed * 10.0) * 0.3;
            float dr = t * 25.0 * (0.6 + seed * 0.8);
            float dd = length(fragCoord - ctr - vec2(cos(da), sin(da)) * dr);
            float sz = DUST_SZ * (0.8 + seed * 0.4);
            if (dd < sz * 3.0) dust += gaussian(dd, sz) * life * DUST_I;
        }
    }

    // ── Glow ────────────────────────────────────────────────────
    float glow = GLOW_I * smoothstep(GLOW_R, 0.0, dist) * (1.0 - smoothstep(0.0, 0.4, n));
    if (col) glow += GLOW_I * 3.0 * cp * cp * smoothstep(GLOW_R * (1.0 - cp * 0.8), 0.0, dist);

    // ── Singularity ─────────────────────────────────────────────
    float sing = (sp > 0.0) ? 0.3 * smoothstep(8.0 * (1.0 - sp * sp), 0.0, dist) * (1.0 - sp) : 0.0;

    // ── Afterimage ──────────────────────────────────────────────
    vec3 aiColor = vec3(0.0);
    float aiVal  = 0.0;

    if (n > 0.95 && t < T_GATHER + 0.3) {
        float fade = 1.0 - (n - 0.95) / 0.05;
        aiColor = chromaticRing(dist, 18.0 + (1.0 - fade) * 8.0, 6.0, AFTERIMAGE_SEP, fade);
        aiVal   = dot(aiColor, vec3(0.33));
    }
    float postN = (elapsed - T_DELAY) / T_TOTAL;
    if (postN > 1.0 && postN < 1.45) {
        float fade = 1.0 - (postN - 1.0) / 0.45;
        vec3 ext = chromaticRing(dist, 26.0 + (postN - 1.0) * 15.0, 8.0,
                                 AFTERIMAGE_SEP * 1.5, fade * fade) * 0.5;
        aiColor += ext;
        aiVal   += dot(ext, vec3(0.33));
    }

    // ── Post-singularity: gathering + instability ────────────────
    float gather  = gatherGlow(t, dist);
    float wisps   = gatherWisps(t, dist, fragCoord, ctr);
    float flicker = instabilityFlicker(t, ev);
    float flash   = novaFlash(t, dist);
    float nRing   = novaRing(t, dist);

    // Apply flicker to gathering effects
    gather *= flicker;
    wisps  *= flicker;

    // ── Drift particles ─────────────────────────────────────────
    vec3 drift = driftParticles(t, fragCoord, ctr, ev, iResolution.xy);

    // ── Compose ─────────────────────────────────────────────────
    // Fade original phases out after singularity so gathering starts clean
    float origFade = 1.0 - smoothstep(T_GATHER, T_GATHER + 0.3, t);

    vec3 tint = phaseTint(cp, sp);
    vec3 fx   = (tint * ring1
              + ring2 + ring3
              + mix(FROST1, WHITE, 0.5) * sparks
              + FROST1 * dust
              + mix(FROST0, HOT_CORE, cp * 0.3) * glow
              + HOT_CORE * sing
              + aiColor) * origFade
              + HOT_CORE * gather
              + WHITE * wisps
              + WHITE * flash
              + FROST1 * nRing
              + drift;

    float total = (ring1 + dot(ring2, vec3(0.33)) + r3v * R3_I * en
                + sparks + dust + glow + sing + aiVal) * origFade
                + gather + wisps + flash + nRing + dot(drift, vec3(0.33));

    fragColor = vec4(mix(orig.rgb, orig.rgb + fx, smoothstep(0.0, 0.002, total)), orig.a);
}
