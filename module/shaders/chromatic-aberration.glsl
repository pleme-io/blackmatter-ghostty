// Nord Frost — edge chromatic aberration
//
// Subtle color channel separation at screen edges mimicking light refracting
// through ice crystal or a premium lens. The effect is zero at center and
// increases radially outward. Shifts toward Nord frost-blue on the outer
// channels for a cold, crystalline feel.
//
// The displacement is sub-pixel at the center and only reaches 1-2 pixels
// at the very corners — enough to add perceived depth without affecting
// text readability.

// ─── Parameters ────────────────────────────────────────────────────
const float MAX_OFFSET    = 1.5;    // max channel displacement in pixels at corners
const float POWER         = 2.0;    // radial falloff curve (2.0 = quadratic, natural lens)
const float FROST_SHIFT   = 0.12;   // blue channel gets extra outward push (ice refraction)

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    // Distance from center (0 at center, ~0.707 at corners)
    vec2 centered = uv - 0.5;
    float dist = length(centered);

    // Radial displacement — zero at center, MAX_OFFSET at corners
    float strength = pow(dist * 1.414, POWER);  // normalize so corners = 1.0
    vec2 dir = centered / max(dist, 0.001);     // unit direction from center
    vec2 texelSize = 1.0 / iResolution.xy;
    vec2 offset = dir * strength * MAX_OFFSET * texelSize;

    // Sample each channel with different offsets:
    //   Red: pulled inward (warm stays center)
    //   Green: no shift (anchor channel)
    //   Blue: pushed outward + extra frost shift (ice refraction)
    float r = texture(iChannel0, uv - offset * 0.5).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv + offset * (0.5 + FROST_SHIFT)).b;
    float a = texture(iChannel0, uv).a;

    fragColor = vec4(r, g, b, a);
}
