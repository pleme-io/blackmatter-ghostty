// Cursor trail effect for Ghostty terminal
// Creates a smooth trailing warp when the cursor moves between positions
// Based on sahaj-b/ghostty-cursor-shaders cursor_warp.glsl
//
// Ghostty cursor uniforms:
//   iCurrentCursor   — vec4(x, y, width, height) in pixels
//   iPreviousCursor   — vec4(x, y, width, height) in pixels
//   iTimeCursorChange — float, time of last cursor position change
//   iCurrentCursorColor — vec4, RGBA color of the cursor

// ─── Tuning constants ───────────────────────────────────────────────

// Trail duration: how long the trail lingers (seconds)
const float TRAIL_DURATION = 0.35;

// Trail width: how wide the distortion band is (pixels)
const float TRAIL_WIDTH = 24.0;

// Warp intensity: max pixel displacement at peak
const float WARP_STRENGTH = 8.0;

// Glow intensity: brightness of the trail glow
const float GLOW_INTENSITY = 0.25;

// Glow falloff: how quickly glow fades from the trail center
const float GLOW_FALLOFF = 3.0;

// Number of trail segments for smooth interpolation
const int TRAIL_SEGMENTS = 32;

// ─── Helpers ────────────────────────────────────────────────────────

// Smooth cubic ease-out
float easeOut(float t) {
    float inv = 1.0 - t;
    return 1.0 - inv * inv * inv;
}

// Signed distance from point p to line segment (a, b)
// Returns: (distance, t) where t is the projection parameter [0,1]
vec2 sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float d = length(pa - ba * h);
    return vec2(d, h);
}

// ─── Main ───────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Time since cursor last moved
    float dt = iTime - iTimeCursorChange;

    // Normalized progress [0, 1] — 0 = just moved, 1 = trail fully faded
    float progress = clamp(dt / TRAIL_DURATION, 0.0, 1.0);

    // Early exit: trail has fully faded
    if (progress >= 1.0) {
        fragColor = texture(iChannel0, uv);
        return;
    }

    // Cursor centers (pixels)
    vec2 prevCenter = iPreviousCursor.xy + iPreviousCursor.zw * 0.5;
    vec2 currCenter = iCurrentCursor.xy + iCurrentCursor.zw * 0.5;

    // Flip Y — Ghostty cursor coords are top-down, GL is bottom-up
    prevCenter.y = iResolution.y - prevCenter.y;
    currCenter.y = iResolution.y - currCenter.y;

    // Distance between old and new cursor positions
    float moveDistance = length(currCenter - prevCenter);

    // Skip if cursor didn't actually move (or moved < 1 pixel)
    if (moveDistance < 1.0) {
        fragColor = texture(iChannel0, uv);
        return;
    }

    // ─── Trail path ─────────────────────────────────────────────

    // Animated head position — the trail head moves from prev to curr
    float headProgress = easeOut(min(progress * 2.0, 1.0));
    vec2 headPos = mix(prevCenter, currCenter, headProgress);

    // Animated tail position — the tail catches up after the head
    float tailProgress = easeOut(max((progress - 0.15) * 2.5, 0.0));
    vec2 tailPos = mix(prevCenter, currCenter, tailProgress);

    // Direction of travel
    vec2 moveDir = normalize(currCenter - prevCenter);
    vec2 movePerp = vec2(-moveDir.y, moveDir.x);

    // ─── Distance from fragment to trail segment ────────────────

    vec2 seg = sdSegment(fragCoord, tailPos, headPos);
    float distToTrail = seg.x;
    float trailParam = seg.y; // 0 = tail, 1 = head

    // Fade factor: distance from trail center
    float trailFade = 1.0 - smoothstep(0.0, TRAIL_WIDTH, distToTrail);

    // Skip fragments too far from the trail
    if (trailFade <= 0.0) {
        fragColor = texture(iChannel0, uv);
        return;
    }

    // ─── Temporal fade ──────────────────────────────────────────

    // Overall opacity fades as the trail ages
    float timeFade = 1.0 - easeOut(progress);

    // Trail is brightest at the head, dimmer at the tail
    float headFade = mix(0.3, 1.0, trailParam);

    float combinedFade = trailFade * timeFade * headFade;

    // ─── Warp distortion ────────────────────────────────────────

    // Displacement: push pixels away from the trail path perpendicular to movement
    // Stronger near the head, weaker near the tail
    float warpAmount = WARP_STRENGTH * combinedFade;

    // Determine which side of the trail this fragment is on
    vec2 toFrag = fragCoord - mix(tailPos, headPos, trailParam);
    float side = sign(dot(toFrag, movePerp));

    // Apply displacement in UV space
    vec2 warpOffset = movePerp * side * warpAmount / iResolution.xy;
    vec2 warpedUV = uv + warpOffset;

    // Clamp to valid UV range
    warpedUV = clamp(warpedUV, vec2(0.0), vec2(1.0));

    // Sample the warped texture
    vec4 warped = texture(iChannel0, warpedUV);

    // ─── Glow ───────────────────────────────────────────────────

    // Color glow along the trail using cursor color
    vec3 glowColor = iCurrentCursorColor.rgb;
    float glowStrength = GLOW_INTENSITY * combinedFade;

    // Soft additive glow
    vec3 glow = glowColor * glowStrength * exp(-GLOW_FALLOFF * distToTrail / TRAIL_WIDTH);

    // ─── Chromatic fringe (subtle) ──────────────────────────────

    // Slight color separation at the warp edges for a polished look
    float chromaOffset = 0.5 * combinedFade / iResolution.x;
    vec2 chromaDir = movePerp / iResolution.xy;

    float r = texture(iChannel0, warpedUV + chromaDir * chromaOffset).r;
    float g = warped.g;
    float b = texture(iChannel0, warpedUV - chromaDir * chromaOffset).b;

    vec3 chromatic = vec3(r, g, b);

    // ─── Composite ──────────────────────────────────────────────

    // Blend between original and warped+glow based on trail proximity
    vec4 original = texture(iChannel0, uv);
    vec3 trailColor = chromatic + glow;
    vec3 finalColor = mix(original.rgb, trailColor, combinedFade * 0.7);

    fragColor = vec4(finalColor, original.a);
}
