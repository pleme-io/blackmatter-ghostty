// Cursor Glow — soft lightsaber halo around the cursor
//
// A clean frost-blue aura that sits on the cursor at all times.
// No prompt detection, no trail math — works identically in every
// application (shell, vim, htop, TUI).  Bright white-cyan core
// with a soft gaussian bloom that fades to deep frost blue.
//
// Coordinate convention (Ghostty shadertoy_prefix.glsl):
//   iCurrentCursor.xy  = top-left of cursor cell (GL coords)
//   iCurrentCursor.zw  = cell width, height
//   Center = xy + vec2(z*0.5, -w*0.5)

// ─── Color palette (Nord frost) ────────────────────────────────────
const vec3 CORE_COLOR  = vec3(0.80, 0.94, 1.0);   // near-white cyan
const vec3 INNER_COLOR = vec3(0.53, 0.75, 0.98);   // Nord frost8
const vec3 OUTER_COLOR = vec3(0.32, 0.55, 0.88);   // deeper frost blue

// ─── Geometry ──────────────────────────────────────────────────────
const float CORE_RADIUS  = 6.0;    // bright center (pixels)
const float INNER_RADIUS = 18.0;   // mid bloom
const float OUTER_RADIUS = 42.0;   // soft outer reach

// ─── Intensity ─────────────────────────────────────────────────────
const float CORE_INTENSITY  = 0.70;  // bright but not blown-out
const float INNER_INTENSITY = 0.12;  // gentle mid glow
const float OUTER_INTENSITY = 0.03;  // whisper-level haze

// ─── Pulse (slow breathing — one inhale per second) ────────────────
const float PULSE_FREQ   = 1.0;    // Hz
const float PULSE_AMOUNT = 0.04;   // very subtle modulation

// ─── Helpers ───────────────────────────────────────────────────────

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 original = texture(iChannel0, fragCoord / iResolution.xy);

    vec2 center = cursorCenter(iCurrentCursor);
    float dist = length(fragCoord - center);

    // Early exit — vast majority of pixels skip all math
    if (dist > OUTER_RADIUS) {
        fragColor = original;
        return;
    }

    // Breathing pulse — wrap phase to avoid float precision drift
    float phase = mod(iTime * PULSE_FREQ, 1.0) * 6.2832;
    float pulse = 1.0 + PULSE_AMOUNT * sin(phase);

    // Three-layer radial glow (smoothstep for clean falloff)
    float core  = CORE_INTENSITY  * smoothstep(CORE_RADIUS,  0.0, dist);
    float inner = INNER_INTENSITY * smoothstep(INNER_RADIUS, CORE_RADIUS * 0.5, dist);
    float outer = OUTER_INTENSITY * exp(-3.0 * (dist * dist) / (OUTER_RADIUS * OUTER_RADIUS));

    vec3 glow = CORE_COLOR  * core
              + INNER_COLOR * inner
              + OUTER_COLOR * outer;

    float total = (core + inner + outer) * pulse;
    glow *= pulse;

    // Additive blend with soft-clamp to prevent blow-out
    vec3 result = original.rgb + glow;
    result = result / (1.0 + total * 0.4);
    result = mix(original.rgb, result, smoothstep(0.0, 0.005, total));

    fragColor = vec4(result, original.a);
}
