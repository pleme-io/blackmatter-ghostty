// nord-common.glsl — Shared constants and utility functions
//
// Reference library for all Nord Ghostty shaders. Since Ghostty does not
// support #include, each shader must be self-contained. This file documents
// the canonical names and implementations that every shader should use.
// Copy the sections you need into each shader verbatim.
//
// When updating a function here, grep for its name across all .glsl files
// and update every copy.

// ═══════════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════════

// TAU — full circle in radians, avoids the magic number 6.2832 everywhere.
const float TAU = 6.2832;

// ═══════════════════════════════════════════════════════════════════════
// Nord Frost Palette
// ═══════════════════════════════════════════════════════════════════════
//
// Primary cool accent colors from the Nord color scheme.
// https://www.nordtheme.com/docs/colors-and-palettes

const vec3 FROST_0 = vec3(0.56, 0.74, 0.73);  // #8FBCBB — frozen polar water
const vec3 FROST_1 = vec3(0.53, 0.75, 0.82);  // #88C0D0 — pure ice
const vec3 FROST_2 = vec3(0.51, 0.63, 0.76);  // #81A1C1 — arctic water
const vec3 FROST_3 = vec3(0.37, 0.51, 0.67);  // #5E81AC — arctic ocean

// ═══════════════════════════════════════════════════════════════════════
// Nord Aurora Palette
// ═══════════════════════════════════════════════════════════════════════
//
// Warm accent colors for highlights and status indicators.

const vec3 AURORA_RED    = vec3(0.75, 0.38, 0.42);  // #BF616A
const vec3 AURORA_ORANGE = vec3(0.82, 0.53, 0.44);  // #D08770
const vec3 AURORA_YELLOW = vec3(0.92, 0.80, 0.55);  // #EBCB8B
const vec3 AURORA_GREEN  = vec3(0.64, 0.75, 0.55);  // #A3BE8C
const vec3 AURORA_PURPLE = vec3(0.71, 0.56, 0.68);  // #B48EAD

// ═══════════════════════════════════════════════════════════════════════
// Nord Snow Storm Palette
// ═══════════════════════════════════════════════════════════════════════

const vec3 SNOW_0 = vec3(0.85, 0.87, 0.91);  // #D8DEE9
const vec3 SNOW_1 = vec3(0.90, 0.91, 0.94);  // #E5E9F0
const vec3 SNOW_2 = vec3(0.93, 0.94, 0.96);  // #ECEFF4

// ═══════════════════════════════════════════════════════════════════════
// Luminance
// ═══════════════════════════════════════════════════════════════════════
//
// ITU-R BT.709 luminance coefficients. Use this for any brightness
// calculation, background detection, or bloom thresholding.

float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// ═══════════════════════════════════════════════════════════════════════
// Hash Functions
// ═══════════════════════════════════════════════════════════════════════
//
// Pseudo-random number generators for noise, shimmer, and particle seeds.

// hash11 — float in, float out. General-purpose scalar hash.
float hash11(float n) {
    return fract(sin(n) * 43758.5453123);
}

// hash21 — vec2 in, float out. Spatial noise and shimmer.
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// hash23 — vec2 + float in, vec3 out. Three-channel color grain.
vec3 hash23(vec2 p, float t) {
    float tw = mod(t, 1000.0);
    vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
    p3 += dot(p3, p3.yzx + vec3(19.19 + tw));
    return fract(vec3(
        (p3.x + p3.y) * p3.z,
        (p3.x + p3.z) * p3.y,
        (p3.y + p3.z) * p3.x
    ));
}

// ═══════════════════════════════════════════════════════════════════════
// Value Noise
// ═══════════════════════════════════════════════════════════════════════
//
// Smooth interpolated 2D noise built on the spatial hash. Used by
// frost-haze fbm and anywhere organic patterns are needed.

// hashCell — internal helper for value noise (different constants to
// avoid correlation with hash21).
float hashCell(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);  // smoothstep interpolation

    float a = hashCell(i);
    float b = hashCell(i + vec2(1.0, 0.0));
    float c = hashCell(i + vec2(0.0, 1.0));
    float d = hashCell(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// ═══════════════════════════════════════════════════════════════════════
// Gaussian
// ═══════════════════════════════════════════════════════════════════════
//
// Normalized-ish gaussian falloff. Used for glow, particles, ring shapes.

float gaussian(float d, float w) {
    return exp(-0.5 * d * d / (w * w));
}

// ═══════════════════════════════════════════════════════════════════════
// Cursor Center
// ═══════════════════════════════════════════════════════════════════════
//
// Compute the pixel-space center of the cursor cell from the Ghostty
// cursor vec4 (xy = top-left corner, zw = cell width/height, GL coords
// where y points up and xy is the top edge).

vec2 cursorCenter(vec4 c) {
    return c.xy + vec2(c.z * 0.5, -c.w * 0.5);
}

// ═══════════════════════════════════════════════════════════════════════
// Shimmer
// ═══════════════════════════════════════════════════════════════════════
//
// Organic spatial noise variation for glow effects. Returns a value in
// [base, base + range] that changes slowly over time. Time is wrapped
// to prevent float precision loss after hours of uptime.
//
//   base  — minimum return value (e.g. 0.85 for subtle, 0.93 for faint)
//   range — variation amplitude  (e.g. 0.15 for subtle, 0.07 for faint)
//   speed — temporal rate         (e.g. 3.0 for cursor-trail, 2.5 for prompt-saber)

float shimmer(vec2 p, float t, float base, float range, float speed) {
    vec2 cell = floor(p * 0.08);
    float n = hash21(cell + floor(mod(t * speed, 256.0)));
    return base + range * n;
}
