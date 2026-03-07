// Nord Frost — subtle text bloom + scan lines + vignette
//
// Content-reactive shader that works in every context (shell, TUI, Claude Code).
// Uses only iChannel0 (screen texture), iTime, and iResolution — no cursor
// uniforms. Bright text gets a soft Nord frost-blue bloom halo; faint scan
// lines and edge vignette add depth without interfering with readability.

// ─── Nord frost palette ──────────────────────────────────────────────
const vec3 FROST_CYAN  = vec3(0.55, 0.83, 0.93);  // nord8 — primary accent
const vec3 FROST_ICE   = vec3(0.70, 0.88, 1.00);  // bright ice highlight

// ─── Bloom parameters ────────────────────────────────────────────────
const float BLOOM_THRESHOLD  = 0.55;   // luminance threshold for source pixels
const float BLOOM_INTENSITY  = 0.12;   // overall bloom brightness
const float BLOOM_RADIUS     = 3.5;    // sample spread (pixels)
const float BLOOM_TINT       = 0.30;   // Nord frost tint strength (0=none, 1=full)
const int   BLOOM_SAMPLES    = 14;     // golden-spiral sample count

// ─── Scan lines ──────────────────────────────────────────────────────
const float SCAN_INTENSITY   = 0.025;  // barely visible
const float SCAN_SPEED       = 0.08;   // drift rate (fraction of screen/sec)
const float SCAN_PERIOD      = 4.0;    // pixels between lines

// ─── Vignette ────────────────────────────────────────────────────────
const float VIGNETTE_STRENGTH = 0.18;  // max darkening at corners
const float VIGNETTE_SOFTNESS = 0.45;  // how far in the effect reaches

// ─── Pulse ───────────────────────────────────────────────────────────
const float PULSE_FREQ   = 0.3;   // very slow breathing
const float PULSE_AMOUNT = 0.015; // barely perceptible intensity shift

// ─── Helpers ─────────────────────────────────────────────────────────

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// ─── Main ────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // ── Bloom: golden-ratio spiral gaussian on bright text ──
    // The sampling loop only accumulates contributions from bright
    // neighbor pixels. The result is added unconditionally so that
    // dark background near bright text receives a visible glow halo.
    vec3 bloom = vec3(0.0);
    float totalWeight = 0.0;
    vec2 texelSize = 1.0 / iResolution.xy;
    const float goldenAngle = 2.39996323;

    for (int i = 0; i < BLOOM_SAMPLES; i++) {
        float fi = float(i);
        float angle = fi * goldenAngle;
        float dist = sqrt(fi + 0.5) * BLOOM_RADIUS;
        vec2 offset = vec2(cos(angle), sin(angle)) * dist * texelSize;

        float weight = exp(-0.5 * (dist * dist) / (BLOOM_RADIUS * BLOOM_RADIUS));
        vec3 s = texture(iChannel0, uv + offset).rgb;
        float sLuma = luminance(s);

        // Only accumulate bright neighbours
        float contrib = smoothstep(BLOOM_THRESHOLD - 0.1, BLOOM_THRESHOLD, sLuma);
        bloom += s * weight * contrib;
        totalWeight += weight;
    }
    bloom /= max(totalWeight, 1.0);

    // Tint bloom toward Nord frost — blue-cyan shift
    float luma = luminance(original.rgb);
    vec3 frostTint = mix(FROST_CYAN, FROST_ICE, luma);
    bloom = mix(bloom, bloom * frostTint, BLOOM_TINT);

    // ── Scan lines: faint horizontal lines drifting slowly ──
    // Wrap time offset to SCAN_PERIOD to avoid float precision loss at large iTime.
    float scanOffset = mod(iTime * SCAN_SPEED * iResolution.y, SCAN_PERIOD);
    float scanY = fragCoord.y + scanOffset;
    float scan = 1.0 - SCAN_INTENSITY * (0.5 + 0.5 * sin(scanY * 6.2832 / SCAN_PERIOD));

    // ── Vignette: soft edge darkening ──
    vec2 centered = uv - 0.5;
    float vignette = 1.0 - VIGNETTE_STRENGTH * smoothstep(
        VIGNETTE_SOFTNESS, 1.0, length(centered) * 1.6
    );

    // ── Pulse: barely-there breathing ──
    // Wrap phase to [0, 2pi) to preserve float precision over hours of uptime.
    float pulse = 1.0 + PULSE_AMOUNT * sin(mod(iTime * PULSE_FREQ, 1.0) * 6.2832);

    // ── Composite ──
    vec3 color = original.rgb + bloom * BLOOM_INTENSITY * pulse;

    // Apply scan lines and vignette
    color *= scan * vignette;

    fragColor = vec4(color, original.a);
}
