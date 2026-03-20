// Stardust — barely perceptible twinkling particles across the screen
//
// Sparse point particles scattered over the terminal, each with its own
// lifecycle: slow fade in, brief bright twinkle, gentle fade out. The
// stars drift very slightly over time and are tinted Nord frost-blue so
// they feel like ice crystals catching light in a dark arctic sky.
//
// At default intensity the effect is subliminal — individual stars are
// only noticed if you stare at a dark area. The cumulative impression
// is a terminal that feels alive and slightly magical without any
// distraction to readability.
//
// Layer: noise (same category as film-grain, runs late in the pipeline)
// Shared functions: hash11, hash21, luminance (see nord-common.glsl)

// ─── Constants ─────────────────────────────────────────────────────────
const float TAU = 6.2832;

// ─── Color Palette (Nord Frost) ────────────────────────────────────────
const vec3 STAR_COLD   = vec3(0.56, 0.74, 0.73);  // FROST_0 — dim stars
const vec3 STAR_BRIGHT = vec3(0.70, 0.88, 1.00);  // frost ice — twinkle peak
const vec3 STAR_WARM   = vec3(0.85, 0.87, 0.91);  // SNOW_0 — rare warm flicker

// ─── Stardust Parameters ───────────────────────────────────────────────
const float STAR_DENSITY    = 0.09;   // probability a cell contains a star (0-1)
const float STAR_INTENSITY  = 0.06;   // peak additive brightness
const float STAR_RADIUS     = 1.5;    // core glow radius (pixels)
const float STAR_SOFTNESS   = 1.0;    // falloff softness (pixels)
const float CYCLE_BASE      = 3.5;    // minimum lifecycle duration (seconds)
const float CYCLE_VARIANCE  = 7.0;    // additional random duration per star
const float TWINKLE_SHARPNESS = 3.0;  // how peaked the brightness curve is (lower = more visible)
const float DRIFT_SPEED     = 0.3;    // very slow positional drift (pixels/sec)
const float GRID_SIZE       = 20.0;   // cell size — controls star spacing (smaller = denser)

// ─── Background Detection ──────────────────────────────────────────────
const float BG_THRESHOLD = 0.25;  // stars only appear on darker areas
const float BG_SOFTNESS  = 0.15;  // transition band width

// ─── Hash Functions (from nord-common.glsl) ────────────────────────────

float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// ─── Luminance (from nord-common.glsl) ─────────────────────────────────

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// ─── Star Lifecycle ────────────────────────────────────────────────────
// Each star has a unique phase and period derived from its cell hash.
// The brightness curve is a raised cosine pinched by TWINKLE_SHARPNESS
// so the star spends most of its cycle dim and only briefly peaks.

float starBrightness(float phase, float t) {
    float raw = 0.5 + 0.5 * cos(TAU * (t - phase));
    return pow(raw, TWINKLE_SHARPNESS);
}

// ─── Main ──────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // Stars only appear on dark areas — don't interfere with text
    float luma = luminance(original.rgb);
    float bgMask = 1.0 - smoothstep(BG_THRESHOLD - BG_SOFTNESS,
                                      BG_THRESHOLD + BG_SOFTNESS, luma);

    // Early exit on bright areas
    if (bgMask < 0.001) {
        fragColor = original;
        return;
    }

    // Accumulate light from nearby star cells
    vec3 starLight = vec3(0.0);

    // Check the 3x3 neighborhood of cells around this pixel
    // so stars near cell edges still contribute
    vec2 cellCoord = fragCoord / GRID_SIZE;
    vec2 cellBase = floor(cellCoord);

    for (float dy = -1.0; dy <= 1.0; dy += 1.0) {
        for (float dx = -1.0; dx <= 1.0; dx += 1.0) {
            vec2 cell = cellBase + vec2(dx, dy);

            // Deterministic seed for this cell
            float seed = hash21(cell * 0.7123 + 0.3);

            // Density check — most cells are empty
            if (seed > STAR_DENSITY) continue;

            // Star position within cell (0-1 range, offset by slow drift)
            float seedX = hash21(cell + vec2(13.7, 0.0));
            float seedY = hash21(cell + vec2(0.0, 29.3));
            float drift = mod(iTime * DRIFT_SPEED, 1000.0);
            vec2 starPos = cell + vec2(
                seedX + sin(drift * 0.7 + seed * TAU) * 0.08,
                seedY + cos(drift * 0.5 + seed * TAU) * 0.08
            );
            vec2 starPixel = starPos * GRID_SIZE;

            // Distance from this pixel to the star center
            float dist = length(fragCoord - starPixel);

            // Star glow falloff
            float glow = exp(-0.5 * dist * dist /
                            ((STAR_RADIUS + STAR_SOFTNESS) *
                             (STAR_RADIUS + STAR_SOFTNESS)));

            if (glow < 0.001) continue;

            // Lifecycle timing — unique period and phase per star
            float period = CYCLE_BASE + CYCLE_VARIANCE * hash11(seed * 127.0);
            float phase  = hash11(seed * 311.0);
            float bright = starBrightness(phase, iTime / period);

            // Color — mostly cold frost, occasionally warmer
            float warmth = hash11(seed * 71.0);
            vec3 color = mix(STAR_COLD, STAR_BRIGHT, bright);
            if (warmth > 0.85) {
                color = mix(color, STAR_WARM, 0.3 * bright);
            }

            starLight += color * glow * bright * STAR_INTENSITY;
        }
    }

    // Composite — additive blend on dark areas only
    vec3 result = original.rgb + starLight * bgMask;

    fragColor = vec4(result, original.a);
}
