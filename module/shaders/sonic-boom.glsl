// Sonic Boom — expanding ring on cursor arrival
//
// When the cursor stops at a new position, a single gentle ripple
// ring emanates outward.  Very fast fade (~350ms).  During rapid
// typing the cursor keeps updating so no ring is visible — only
// when the cursor settles does the ring appear.
//
// Coordinate convention (Ghostty shadertoy_prefix.glsl):
//   iCurrentCursor.xy  = top-left of cursor cell (GL coords)
//   iCurrentCursor.zw  = cell width, height
//   iTimeCursorChange  = time when cursor last moved

// ─── Colors (Nord frost) ─────────────────────────────────────────
const vec3  RING_COLOR    = vec3(0.53, 0.75, 0.98);  // Nord frost8

// ─── Ring geometry ───────────────────────────────────────────────
const float RING_INTENSITY = 0.08;    // peak additive brightness
const float RING_WIDTH    = 4.0;     // ring thickness (pixels)
const float RING_SPEED    = 150.0;   // expansion speed (px/sec)
const float RING_DURATION = 0.35;    // total animation time (seconds)

// ─── Timing ──────────────────────────────────────────────────────
const float MIN_DELAY     = 0.06;    // debounce: ignore first 60ms
const float FADE_POWER    = 2.0;     // fade-out curve steepness

// ─── Helpers ─────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

// ─── Main ────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 original = texture(iChannel0, fragCoord / iResolution.xy);

    // Time since cursor last moved
    float elapsed = iTime - iTimeCursorChange;

    // Skip during debounce window and after animation ends
    if (elapsed < MIN_DELAY || elapsed > RING_DURATION + MIN_DELAY) {
        fragColor = original;
        return;
    }

    float t = elapsed - MIN_DELAY;
    vec2 center = cursorCenter(iCurrentCursor);
    float dist = length(fragCoord - center);

    // Expanding ring radius
    float ringRadius = t * RING_SPEED;

    // Early exit for pixels far from the ring
    if (abs(dist - ringRadius) > RING_WIDTH * 4.0) {
        fragColor = original;
        return;
    }

    // Ring shape — gaussian profile
    float ringDist = abs(dist - ringRadius);
    float ring = exp(-0.5 * (ringDist * ringDist) / (RING_WIDTH * RING_WIDTH));

    // Fade over time (power curve)
    float fade = 1.0 - pow(t / RING_DURATION, FADE_POWER);

    // Final ring intensity — additive blend
    float intensity = ring * fade * RING_INTENSITY;
    vec3 result = original.rgb + RING_COLOR * intensity;

    fragColor = vec4(result, original.a);
}
