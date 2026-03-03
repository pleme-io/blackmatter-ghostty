// Subtle bloom glow effect for Ghostty terminal
// Applies a soft golden-ratio gaussian bloom to bright pixels
// Shadertoy-compatible: uses iTime, iResolution, iChannel0

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // Bloom parameters
    const float threshold = 0.7;
    const float intensity = 0.15;
    const float radius = 3.0;
    const float goldenAngle = 2.39996323;

    // Calculate luminance of center pixel
    float luma = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Only bloom bright pixels (text glow)
    if (luma < threshold) {
        fragColor = original;
        return;
    }

    // Golden-ratio spiral gaussian kernel
    vec3 bloom = vec3(0.0);
    float totalWeight = 0.0;
    vec2 texelSize = 1.0 / iResolution.xy;

    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        float angle = fi * goldenAngle;
        float dist = sqrt(fi + 0.5) * radius;
        vec2 offset = vec2(cos(angle), sin(angle)) * dist * texelSize;

        // Gaussian weight based on distance
        float weight = exp(-0.5 * (dist * dist) / (radius * radius));
        vec3 sample_color = texture(iChannel0, uv + offset).rgb;
        float sampleLuma = dot(sample_color, vec3(0.2126, 0.7152, 0.0722));

        // Only accumulate bright samples
        bloom += sample_color * weight * smoothstep(threshold - 0.1, threshold, sampleLuma);
        totalWeight += weight;
    }

    bloom /= max(totalWeight, 1.0);

    // Subtle time-based pulse (barely perceptible warmth)
    float pulse = 1.0 + 0.02 * sin(iTime * 0.5);

    fragColor = vec4(original.rgb + bloom * intensity * pulse, original.a);
}
