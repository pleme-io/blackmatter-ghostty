// Sonic Boom — shockwave distortion + spark scatter + triple aurora rings
//
// When the cursor settles, a layered explosion unfolds:
//   1. Impact flash with radial UV distortion (text warps outward briefly)
//   2. Primary ring — fast, bright, bends the screen as it passes
//   3. Secondary ring — slower, chromatic split (RGB channels fan apart)
//   4. Tertiary ghost ring — slowest, wide, ethereal
//   5. Spark scatter — procedural noise creates tiny bright dots that
//      fly outward from the impact, like embers from a struck anvil
//   6. Afterglow — brief warm radial tint that lingers at the origin
//
// Coordinate convention (Ghostty shadertoy_prefix.glsl):
//   iCurrentCursor.xy  = top-left of cursor cell (GL coords)
//   iCurrentCursor.zw  = cell width, height
//   iTimeCursorChange  = time when cursor last moved

// ─── Nord palette ────────────────────────────────────────────────────
const vec3  FROST0    = vec3(0.56, 0.74, 0.73);   // teal
const vec3  FROST1    = vec3(0.53, 0.75, 0.87);   // frost blue
const vec3  FROST2    = vec3(0.51, 0.63, 0.76);   // steel blue
const vec3  AURORA_G  = vec3(0.64, 0.75, 0.55);   // green (A3BE8C)
const vec3  AURORA_P  = vec3(0.71, 0.56, 0.68);   // purple (B48EAD)
const vec3  WHITE     = vec3(0.93, 0.94, 0.96);   // ECEFF4

// ─── Ring 1 — primary shockwave ──────────────────────────────────────
const float R1_SPEED      = 260.0;
const float R1_WIDTH      = 4.5;
const float R1_INTENSITY  = 0.28;
const float R1_DISTORT    = 6.0;    // UV displacement in pixels

// ─── Ring 2 — chromatic split ────────────────────────────────────────
const float R2_SPEED      = 150.0;
const float R2_WIDTH      = 7.0;
const float R2_INTENSITY  = 0.14;
const float R2_DELAY      = 0.035;
const float R2_CHROMA     = 4.5;    // RGB channel separation (px)

// ─── Ring 3 — ghost aurora ───────────────────────────────────────────
const float R3_SPEED      = 80.0;
const float R3_WIDTH      = 14.0;
const float R3_INTENSITY  = 0.06;
const float R3_DELAY      = 0.07;

// ─── Impact flash ────────────────────────────────────────────────────
const float FLASH_INTENSITY = 0.35;
const float FLASH_RADIUS    = 22.0;
const float FLASH_DURATION  = 0.10;

// ─── Spark scatter ───────────────────────────────────────────────────
const float SPARK_COUNT     = 24.0;   // angular density
const float SPARK_INTENSITY = 0.50;
const float SPARK_SIZE      = 2.8;    // px radius per spark
const float SPARK_SPEED     = 200.0;  // radial expansion speed
const float SPARK_SPREAD    = 0.7;    // radial jitter factor
const float SPARK_FADE      = 2.5;    // fade power

// ─── Afterglow ───────────────────────────────────────────────────────
const float GLOW_RADIUS     = 30.0;
const float GLOW_INTENSITY  = 0.08;
const float GLOW_DURATION   = 0.35;

// ─── Timing ──────────────────────────────────────────────────────────
const float TOTAL_DURATION  = 0.65;
const float MIN_DELAY       = 0.025;
const float FADE_POWER      = 2.0;

// ─── Helpers ─────────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

float ringShape(float dist, float radius, float width) {
    float d = abs(dist - radius);
    return exp(-0.5 * (d * d) / (width * width));
}

// Fast pseudo-random hash (good enough for procedural sparks)
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ─── Main ────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    float elapsed = iTime - iTimeCursorChange;

    // Early exit — skip math for vast majority of frames
    if (elapsed < MIN_DELAY || elapsed > TOTAL_DURATION + MIN_DELAY + R3_DELAY) {
        fragColor = texture(iChannel0, fragCoord / iResolution.xy);
        return;
    }

    vec2 uv = fragCoord / iResolution.xy;
    vec2 center = cursorCenter(iCurrentCursor);
    vec2 delta = fragCoord - center;
    float dist = length(delta);
    vec2 dir = dist > 0.5 ? normalize(delta) : vec2(0.0, 1.0);
    float t = elapsed - MIN_DELAY;

    // ── 1. Primary ring with UV distortion ──
    float r1Radius = t * R1_SPEED;
    float fade1 = 1.0 - pow(clamp(t / TOTAL_DURATION, 0.0, 1.0), FADE_POWER);
    float r1Shape = ringShape(dist, r1Radius, R1_WIDTH);

    // Distort UVs — push pixels outward as the ring passes through
    float distortAmount = r1Shape * fade1 * R1_DISTORT / iResolution.x;
    vec2 distortedUV = uv + dir * distortAmount;
    vec4 original = texture(iChannel0, distortedUV);

    float ring1 = r1Shape * fade1 * R1_INTENSITY;

    // ── 2. Chromatic ring — sample R/G/B at offset positions ──
    float t2 = t - R2_DELAY;
    vec3 ring2Color = vec3(0.0);
    if (t2 > 0.0) {
        float r2Radius = t2 * R2_SPEED;
        float fade2 = 1.0 - pow(clamp(t2 / TOTAL_DURATION, 0.0, 1.0), FADE_POWER);

        float rR = ringShape(length(delta + dir * R2_CHROMA), r2Radius, R2_WIDTH);
        float rG = ringShape(dist, r2Radius, R2_WIDTH);
        float rB = ringShape(length(delta - dir * R2_CHROMA), r2Radius, R2_WIDTH);

        ring2Color = vec3(rR * 0.8, rG, rB * 1.2) * fade2 * R2_INTENSITY;
    }

    // ── 3. Ghost aurora ring — wide, colored, ethereal ──
    float t3 = t - R3_DELAY;
    float ring3 = 0.0;
    vec3 ring3Color = vec3(0.0);
    if (t3 > 0.0) {
        float r3Radius = t3 * R3_SPEED;
        float fade3 = 1.0 - pow(clamp(t3 / TOTAL_DURATION, 0.0, 1.0), FADE_POWER);
        ring3 = ringShape(dist, r3Radius, R3_WIDTH) * fade3;

        // Rotate hue around the ring — aurora effect
        float angle = atan(delta.y, delta.x);
        float hueT = fract(angle / 6.2832 + 0.5);
        vec3 auroraColor = mix(AURORA_G, AURORA_P, smoothstep(0.3, 0.7, hueT));
        auroraColor = mix(auroraColor, FROST0, smoothstep(0.7, 1.0, hueT));
        ring3Color = auroraColor * ring3 * R3_INTENSITY;
    }

    // ── 4. Impact flash ──
    float flashT = t / FLASH_DURATION;
    float flash = 0.0;
    if (flashT > 0.0 && flashT < 1.0) {
        flash = FLASH_INTENSITY * smoothstep(FLASH_RADIUS, 0.0, dist)
              * (1.0 - flashT * flashT);
    }

    // ── 5. Spark scatter — procedural flying embers ──
    float sparks = 0.0;
    if (t > 0.0 && t < TOTAL_DURATION * 0.8) {
        float sparkFade = 1.0 - pow(t / (TOTAL_DURATION * 0.8), SPARK_FADE);

        for (float i = 0.0; i < SPARK_COUNT; i += 1.0) {
            // Each spark has a unique angle and speed jitter
            float seed = hash(i * 137.0 + 0.5);
            float angle = (i / SPARK_COUNT) * 6.2832 + seed * 1.5;
            float speedJitter = 1.0 + (seed - 0.5) * SPARK_SPREAD;
            float sparkRadius = t * SPARK_SPEED * speedJitter;

            // Spark position
            vec2 sparkPos = center + vec2(cos(angle), sin(angle)) * sparkRadius;
            float sparkDist = length(fragCoord - sparkPos);

            // Size shrinks over time
            float size = SPARK_SIZE * (1.0 - t / TOTAL_DURATION);

            if (sparkDist < size * 3.0) {
                float spark = exp(-0.5 * sparkDist * sparkDist / (size * size));
                sparks += spark * sparkFade * SPARK_INTENSITY;
            }
        }
    }

    // ── 6. Afterglow — warm tint at origin ──
    float afterglow = 0.0;
    if (t < GLOW_DURATION) {
        float glowFade = 1.0 - (t / GLOW_DURATION);
        afterglow = GLOW_INTENSITY * smoothstep(GLOW_RADIUS, 0.0, dist)
                  * glowFade * glowFade;
    }

    // ── Compose ──
    vec3 glow = FROST1 * ring1
              + ring2Color
              + ring3Color
              + WHITE * flash
              + mix(FROST1, WHITE, 0.6) * sparks
              + mix(FROST0, AURORA_G, 0.3) * afterglow;

    float total = ring1 + (ring2Color.r + ring2Color.g + ring2Color.b) * 0.33
                + ring3 * R3_INTENSITY + flash + sparks + afterglow;

    vec3 result = original.rgb + glow;
    result = mix(original.rgb, result, smoothstep(0.0, 0.003, total));

    fragColor = vec4(result, original.a);
}
