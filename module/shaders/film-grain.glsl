// Nord Frost — film grain
//
// Extremely subtle animated noise that prevents digital flatness and gives
// the terminal an organic, cinematic quality. Tinted toward Nord frost-blue
// so the grain feels like particles of ice dust catching light.
//
// At the default intensity the effect is invisible to conscious perception
// but the brain registers the screen as more natural and less sterile.

// ─── Grain parameters ──────────────────────────────────────────────
const float GRAIN_INTENSITY  = 0.025;  // overall strength (0.02-0.04 sweet spot)
const float GRAIN_SIZE       = 1.0;    // 1.0 = per-pixel, higher = coarser
const float GRAIN_SPEED      = 12.0;   // temporal variation rate
const float FROST_TINT       = 0.15;   // how much grain shifts toward blue (0=neutral)

// ─── Nord frost ────────────────────────────────────────────────────
const vec3 FROST_BIAS = vec3(-0.02, 0.01, 0.04);  // subtle blue shift on grain

// ─── Noise ─────────────────────────────────────────────────────────

// High-quality hash — three independent channels for color grain
vec3 hash3(vec2 p, float t) {
    // Wrap time to prevent float precision loss over hours
    float tw = mod(t, 1000.0);
    vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
    p3 += dot(p3, p3.yzx + vec3(19.19 + tw));
    return fract(vec3(
        (p3.x + p3.y) * p3.z,
        (p3.x + p3.z) * p3.y,
        (p3.y + p3.z) * p3.x
    ));
}

// ─── Main ──────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // Grain coordinate — quantize to grain size
    vec2 grainCoord = floor(fragCoord / GRAIN_SIZE);

    // Temporal seed — changes every frame for animated grain
    float timeSeed = floor(iTime * GRAIN_SPEED);

    // Three-channel noise centered at 0 (-0.5 to +0.5)
    vec3 noise = hash3(grainCoord, timeSeed) - 0.5;

    // Apply frost tint bias — grain skews slightly blue
    noise += FROST_BIAS * FROST_TINT;

    // Reduce grain on bright areas (film grain is more visible in shadows)
    float luma = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
    float shadowBoost = mix(1.0, 0.4, smoothstep(0.0, 0.8, luma));

    // Apply grain
    vec3 color = original.rgb + noise * GRAIN_INTENSITY * shadowBoost;

    fragColor = vec4(color, original.a);
}
