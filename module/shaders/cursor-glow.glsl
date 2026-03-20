// Cursor Glow — vertical bar core + radial frost-blue aura
//
// A thin glowing bar (matching line-cursor aesthetic) at the cursor
// center, surrounded by a soft radial halo. The bar spans the full
// cell height. Two-layer radial bloom radiates outward from the bar.
// Slow 1Hz breathing pulse.
//
// Coordinate convention (Ghostty shadertoy_prefix.glsl):
//   iCurrentCursor.xy  = top-left of cursor cell (GL coords)
//   iCurrentCursor.zw  = cell width, height
//
// Shared functions: cursorCenter (see nord-common.glsl)

// ─── Constants ─────────────────────────────────────────────────────────
const float TAU = 6.2832;

// ─── Color Palette (Nord Frost) ────────────────────────────────────────
const vec3 BAR_COLOR   = vec3(0.80, 0.94, 1.0);   // near-white cyan
const vec3 INNER_COLOR = vec3(0.53, 0.75, 0.98);   // Nord frost8
const vec3 OUTER_COLOR = vec3(0.32, 0.55, 0.88);   // deeper frost blue

// ─── Bar Geometry ──────────────────────────────────────────────────────
const float BAR_HALF_WIDTH = 1.2;   // half-width of the bright bar (pixels)
const float BAR_SOFTNESS   = 2.5;   // horizontal falloff (pixels)

// ─── Halo Geometry ─────────────────────────────────────────────────────
const float INNER_RADIUS = 24.0;    // mid bloom
const float OUTER_RADIUS = 55.0;    // soft outer reach

// ─── Intensity ─────────────────────────────────────────────────────────
const float BAR_INTENSITY   = 0.55;  // bar brightness
const float INNER_INTENSITY = 0.14;  // gentle mid glow
const float OUTER_INTENSITY = 0.04;  // whisper-level haze

// ─── Pulse (slow breathing) ────────────────────────────────────────────
const float PULSE_FREQ   = 1.0;    // Hz
const float PULSE_AMOUNT = 0.06;   // subtle modulation

// ─── Helpers ───────────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

// ─── Main ──────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 original = texture(iChannel0, fragCoord / iResolution.xy);

    vec2 center = cursorCenter(iCurrentCursor);
    float dist = length(fragCoord - center);

    // Early exit — vast majority of pixels skip all math
    if (dist > OUTER_RADIUS) {
        fragColor = original;
        return;
    }

    // Cell vertical bounds (GL coords: y increases upward, origin top-left)
    float cellTop    = iCurrentCursor.y;
    float cellBottom = iCurrentCursor.y - iCurrentCursor.w;

    // Breathing pulse
    float phase = mod(iTime * PULSE_FREQ, 1.0) * TAU;
    float pulse = 1.0 + PULSE_AMOUNT * sin(phase);

    // ── Bar core: vertical line spanning cell height ──
    float dx = abs(fragCoord.x - center.x);
    float barMask = smoothstep(BAR_HALF_WIDTH + BAR_SOFTNESS, BAR_HALF_WIDTH, dx);
    // Clamp to cell height with soft edges
    float vertFade = smoothstep(cellBottom - 2.0, cellBottom + 2.0, fragCoord.y)
                   * smoothstep(cellTop + 2.0, cellTop - 2.0, fragCoord.y);
    float bar = BAR_INTENSITY * barMask * vertFade;

    // ── Radial halo ──
    float inner = INNER_INTENSITY * smoothstep(INNER_RADIUS, BAR_HALF_WIDTH * 2.0, dist);
    float outer = OUTER_INTENSITY * exp(-3.0 * (dist * dist) / (OUTER_RADIUS * OUTER_RADIUS));

    vec3 glow = BAR_COLOR   * bar
              + INNER_COLOR * inner
              + OUTER_COLOR * outer;

    float total = (bar + inner + outer) * pulse;
    glow *= pulse;

    // Additive blend with soft-clamp
    vec3 result = original.rgb + glow;
    result = result / (1.0 + total * 0.4);
    result = mix(original.rgb, result, smoothstep(0.0, 0.005, total));

    fragColor = vec4(result, original.a);
}
