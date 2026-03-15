// Sonic Boom — shockwave with black-hole collapse
//
// When the cursor settles, a layered explosion unfolds then implodes:
//
//   EXPANSION (0–0.40s):
//     1. Impact flash — white burst at origin
//     2. Primary ring — fast, bright, pushes pixels outward
//     3. Secondary ring — chromatic split (RGB channels fan apart)
//     4. Ghost aurora ring — wide ethereal shimmer
//     5. Spark scatter — procedural embers fly outward
//
//   TURBULENCE (0.35–0.55s):
//     Rings reach maximum extent and begin to destabilize — edges
//     fracture with angular noise, intensity spikes violently,
//     ring widths become ragged and asymmetric.
//
//   COLLAPSE (0.50–0.95s):
//     A gravitational reversal — rings decelerate, halt, then
//     accelerate inward with increasing ferocity. UV distortion
//     inverts (pixels pulled toward center). Chromatic channels
//     compress. Sparks reverse course. Colors blueshift deeper.
//     The collapse starts slow (resistance) then goes exponential
//     like matter crossing an event horizon.
//
//   SINGULARITY (0.90–1.10s):
//     Everything converges to a point. Final implosion flash —
//     brighter than the original explosion. Brief aftershock
//     ripple, then silence.

// ─── Nord palette ────────────────────────────────────────────────────
const vec3  FROST0    = vec3(0.56, 0.74, 0.73);   // teal
const vec3  FROST1    = vec3(0.53, 0.75, 0.87);   // frost blue
const vec3  FROST2    = vec3(0.51, 0.63, 0.76);   // steel blue
const vec3  AURORA_G  = vec3(0.64, 0.75, 0.55);   // green
const vec3  AURORA_P  = vec3(0.71, 0.56, 0.68);   // purple
const vec3  WHITE     = vec3(0.93, 0.94, 0.96);   // ECEFF4
const vec3  DEEP_BLUE = vec3(0.28, 0.35, 0.52);   // gravitational blueshift

// ─── Ring parameters ───────────────────────────────────────────────
const float R1_MAX_RADIUS = 120.0;   // peak expansion distance
const float R1_WIDTH      = 4.5;
const float R1_INTENSITY  = 0.28;
const float R1_DISTORT    = 6.0;     // UV displacement in pixels

const float R2_MAX_RADIUS = 85.0;
const float R2_WIDTH      = 7.0;
const float R2_INTENSITY  = 0.14;
const float R2_DELAY      = 0.035;
const float R2_CHROMA     = 4.5;     // RGB channel separation (px)

const float R3_MAX_RADIUS = 50.0;
const float R3_WIDTH      = 14.0;
const float R3_INTENSITY  = 0.06;
const float R3_DELAY      = 0.07;

// ─── Impact flash ──────────────────────────────────────────────────
const float FLASH_INTENSITY = 0.35;
const float FLASH_RADIUS    = 22.0;
const float FLASH_DURATION  = 0.10;

// ─── Spark scatter ─────────────────────────────────────────────────
const float SPARK_COUNT     = 24.0;
const float SPARK_INTENSITY = 0.50;
const float SPARK_SIZE      = 2.8;
const float SPARK_MAX_DIST  = 100.0;  // peak spark distance
const float SPARK_SPREAD    = 0.7;
const float SPARK_FADE      = 2.5;

// ─── Afterglow ─────────────────────────────────────────────────────
const float GLOW_RADIUS     = 30.0;
const float GLOW_INTENSITY  = 0.08;

// ─── Singularity implosion ─────────────────────────────────────────
const float IMPLODE_FLASH   = 0.55;   // brighter than original flash
const float IMPLODE_RADIUS  = 14.0;
const float IMPLODE_DISTORT = 10.0;   // stronger inward pull

// ─── Phase timing ──────────────────────────────────────────────────
const float TOTAL_DURATION    = 1.10;
const float EXPANSION_END     = 0.40;  // rings reach peak
const float TURBULENCE_ONSET  = 0.32;  // edges start fracturing
const float COLLAPSE_START    = 0.48;  // reversal begins
const float SINGULARITY_START = 0.90;  // final convergence
const float MIN_DELAY         = 0.025;

// ─── Helpers ───────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

float ringShape(float dist, float radius, float width) {
    float d = abs(dist - radius);
    return exp(-0.5 * (d * d) / (width * width));
}

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// ─── Phase curve: expansion → peak → collapse ─────────────────────
// Returns 0.0 at start, 1.0 at peak, 0.0 at singularity.
// Expansion: fast start, ease-out deceleration (momentum).
// Collapse: slow start (resistance), then cubic acceleration (gravity wins).

float phaseCurve(float t) {
    float norm = t / TOTAL_DURATION;

    if (norm < EXPANSION_END / TOTAL_DURATION) {
        // Expansion: quadratic ease-out
        float ep = norm / (EXPANSION_END / TOTAL_DURATION);
        return 1.0 - (1.0 - ep) * (1.0 - ep);
    }

    float collapseNorm = COLLAPSE_START / TOTAL_DURATION;
    if (norm < collapseNorm) {
        // Turbulent peak: hovering at max, barely moving
        return 1.0;
    }

    // Collapse: cubic ease-in (slow → fast, like gravitational acceleration)
    float cp = (norm - collapseNorm) / (1.0 - collapseNorm);
    cp = clamp(cp, 0.0, 1.0);
    return 1.0 - cp * cp * cp;
}

// ─── Turbulence factor: 0 during clean expansion, peaks at collapse ──
float turbulence(float t, float angle) {
    float norm = t / TOTAL_DURATION;

    // Onset: smoothstep from turbulence onset through collapse
    float turb = smoothstep(
        TURBULENCE_ONSET / TOTAL_DURATION,
        COLLAPSE_START / TOTAL_DURATION,
        norm
    );

    // Peaks at mid-collapse, subsides at singularity
    float collapse_progress = (norm - COLLAPSE_START / TOTAL_DURATION)
                            / (1.0 - COLLAPSE_START / TOTAL_DURATION);
    collapse_progress = clamp(collapse_progress, 0.0, 1.0);

    // Violence peaks at ~70% through collapse, then singularity swallows it
    float violence = turb * (1.0 - smoothstep(0.7, 1.0, collapse_progress));

    // Angular fracture — ring edges break apart non-uniformly
    float fracture = sin(angle * 7.0 + t * 15.0) * 0.5
                   + sin(angle * 13.0 - t * 23.0) * 0.3
                   + sin(angle * 19.0 + t * 37.0) * 0.2;

    return violence * fracture;
}

// ─── Collapse intensity: gets more extreme as things compress ──────
float collapseIntensity(float t) {
    float norm = t / TOTAL_DURATION;
    if (norm < COLLAPSE_START / TOTAL_DURATION) return 1.0;

    float cp = (norm - COLLAPSE_START / TOTAL_DURATION)
             / (1.0 - COLLAPSE_START / TOTAL_DURATION);
    cp = clamp(cp, 0.0, 1.0);

    // Intensity ramps up during collapse (energy compressing)
    return 1.0 + cp * cp * 2.0;  // up to 3x at singularity
}

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float elapsed = iTime - iTimeCursorChange;

    // Early exit
    if (elapsed < MIN_DELAY || elapsed > TOTAL_DURATION + MIN_DELAY + R3_DELAY) {
        fragColor = texture(iChannel0, fragCoord / iResolution.xy);
        return;
    }

    vec2 uv = fragCoord / iResolution.xy;
    vec2 center = cursorCenter(iCurrentCursor);
    vec2 delta = fragCoord - center;
    float dist = length(delta);
    vec2 dir = dist > 0.5 ? normalize(delta) : vec2(0.0, 1.0);
    float angle = atan(delta.y, delta.x);
    float t = elapsed - MIN_DELAY;
    float phase = phaseCurve(t);
    float cIntensity = collapseIntensity(t);
    float tNorm = t / TOTAL_DURATION;

    // Is the system collapsing?
    bool collapsing = tNorm > COLLAPSE_START / TOTAL_DURATION;

    // ── 1. Primary ring with UV distortion ──
    float r1Radius = phase * R1_MAX_RADIUS;

    // Turbulence warps the ring shape during fracture phase
    float turb1 = turbulence(t, angle);
    float r1Effective = r1Radius + turb1 * 12.0 * smoothstep(0.3, 0.6, tNorm);
    float r1Width = R1_WIDTH + abs(turb1) * 6.0 * smoothstep(0.3, 0.7, tNorm);

    float r1Shape = ringShape(dist, max(r1Effective, 0.0), r1Width);

    // UV distortion: outward during expansion, INWARD during collapse
    float distortDir = collapsing ? -1.0 : 1.0;
    float distortStrength = collapsing
        ? R1_DISTORT * cIntensity * 0.7  // stronger pull during collapse
        : R1_DISTORT;
    float distortAmount = r1Shape * distortStrength / iResolution.x * distortDir;

    // During collapse, add radial pull even outside the ring (gravitational lensing)
    float gravPull = 0.0;
    if (collapsing && dist > 1.0) {
        float cp = clamp((tNorm - COLLAPSE_START / TOTAL_DURATION)
                  / (1.0 - COLLAPSE_START / TOTAL_DURATION), 0.0, 1.0);
        gravPull = -IMPLODE_DISTORT * cp * cp * cp / (dist * 0.08) / iResolution.x;
        gravPull *= smoothstep(R1_MAX_RADIUS * 1.5, 0.0, dist);  // falloff
    }

    vec2 distortedUV = uv + dir * (distortAmount + gravPull);
    distortedUV = clamp(distortedUV, vec2(0.0), vec2(1.0));
    vec4 original = texture(iChannel0, distortedUV);

    float ring1 = r1Shape * R1_INTENSITY * cIntensity;

    // ── 2. Chromatic ring ──
    float t2 = t - R2_DELAY;
    vec3 ring2Color = vec3(0.0);
    if (t2 > 0.0) {
        float r2Radius = phase * R2_MAX_RADIUS;
        float turb2 = turbulence(t, angle + 1.0);
        float r2Effective = r2Radius + turb2 * 8.0 * smoothstep(0.3, 0.6, tNorm);

        // Chromatic: channels separate during expansion, COMPRESS during collapse
        float chromaDir = collapsing ? -1.0 : 1.0;
        float chromaAmount = R2_CHROMA * chromaDir * cIntensity;

        float rR = ringShape(length(delta + dir * chromaAmount), r2Effective, R2_WIDTH);
        float rG = ringShape(dist, r2Effective, R2_WIDTH);
        float rB = ringShape(length(delta - dir * chromaAmount), r2Effective, R2_WIDTH);

        ring2Color = vec3(rR * 0.8, rG, rB * 1.2) * R2_INTENSITY * cIntensity;
    }

    // ── 3. Ghost aurora ring ──
    float t3 = t - R3_DELAY;
    float ring3 = 0.0;
    vec3 ring3Color = vec3(0.0);
    if (t3 > 0.0) {
        float r3Radius = phase * R3_MAX_RADIUS;
        float turb3 = turbulence(t, angle + 2.0);
        float r3Effective = r3Radius + turb3 * 15.0 * smoothstep(0.25, 0.6, tNorm);
        float r3Width = R3_WIDTH + abs(turb3) * 10.0 * smoothstep(0.3, 0.7, tNorm);

        ring3 = ringShape(dist, max(r3Effective, 0.0), r3Width);

        // Aurora colors shift toward deep blue during collapse (gravitational blueshift)
        float hueT = fract(angle / 6.2832 + 0.5);
        vec3 auroraColor = mix(AURORA_G, AURORA_P, smoothstep(0.3, 0.7, hueT));
        auroraColor = mix(auroraColor, FROST0, smoothstep(0.7, 1.0, hueT));

        if (collapsing) {
            float blueshift = clamp((tNorm - COLLAPSE_START / TOTAL_DURATION)
                            / (1.0 - COLLAPSE_START / TOTAL_DURATION), 0.0, 1.0);
            auroraColor = mix(auroraColor, DEEP_BLUE, blueshift * 0.7);
        }

        ring3Color = auroraColor * ring3 * R3_INTENSITY * cIntensity;
    }

    // ── 4. Impact flash (expansion only) ──
    float flashT = t / FLASH_DURATION;
    float flash = 0.0;
    if (flashT > 0.0 && flashT < 1.0) {
        flash = FLASH_INTENSITY * smoothstep(FLASH_RADIUS, 0.0, dist)
              * (1.0 - flashT * flashT);
    }

    // ── 5. Spark scatter — reverse during collapse ──
    float sparks = 0.0;
    if (t > 0.0 && tNorm < SINGULARITY_START / TOTAL_DURATION) {
        float sparkPhase = phase;  // follows expansion/collapse curve
        float sparkFadeGlobal = 1.0 - smoothstep(
            0.7, SINGULARITY_START / TOTAL_DURATION, tNorm);

        for (float i = 0.0; i < SPARK_COUNT; i += 1.0) {
            float seed = hash(i * 137.0 + 0.5);
            float sparkAngle = (i / SPARK_COUNT) * 6.2832 + seed * 1.5;
            float speedJitter = 1.0 + (seed - 0.5) * SPARK_SPREAD;
            float sparkRadius = sparkPhase * SPARK_MAX_DIST * speedJitter;

            // During collapse, sparks jitter violently
            if (collapsing) {
                float jitter = turbulence(t, sparkAngle) * 8.0;
                sparkRadius += jitter;
            }

            vec2 sparkPos = center + vec2(cos(sparkAngle), sin(sparkAngle))
                          * max(sparkRadius, 0.0);
            float sparkDist = length(fragCoord - sparkPos);

            float size = SPARK_SIZE * max(sparkPhase, 0.15);
            if (collapsing) {
                // Sparks get brighter and tighter as they compress
                size *= 0.6;
            }

            if (sparkDist < size * 3.0) {
                float spark = exp(-0.5 * sparkDist * sparkDist / (size * size));
                sparks += spark * sparkFadeGlobal * SPARK_INTENSITY * cIntensity;
            }
        }
    }

    // ── 6. Afterglow — persists through expansion, rekindles at singularity ──
    float afterglow = 0.0;
    {
        // Expansion afterglow
        float glowExp = GLOW_INTENSITY * smoothstep(GLOW_RADIUS, 0.0, dist)
                      * (1.0 - smoothstep(0.0, 0.35, tNorm));

        // Collapse rekindle — glow intensifies as energy compresses back
        float glowCollapse = 0.0;
        if (collapsing) {
            float cp = clamp((tNorm - COLLAPSE_START / TOTAL_DURATION)
                     / (1.0 - COLLAPSE_START / TOTAL_DURATION), 0.0, 1.0);
            glowCollapse = GLOW_INTENSITY * 2.5 * cp * cp
                         * smoothstep(GLOW_RADIUS * (1.0 - cp * 0.7), 0.0, dist);
        }
        afterglow = glowExp + glowCollapse;
    }

    // ── 7. Singularity implosion flash ──
    float implode = 0.0;
    float implodeDistort = 0.0;
    if (tNorm > SINGULARITY_START / TOTAL_DURATION) {
        float sp = (tNorm - SINGULARITY_START / TOTAL_DURATION)
                 / (1.0 - SINGULARITY_START / TOTAL_DURATION);
        sp = clamp(sp, 0.0, 1.0);

        // Flash peaks at sp=0.5 then fades
        float flashCurve = sp < 0.5 ? sp * 2.0 : 2.0 * (1.0 - sp);
        flashCurve *= flashCurve;  // sharpen

        float shrinkingRadius = IMPLODE_RADIUS * (1.0 - sp);
        implode = IMPLODE_FLASH * smoothstep(shrinkingRadius, 0.0, dist)
                * flashCurve;

        // Aftershock micro-ripple
        if (sp > 0.5) {
            float rippleT = (sp - 0.5) * 2.0;
            float rippleRadius = rippleT * 40.0;
            float ripple = ringShape(dist, rippleRadius, 2.0) * (1.0 - rippleT) * 0.08;
            implode += ripple;
        }
    }

    // ── Compose ──
    // Color shifts toward deeper blue during collapse
    vec3 ringTint = collapsing
        ? mix(FROST1, DEEP_BLUE, clamp((tNorm - 0.5) * 2.0, 0.0, 0.6))
        : FROST1;

    vec3 glow = ringTint * ring1
              + ring2Color
              + ring3Color
              + WHITE * flash
              + mix(FROST1, WHITE, 0.6) * sparks
              + mix(FROST0, AURORA_G, 0.3) * afterglow
              + WHITE * implode;

    float total = ring1 + (ring2Color.r + ring2Color.g + ring2Color.b) * 0.33
                + ring3 * R3_INTENSITY * cIntensity + flash + sparks
                + afterglow + implode;

    vec3 result = original.rgb + glow;
    result = mix(original.rgb, result, smoothstep(0.0, 0.003, total));

    fragColor = vec4(result, original.a);
}
