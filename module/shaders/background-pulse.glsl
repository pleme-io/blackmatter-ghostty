// Background Pulse — ultra-slow Nord frost color breathing
//
// Adds a barely perceptible color shift to dark background areas that
// slowly cycles through Nord frost blues.  Text and bright content are
// untouched.  Gives the terminal a living, breathing quality.

// ─── Color palette (Nord frost) ──────────────────────────────────
const vec3 FROST_A = vec3(0.56, 0.74, 0.73);   // Nord frost0 (#8FBCBB)
const vec3 FROST_B = vec3(0.53, 0.75, 0.82);   // Nord frost1 (#88C0D0)
const vec3 FROST_C = vec3(0.51, 0.63, 0.76);   // Nord frost2 (#81A1C1)

// ─── Timing ──────────────────────────────────────────────────────
const float CYCLE_SPEED   = 0.08;    // Hz — one full cycle every ~12s
const float INTENSITY     = 0.015;   // color shift strength (very subtle)

// ─── Background detection ────────────────────────────────────────
const float BG_THRESHOLD  = 0.15;    // luminance below this = background
const float BG_SOFTNESS   = 0.08;    // transition band width

// ─── Main ────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    float lum = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Only affect dark background areas — smooth transition
    float mask = smoothstep(BG_THRESHOLD, BG_THRESHOLD - BG_SOFTNESS, lum);

    // Early exit for bright content (most text pixels)
    if (mask < 0.001) {
        fragColor = original;
        return;
    }

    // Slow three-phase color cycling through frost palette
    float phase = mod(iTime * CYCLE_SPEED, 1.0) * 6.2832;
    float t1 = 0.5 + 0.5 * sin(phase);
    float t2 = 0.5 + 0.5 * sin(phase + 2.094);  // 120° offset

    vec3 frost = mix(mix(FROST_A, FROST_B, t1), FROST_C, t2);
    vec3 shift = frost * INTENSITY * mask;

    fragColor = vec4(original.rgb + shift, original.a);
}
