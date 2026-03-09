// Prompt Saber — thick lightsaber underline for shell prompts
//
// A glowing horizontal plasma beam that appears beneath the cursor's row
// when the terminal detects a shell prompt. Uses content-aware heuristics
// to distinguish prompts from TUI applications: in vim, htop, less, etc.
// the effect gracefully fades to zero — no visual artifacts.
//
// Detection: samples pixels to the right of the cursor. Shell prompts have
// empty background there; TUI apps fill the line with content. When there
// is not enough space to sample (cursor near right edge), the effect dims
// to a subtle fallback rather than guessing.
//
// Coordinate convention (from Ghostty shadertoy_prefix.glsl):
//   fragCoord and iCurrentCursor are in the SAME coordinate space.
//   iCurrentCursor.xy = top-left corner of cursor cell (GL coords: y=top edge)
//   iCurrentCursor.zw = width, height of cursor cell
//   NO Y-flip needed.

// ─── Saber palette (Nord frost) ────────────────────────────────────
const vec3 CORE_COLOR  = vec3(0.88, 0.97, 1.0);   // white-hot plasma center
const vec3 INNER_COLOR = vec3(0.53, 0.75, 0.93);   // frost blue containment
const vec3 OUTER_COLOR = vec3(0.25, 0.45, 0.82);   // deep blue ambient haze

// ─── Beam geometry ─────────────────────────────────────────────────
const float CORE_HALF   = 1.5;    // half-height of bright core (pixels)
const float INNER_HALF  = 6.0;    // half-height of inner glow
const float OUTER_HALF  = 18.0;   // half-height of outer haze
const float BEAM_OFFSET = 1.0;    // gap below cursor cell bottom edge (pixels)

// ─── Intensity ─────────────────────────────────────────────────────
const float CORE_INTENSITY  = 0.80;   // plasma core brightness
const float INNER_INTENSITY = 0.20;   // containment glow brightness
const float OUTER_INTENSITY = 0.035;  // ambient haze brightness

// ─── Cursor focal bloom ───────────────────────────────────────────
// Brighter spot under the cursor — the blade's active point.
const float FOCAL_RADIUS    = 40.0;   // horizontal spread (pixels)
const float FOCAL_INTENSITY = 0.12;   // extra brightness at cursor center

// ─── Pulse (lightsaber hum) ────────────────────────────────────────
const float PULSE_FREQ   = 1.2;    // primary hum frequency (Hz)
const float PULSE_AMOUNT = 0.07;   // intensity modulation depth
const float PULSE_DRIFT  = 0.35;   // secondary slow drift frequency (Hz)

// ─── Energy ripple (traveling brightness wave) ─────────────────────
const float RIPPLE_SPEED     = 1.8;   // phase speed (units/sec)
const float RIPPLE_SCALE     = 0.012; // spatial frequency (cycles/pixel)
const float RIPPLE_SHARPNESS = 3.0;   // exponent — higher = tighter pulses
const float RIPPLE_STRENGTH  = 0.15;  // brightness modulation depth

// ─── Edge taper ────────────────────────────────────────────────────
const float EDGE_TAPER = 60.0;    // horizontal fade at screen edges (pixels)

// ─── Prompt detection ──────────────────────────────────────────────
const int   DETECT_SAMPLES    = 8;     // points sampled right of cursor
const float DETECT_THRESHOLD  = 0.18;  // luminance below this = "empty" pixel
const float DETECT_MIN_EMPTY  = 0.55;  // fraction of samples that must be empty
const float DETECT_FALLBACK   = 0.5;   // confidence when right side is too narrow
const float DETECT_MIN_SPACE  = 3.0;   // minimum cell widths of space to attempt detection

// ─── Vertical asymmetry ───────────────────────────────────────────
// Outer haze extends slightly further downward (away from text) than
// upward (into the cursor row). 1.0 = symmetric, lower = more downward.
const float ASYM_FACTOR = 0.85;

// ─── Helpers ───────────────────────────────────────────────────────

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Organic shimmer — slow noise variation along the beam.
// Wraps time to keep hash input small, avoiding float precision loss
// after hours of uptime. 256 cycles ≈ 102s period, invisible repeat.
float shimmer(vec2 p, float t) {
    vec2 cell = floor(p * 0.08);
    float n = hash(cell + floor(mod(t * 2.5, 256.0)));
    return 0.93 + 0.07 * n;
}

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // ── Cursor geometry ──
    vec2 cursorPos = iCurrentCursor.xy;
    vec2 cellSize  = iCurrentCursor.zw;

    // Guard: bail on nonsensical cursor data
    if (cellSize.x < 1.0 || cellSize.y < 1.0) {
        fragColor = original;
        return;
    }

    // Beam Y: bottom edge of cursor cell, offset downward
    float beamY = cursorPos.y - cellSize.y - BEAM_OFFSET;
    float distY = abs(fragCoord.y - beamY);

    // ── Early exit: too far from beam vertically ──
    if (distY > OUTER_HALF * 1.5) {
        fragColor = original;
        return;
    }

    // ── Prompt detection ──
    // In a shell prompt, the space right of the cursor is empty background.
    // In TUI apps (vim, htop, less), the line is full of visible content.
    float cursorRightX = cursorPos.x + cellSize.x;
    float cursorMidY   = cursorPos.y - cellSize.y * 0.5;
    float rightSpace   = iResolution.x - cursorRightX;

    float promptConf = DETECT_FALLBACK;

    if (rightSpace > cellSize.x * DETECT_MIN_SPACE) {
        float emptyCount   = 0.0;
        float totalSampled = 0.0;

        for (int i = 1; i <= DETECT_SAMPLES; i++) {
            float sx = cursorRightX + rightSpace * float(i) / float(DETECT_SAMPLES + 1);
            vec2 suv = vec2(sx, cursorMidY) / iResolution.xy;

            if (suv.x > 0.0 && suv.x < 1.0 && suv.y > 0.0 && suv.y < 1.0) {
                if (luminance(texture(iChannel0, suv).rgb) < DETECT_THRESHOLD)
                    emptyCount += 1.0;
                totalSampled += 1.0;
            }
        }

        if (totalSampled > 0.0) {
            promptConf = smoothstep(
                DETECT_MIN_EMPTY - 0.1,
                DETECT_MIN_EMPTY + 0.1,
                emptyCount / totalSampled
            );
        }
    }

    if (promptConf < 0.01) {
        fragColor = original;
        return;
    }

    // ── Horizontal edge taper ──
    float edgeFade = smoothstep(0.0, EDGE_TAPER, fragCoord.x)
                   * smoothstep(0.0, EDGE_TAPER, iResolution.x - fragCoord.x);

    if (edgeFade < 0.001) {
        fragColor = original;
        return;
    }

    // ── Pulse (dual-frequency lightsaber hum) ──
    // Wrap phases to [0,1) to preserve float precision over hours of uptime.
    float pulse = 1.0
        + PULSE_AMOUNT * sin(mod(iTime * PULSE_FREQ, 1.0) * 6.2832)
        + PULSE_AMOUNT * 0.4 * sin(mod(iTime * PULSE_DRIFT, 1.0) * 6.2832 + 2.1);

    // ── Energy ripple: brightness wave traveling rightward ──
    float ripplePhase = fragCoord.x * RIPPLE_SCALE - mod(iTime * RIPPLE_SPEED, 100.0);
    float ripple = pow(0.5 + 0.5 * sin(ripplePhase * 6.2832), RIPPLE_SHARPNESS);
    float rippleBoost = 1.0 + RIPPLE_STRENGTH * ripple;

    // ── Organic shimmer ──
    float shim = shimmer(fragCoord, iTime);

    // ── Glow layers ──
    float totalGlow = 0.0;
    vec3 beamColor  = vec3(0.0);

    // Core — white-hot plasma
    float coreGlow = CORE_INTENSITY * smoothstep(CORE_HALF, 0.0, distY);
    beamColor += CORE_COLOR * coreGlow;
    totalGlow += coreGlow;

    // Inner containment — frost blue
    float innerGlow = INNER_INTENSITY * smoothstep(INNER_HALF, CORE_HALF * 0.3, distY);
    beamColor += INNER_COLOR * innerGlow;
    totalGlow += innerGlow;

    // Outer haze — deep blue, asymmetric gaussian falloff
    // Glow extends further downward (empty space) than upward (text).
    float effDistY = fragCoord.y < beamY ? distY * ASYM_FACTOR : distY;
    float outerGlow = OUTER_INTENSITY * exp(-3.0 * (effDistY * effDistY) / (OUTER_HALF * OUTER_HALF));
    beamColor += OUTER_COLOR * outerGlow;
    totalGlow += outerGlow;

    // Cursor focal bloom — brighter spot at the blade's active point
    float cursorCenterX = cursorPos.x + cellSize.x * 0.5;
    float dxCursor = abs(fragCoord.x - cursorCenterX);
    float focal = FOCAL_INTENSITY * exp(-2.0 * (dxCursor * dxCursor) / (FOCAL_RADIUS * FOCAL_RADIUS));
    float focalMask = smoothstep(INNER_HALF, 0.0, distY);
    beamColor += CORE_COLOR * focal * focalMask;
    totalGlow += focal * focalMask;

    // ── Apply modulations ──
    beamColor *= pulse * rippleBoost * shim * edgeFade * promptConf;
    totalGlow *= pulse * rippleBoost * edgeFade * promptConf;

    if (totalGlow < 0.001) {
        fragColor = original;
        return;
    }

    // ── Composite: additive blend with soft clamp ──
    vec3 finalColor = original.rgb + beamColor;

    // Soft clamp — prevent blow-out while preserving HDR feel
    finalColor = finalColor / (1.0 + totalGlow * 0.5);
    finalColor = mix(original.rgb, finalColor, smoothstep(0.0, 0.01, totalGlow));

    fragColor = vec4(finalColor, original.a);
}
