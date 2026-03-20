// Cursor Trail — always-on lightsaber glow with trailing
//
// A concentrated light-blue aura that hugs a line cursor at all times,
// pulses with a slow lightsaber hum, and leaves a smooth fading trail
// when it moves. Shaped for a vertical beam cursor, not a dot.
//
// Coordinate convention (from Ghostty shadertoy_prefix.glsl):
//   fragCoord and iCurrentCursor are in the SAME coordinate space.
//   iCurrentCursor.xy = top-left corner of cursor cell (GL coords: x=left, y=top edge)
//   iCurrentCursor.zw = width, height of cursor cell
//   NO Y-flip needed.
//
// Shared functions: cursorCenter, hash21, shimmer, gaussian (see nord-common.glsl)

// ─── Constants ─────────────────────────────────────────────────────────
const float TAU = 6.2832;

// ─── Color Palette (Aura) ──────────────────────────────────────────────
const vec3 CORE_COLOR  = vec3(0.75, 0.92, 1.0);   // near-white cyan
const vec3 MID_COLOR   = vec3(0.45, 0.72, 1.0);   // light frost blue
const vec3 OUTER_COLOR = vec3(0.25, 0.50, 0.90);   // deeper blue haze

// ─── Aura Geometry (distance from line cursor) ─────────────────────────
const float CORE_WIDTH  = 3.0;    // tight bright core (pixels)
const float MID_WIDTH   = 10.0;   // close mid glow
const float OUTER_WIDTH = 22.0;   // compact outer haze

// ─── Aura Intensity ────────────────────────────────────────────────────
const float CORE_INTENSITY  = 0.95;  // concentrated core brightness
const float MID_INTENSITY   = 0.18;  // subtle mid ring
const float OUTER_INTENSITY = 0.03;  // barely-there outer haze

// ─── Pulse (lightsaber hum) ────────────────────────────────────────────
const float PULSE_FREQ   = 1.8;   // hum frequency (Hz)
const float PULSE_AMOUNT = 0.06;  // intensity modulation depth
const float PULSE_DRIFT  = 0.4;   // secondary slow drift frequency

// ─── Trail Parameters ──────────────────────────────────────────────────
const float TRAIL_DURATION  = 0.65;  // trail fade time (seconds)
const float TRAIL_WIDTH     = 8.0;   // thin trail saber width (pixels)
const float TRAIL_INTENSITY = 0.35;  // trail peak brightness
const float TRAIL_HEAD_BIAS = 0.85;  // head-to-tail brightness ratio

// ─── Smooth Follow ─────────────────────────────────────────────────────
// Controls how slowly the aura follows the cursor for saber-like rhythm.
const float FOLLOW_SPEED = 3.5;    // lower = slower/smoother following

// ─── Helpers ───────────────────────────────────────────────────────────

// Cursor center from iCurrentCursor/iPreviousCursor vec4.
vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

// Cursor as a vertical line segment (for beam cursor shape).
// Returns (x, y_top, y_bot).
vec3 cursorLine(vec4 c) {
    float x     = c.x + 1.0;      // 1px in from left edge
    float y_top = c.y;             // top of cell
    float y_bot = c.y - c.w;      // bottom of cell
    return vec3(x, y_top, y_bot);
}

// Distance from point to a vertical line segment.
float distToVertLine(vec2 p, vec3 line) {
    float dx = abs(p.x - line.x);
    float dy = 0.0;
    if (p.y > line.y) dy = p.y - line.y;
    if (p.y < line.z) dy = line.z - p.y;
    return length(vec2(dx, dy));
}

// Smooth ease-out for trail animation (cubic).
float easeOut(float t) {
    float inv = 1.0 - t;
    return 1.0 - inv * inv * inv;
}

// Slower ease-out for the aura follow — gives the lightsaber weight (quintic).
float easeOutSlow(float t) {
    float inv = 1.0 - t;
    return 1.0 - inv * inv * inv * inv * inv;
}

// Signed distance from point p to line segment (a, b), returns (dist, t).
vec2 sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float denom = dot(ba, ba);
    if (denom < 0.001) return vec2(length(pa), 0.5);
    float h = clamp(dot(pa, ba) / denom, 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Pseudo-random hash — vec2 in, float out.
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Organic spatial shimmer for glow variation.
float shimmer(vec2 p, float t) {
    vec2 cell = floor(p * 0.08);
    float n = hash21(cell + floor(mod(t * 3.0, 256.0)));
    return 0.85 + 0.15 * n;
}

// ─── Main ──────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // ── Cursor positions ──
    vec2 curCenter  = cursorCenter(iCurrentCursor);
    vec2 prevCenter = cursorCenter(iPreviousCursor);

    // ── Line cursor geometry (follows smooth position) ──
    float dt = iTime - iTimeCursorChange;
    float followT = 1.0 - exp(-FOLLOW_SPEED * dt);

    // Interpolate the cursor cell for smooth line following
    vec4 smoothCursor = mix(iPreviousCursor, iCurrentCursor, easeOutSlow(followT));
    vec3 line = cursorLine(smoothCursor);
    float dist = distToVertLine(fragCoord, line);

    // ── Early exit: too far from both aura and any possible trail ──
    float trailProgress = clamp(dt / TRAIL_DURATION, 0.0, 1.0);
    float moveDistance = length(curCenter - prevCenter);
    float maxReach = OUTER_WIDTH + moveDistance + TRAIL_WIDTH;
    if (dist > maxReach) {
        fragColor = original;
        return;
    }

    // ── Pulse modulation (lightsaber hum) ──
    float pulse = 1.0
        + PULSE_AMOUNT * sin(mod(iTime * PULSE_FREQ, 1.0) * TAU)
        + PULSE_AMOUNT * 0.5 * sin(mod(iTime * PULSE_DRIFT, 1.0) * TAU + 1.0);

    // ── Shimmer for organic feel ──
    float shim = shimmer(fragCoord, iTime);

    // ── Always-on line aura (centered on smooth-followed cursor line) ──
    float auraGlow = 0.0;
    vec3 auraColor = vec3(0.0);

    // Core layer — bright white-cyan
    float coreGlow = CORE_INTENSITY * smoothstep(CORE_WIDTH, 0.0, dist);
    auraColor += CORE_COLOR * coreGlow;
    auraGlow += coreGlow;

    // Mid layer — frost blue
    float midGlow = MID_INTENSITY * smoothstep(MID_WIDTH, CORE_WIDTH * 0.5, dist);
    auraColor += MID_COLOR * midGlow;
    auraGlow += midGlow;

    // Outer layer — deep blue haze, gaussian-ish falloff
    float outerFactor = exp(-2.5 * (dist * dist) / (OUTER_WIDTH * OUTER_WIDTH));
    float outerGlow = OUTER_INTENSITY * outerFactor;
    auraColor += OUTER_COLOR * outerGlow;
    auraGlow += outerGlow;

    // Apply pulse and shimmer
    auraColor *= pulse * shim;
    auraGlow *= pulse;

    // ── Trail glow (only while trail is active) ──
    vec3 trailColor = vec3(0.0);
    float trailGlow = 0.0;

    if (trailProgress < 1.0 && moveDistance > 1.0) {
        // Animated head/tail positions — slower easing for saber rhythm
        float headProg = easeOutSlow(min(trailProgress * 2.0, 1.0));
        vec2 headPos = mix(prevCenter, curCenter, headProg);

        float tailProg = easeOut(clamp((trailProgress - 0.15) * 1.8, 0.0, 1.0));
        vec2 tailPos = mix(prevCenter, curCenter, tailProg);

        // Distance from fragment to trail segment
        vec2 seg = sdSegment(fragCoord, tailPos, headPos);
        float distToTrail = seg.x;
        float trailParam = seg.y;  // 0 = tail, 1 = head

        // Spatial fade — sharp core with subtle glow fringe
        float spatialFade = smoothstep(TRAIL_WIDTH, 0.0, distToTrail);
        spatialFade *= spatialFade;  // sharpen falloff for concentrated saber edge

        if (spatialFade > 0.0) {
            // Temporal fade — trail fades over time
            float timeFade = 1.0 - easeOut(trailProgress);

            // Head-to-tail brightness gradient
            float headFade = mix(1.0 - TRAIL_HEAD_BIAS, 1.0, trailParam);

            float combinedFade = spatialFade * timeFade * headFade;

            // Trail color: blend from outer to mid color along the trail
            vec3 tColor = mix(OUTER_COLOR, MID_COLOR, trailParam);

            trailGlow = TRAIL_INTENSITY * combinedFade * pulse * shim;
            trailColor = tColor * trailGlow;
        }
    }

    // ── Composite ──
    float totalGlow = auraGlow + trailGlow;

    if (totalGlow < 0.001) {
        fragColor = original;
        return;
    }

    // Additive blend — glow on top of terminal content
    vec3 finalColor = original.rgb + auraColor + trailColor;

    // Soft clamp to prevent blow-out while preserving HDR feel
    finalColor = finalColor / (1.0 + totalGlow * 0.5);
    finalColor = mix(original.rgb, finalColor, smoothstep(0.0, 0.01, totalGlow));

    fragColor = vec4(finalColor, original.a);
}
