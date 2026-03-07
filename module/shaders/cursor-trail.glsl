// Cursor aura — always-on lightsaber glow with trailing
//
// A concentrated light-blue aura that hugs the cursor at all times, pulses
// with a slow lightsaber hum, and leaves a smooth fading trail when it moves.
//
// Coordinate convention (from Ghostty shadertoy_prefix.glsl):
//   fragCoord and iCurrentCursor are in the SAME coordinate space.
//   iCurrentCursor.xy = top-left corner of cursor cell (GL coords: x=left, y=top edge)
//   iCurrentCursor.zw = width, height of cursor cell
//   Center = xy + vec2(z*0.5, -w*0.5)
//   NO Y-flip needed.

// ─── Aura color palette ──────────────────────────────────────────────
const vec3 CORE_COLOR  = vec3(0.75, 0.92, 1.0);   // near-white cyan
const vec3 MID_COLOR   = vec3(0.45, 0.72, 1.0);   // light frost blue
const vec3 OUTER_COLOR = vec3(0.25, 0.50, 0.90);  // deeper blue haze

// ─── Aura geometry (concentrated) ────────────────────────────────────
const float CORE_RADIUS  = 5.0;    // tight bright core (pixels)
const float MID_RADIUS   = 14.0;   // close mid glow
const float OUTER_RADIUS = 32.0;   // compact outer haze

// ─── Aura intensity ──────────────────────────────────────────────────
const float CORE_INTENSITY  = 0.95;  // concentrated core brightness
const float MID_INTENSITY   = 0.18;  // subtle mid ring
const float OUTER_INTENSITY = 0.03;  // barely-there outer haze

// ─── Pulse (lightsaber hum — slower, deeper) ─────────────────────────
const float PULSE_FREQ   = 1.8;   // hum frequency (Hz)
const float PULSE_AMOUNT = 0.06;  // intensity modulation depth
const float PULSE_DRIFT  = 0.4;   // secondary slow drift frequency

// ─── Trail parameters (longer, smoother) ─────────────────────────────
const float TRAIL_DURATION   = 0.65;  // trail fade time (seconds)
const float TRAIL_WIDTH      = 8.0;   // thin trail saber width (pixels)
const float TRAIL_INTENSITY  = 0.35;  // trail peak brightness
const float TRAIL_HEAD_BIAS  = 0.85;  // head-to-tail brightness ratio

// ─── Smooth follow ──────────────────────────────────────────────────
// Controls how slowly the aura follows the cursor for saber-like rhythm.
const float FOLLOW_SPEED = 3.5;    // lower = slower/smoother following

// ─── Helpers ─────────────────────────────────────────────────────────

// Cursor center from iCurrentCursor/iPreviousCursor vec4.
// xy = top-left corner (GL coords), zw = cell size.
// Center: x + w/2 horizontally, y - h/2 vertically (y=top edge, move down).
vec2 cursorCellCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

// Smooth ease-out for trail animation
float easeOut(float t) {
    float inv = 1.0 - t;
    return 1.0 - inv * inv * inv;
}

// Slower ease-out for the aura follow — gives the lightsaber weight
float easeOutSlow(float t) {
    float inv = 1.0 - t;
    return 1.0 - inv * inv * inv * inv * inv;  // quintic
}

// Signed distance from point p to line segment (a, b), returns (dist, t)
vec2 sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float denom = dot(ba, ba);
    if (denom < 0.001) return vec2(length(pa), 0.5);
    float h = clamp(dot(pa, ba) / denom, 0.0, 1.0);
    return vec2(length(pa - ba * h), h);
}

// Simple pseudo-noise for shimmer
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float shimmer(vec2 p, float t) {
    vec2 cell = floor(p * 0.08);
    float n = hash(cell + floor(t * 3.0));
    return 0.85 + 0.15 * n;
}

// ─── Main ────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // ── Cursor centers (no Y-flip — same coord space as fragCoord) ──
    vec2 cursorCenter = cursorCellCenter(iCurrentCursor);
    vec2 prevCenter   = cursorCellCenter(iPreviousCursor);

    // ── Smooth follow: the aura lags behind the actual cursor ──
    float dt = iTime - iTimeCursorChange;
    float followT = 1.0 - exp(-FOLLOW_SPEED * dt);
    vec2 auraCenter = mix(prevCenter, cursorCenter, easeOutSlow(followT));

    // ── Distance from fragment to aura center ──
    float dist = length(fragCoord - auraCenter);

    // ── Early exit: too far from both aura and any possible trail ──
    float trailProgress = clamp(dt / TRAIL_DURATION, 0.0, 1.0);
    float moveDistance = length(cursorCenter - prevCenter);
    float maxReach = OUTER_RADIUS + moveDistance + TRAIL_WIDTH;
    float distToPrev = length(fragCoord - prevCenter);
    if (dist > maxReach && distToPrev > maxReach) {
        fragColor = original;
        return;
    }

    // ── Pulse modulation (lightsaber hum) ──
    float pulse = 1.0
        + PULSE_AMOUNT * sin(iTime * PULSE_FREQ * 6.2832)
        + PULSE_AMOUNT * 0.5 * sin(iTime * PULSE_DRIFT * 6.2832 + 1.0);

    // ── Shimmer for organic feel ──
    float shim = shimmer(fragCoord, iTime);

    // ── Always-on radial aura (centered on smooth-followed position) ──
    float auraGlow = 0.0;
    vec3 auraColor = vec3(0.0);

    // Core layer — bright white-cyan
    float coreGlow = CORE_INTENSITY * smoothstep(CORE_RADIUS, 0.0, dist);
    auraColor += CORE_COLOR * coreGlow;
    auraGlow += coreGlow;

    // Mid layer — frost blue
    float midGlow = MID_INTENSITY * smoothstep(MID_RADIUS, CORE_RADIUS * 0.5, dist);
    auraColor += MID_COLOR * midGlow;
    auraGlow += midGlow;

    // Outer layer — deep blue haze, gaussian-ish falloff
    float outerFactor = exp(-2.5 * (dist * dist) / (OUTER_RADIUS * OUTER_RADIUS));
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
        vec2 headPos = mix(prevCenter, cursorCenter, headProg);

        float tailProg = easeOut(max((trailProgress - 0.15) * 1.8, 0.0));
        vec2 tailPos = mix(prevCenter, cursorCenter, tailProg);

        // Distance from fragment to trail segment
        vec2 seg = sdSegment(fragCoord, tailPos, headPos);
        float distToTrail = seg.x;
        float trailParam = seg.y; // 0 = tail, 1 = head

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
