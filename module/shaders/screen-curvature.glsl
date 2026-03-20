// Screen Curvature — subtle barrel distortion for depth
//
// Adds a very gentle barrel distortion to simulate the curvature of
// a physical display. Creates a sense of depth and immersion without
// being distracting. Strongest at corners, invisible at center.
// No animation — pure geometry.

// ─── Geometry ──────────────────────────────────────────────────────────
const float CURVATURE   = 0.012;  // distortion strength (keep small!)
const float CORNER_DARK = 0.025;  // subtle corner darkening

// ─── Main ──────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Center UV to -1..1 range
    vec2 centered = uv * 2.0 - 1.0;

    // Barrel distortion — r-squared pushes pixels outward from center
    float r2 = dot(centered, centered);
    vec2 distorted = centered * (1.0 + CURVATURE * r2);

    // Back to 0..1 range
    vec2 finalUV = distorted * 0.5 + 0.5;

    // Clip to screen bounds (black at overscanned edges)
    if (finalUV.x < 0.0 || finalUV.x > 1.0 ||
        finalUV.y < 0.0 || finalUV.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec4 original = texture(iChannel0, finalUV);

    // Subtle corner darkening for CRT feel
    float corner = 1.0 - CORNER_DARK * r2;

    fragColor = vec4(original.rgb * corner, original.a);
}
