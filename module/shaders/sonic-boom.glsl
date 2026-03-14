// Sonic Boom — dual-ring burst with chromatic aurora on cursor arrival
//
// When the cursor settles at a new position, two concentric ripple rings
// emanate outward at different speeds — a fast bright inner ring and a
// slower outer ghost ring.  Each ring has subtle chromatic separation
// (red/blue shift) for a prismatic edge effect.  A brief radial flash
// pulses at the origin on impact.
//
// Coordinate convention (Ghostty shadertoy_prefix.glsl):
//   iCurrentCursor.xy  = top-left of cursor cell (GL coords)
//   iCurrentCursor.zw  = cell width, height
//   iTimeCursorChange  = time when cursor last moved

// ─── Colors (Nord frost + aurora) ──────────────────────────────────
const vec3  RING1_COLOR   = vec3(0.53, 0.75, 0.98);  // Nord frost8
const vec3  RING2_COLOR   = vec3(0.56, 0.74, 0.73);  // Nord frost7 (teal)
const vec3  FLASH_COLOR   = vec3(0.80, 0.94, 1.0);   // near-white cyan

// ─── Ring 1 (fast, bright) ─────────────────────────────────────────
const float R1_INTENSITY  = 0.22;
const float R1_WIDTH      = 5.0;
const float R1_SPEED      = 220.0;   // px/sec

// ─── Ring 2 (slow, ghostly) ────────────────────────────────────────
const float R2_INTENSITY  = 0.10;
const float R2_WIDTH      = 8.0;
const float R2_SPEED      = 120.0;   // px/sec
const float R2_DELAY      = 0.04;    // seconds after ring 1

// ─── Impact flash ──────────────────────────────────────────────────
const float FLASH_INTENSITY = 0.30;
const float FLASH_RADIUS    = 18.0;   // pixels
const float FLASH_DURATION  = 0.12;   // seconds

// ─── Chromatic shift ───────────────────────────────────────────────
const float CHROMA_SHIFT  = 3.0;     // pixel offset for red/blue channels

// ─── Timing ────────────────────────────────────────────────────────
const float RING_DURATION = 0.50;    // total animation time (seconds)
const float MIN_DELAY     = 0.03;    // debounce: ignore first 30ms
const float FADE_POWER    = 2.0;     // fade-out curve steepness

// ─── Helpers ───────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

float ringShape(float dist, float radius, float width) {
    float d = abs(dist - radius);
    return exp(-0.5 * (d * d) / (width * width));
}

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 original = texture(iChannel0, fragCoord / iResolution.xy);

    float elapsed = iTime - iTimeCursorChange;

    // Skip during debounce and after animation
    if (elapsed < MIN_DELAY || elapsed > RING_DURATION + MIN_DELAY + R2_DELAY) {
        fragColor = original;
        return;
    }

    vec2 center = cursorCenter(iCurrentCursor);
    vec2 delta = fragCoord - center;
    float dist = length(delta);
    float t1 = elapsed - MIN_DELAY;
    float r1Radius = t1 * R1_SPEED;
    float fade1 = 1.0 - pow(clamp(t1 / RING_DURATION, 0.0, 1.0), FADE_POWER);

    // ── Impact flash (brief radial burst) ──
    float flashT = t1 / FLASH_DURATION;
    float flash = 0.0;
    if (flashT > 0.0 && flashT < 1.0) {
        flash = FLASH_INTENSITY * smoothstep(FLASH_RADIUS, 0.0, dist)
              * (1.0 - flashT * flashT);
    }

    // ── Ring 1 (fast, bright) ──
    float ring1 = ringShape(dist, r1Radius, R1_WIDTH) * fade1 * R1_INTENSITY;

    // ── Ring 2 (delayed, slower) ──
    float t2 = elapsed - MIN_DELAY - R2_DELAY;
    float ring2 = 0.0;
    if (t2 > 0.0) {
        float r2Radius = t2 * R2_SPEED;
        float fade2 = 1.0 - pow(clamp(t2 / RING_DURATION, 0.0, 1.0), FADE_POWER);
        ring2 = ringShape(dist, r2Radius, R2_WIDTH) * fade2 * R2_INTENSITY;
    }

    // ── Chromatic fringe on ring 1 ──
    vec2 dir = dist > 0.5 ? normalize(delta) : vec2(0.0, 1.0);
    float chromaR = ringShape(length(fragCoord + dir * CHROMA_SHIFT - center), r1Radius, R1_WIDTH) * fade1;
    float chromaB = ringShape(length(fragCoord - dir * CHROMA_SHIFT - center), r1Radius, R1_WIDTH) * fade1;

    // Compose
    vec3 ringGlow = RING1_COLOR * ring1
                  + RING2_COLOR * ring2
                  + FLASH_COLOR * flash;

    // Prismatic edge: warm inner, cool outer
    ringGlow.r += chromaR * R1_INTENSITY * 0.15;
    ringGlow.b += chromaB * R1_INTENSITY * 0.15;

    float total = ring1 + ring2 + flash;
    vec3 result = original.rgb + ringGlow;
    result = mix(original.rgb, result, smoothstep(0.0, 0.003, total));

    fragColor = vec4(result, original.a);
}
