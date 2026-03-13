// Spotlight — soft cursor-centered reading lamp
//
// Gently dims areas far from the cursor, creating a subtle focus
// gradient that draws the eye to where you're working.  Works in
// all applications — shell, editors, TUIs.
//
// Coordinate convention (Ghostty shadertoy_prefix.glsl):
//   iCurrentCursor.xy  = top-left of cursor cell (GL coords)
//   iCurrentCursor.zw  = cell width, height
//   Center = xy + vec2(z*0.5, -w*0.5)

// ─── Geometry ────────────────────────────────────────────────────
const float INNER_RADIUS  = 250.0;   // full brightness zone (pixels)
const float OUTER_RADIUS  = 900.0;   // outer edge of dimming
const float DIM_AMOUNT    = 0.10;    // max dimming at screen edges (0-1)

// ─── Breathing ───────────────────────────────────────────────────
const float PULSE_FREQ    = 0.4;     // Hz (very slow)
const float PULSE_AMOUNT  = 0.02;    // subtle radius modulation

// ─── Helpers ─────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

// ─── Main ────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 original = texture(iChannel0, fragCoord / iResolution.xy);

    vec2 center = cursorCenter(iCurrentCursor);
    float dist = length(fragCoord - center);

    // Early exit — most pixels in the bright zone
    if (dist < INNER_RADIUS * 0.8) {
        fragColor = original;
        return;
    }

    // Breathing modulation on inner radius
    float phase = mod(iTime * PULSE_FREQ, 1.0) * 6.2832;
    float inner = INNER_RADIUS * (1.0 + PULSE_AMOUNT * sin(phase));

    // Smooth dimming gradient
    float dim = smoothstep(inner, OUTER_RADIUS, dist) * DIM_AMOUNT;

    fragColor = vec4(original.rgb * (1.0 - dim), original.a);
}
