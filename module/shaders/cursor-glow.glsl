// Cursor Glow — soft lightsaber aura around a line cursor
//
// A clean frost-blue aura that hugs the cursor at all times.
// Shaped to match a vertical line cursor (beam), not a dot.
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
const float CORE_WIDTH   = 3.0;    // bright center (pixels from line)
const float INNER_WIDTH  = 10.0;   // mid bloom
const float OUTER_WIDTH  = 28.0;   // soft outer reach

// ─── Intensity ─────────────────────────────────────────────────────
const float CORE_INTENSITY  = 0.70;  // bright but not blown-out
const float INNER_INTENSITY = 0.12;  // gentle mid glow
const float OUTER_INTENSITY = 0.03;  // whisper-level haze

// ─── Pulse (slow breathing — one inhale per second) ────────────────
const float PULSE_FREQ   = 1.0;    // Hz
const float PULSE_AMOUNT = 0.04;   // very subtle modulation

// ─── Helpers ───────────────────────────────────────────────────────

// Cursor line: vertical segment from top to bottom of cell.
// Returns (x of line, y_top, y_bottom) for distance calculation.
// Uses a thin offset (1px) from the left edge to match beam cursor.
vec3 cursorLine(vec4 c) {
    float x = c.x + 1.0;       // 1px in from left edge of cell
    float y_top = c.y;          // top of cell
    float y_bot = c.y - c.w;   // bottom of cell (GL: y goes down)
    return vec3(x, y_top, y_bot);
}

// Distance from point to a vertical line segment.
float distToLine(vec2 p, vec3 line) {
    float x = line.x;
    float y_top = line.y;
    float y_bot = line.z;

    // Horizontal distance to the line
    float dx = abs(p.x - x);

    // Vertical: clamp to segment range, measure overshoot
    float dy = 0.0;
    if (p.y > y_top) dy = p.y - y_top;
    if (p.y < y_bot) dy = y_bot - p.y;

    return length(vec2(dx, dy));
}

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 original = texture(iChannel0, fragCoord / iResolution.xy);

    vec3 line = cursorLine(iCurrentCursor);
    float dist = distToLine(fragCoord, line);

    // Early exit — vast majority of pixels skip all math
    if (dist > OUTER_WIDTH) {
        fragColor = original;
        return;
    }

    // Breathing pulse — wrap phase to avoid float precision drift
    float phase = mod(iTime * PULSE_FREQ, 1.0) * 6.2832;
    float pulse = 1.0 + PULSE_AMOUNT * sin(phase);

    // Three-layer glow (smoothstep for clean falloff)
    float core  = CORE_INTENSITY  * smoothstep(CORE_WIDTH,  0.0, dist);
    float inner = INNER_INTENSITY * smoothstep(INNER_WIDTH, CORE_WIDTH * 0.5, dist);
    float outer = OUTER_INTENSITY * exp(-3.0 * (dist * dist) / (OUTER_WIDTH * OUTER_WIDTH));

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
