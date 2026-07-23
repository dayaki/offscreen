// Aurora — per-pixel animated backdrop for the break overlay.
// Compiled by Scripts/build-app.sh into Contents/Resources/default.metallib
// and loaded through SwiftUI's ShaderLibrary as a colorEffect.
#include <metal_stdlib>
using namespace metal;

static float2 rot(float2 p, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

[[ stitchable ]] half4 aurora(float2 position, half4 color, float2 size, float time) {
    float2 p = (position - 0.5 * size) / min(size.x, size.y);
    float t = time * 0.30;

    // Domain-warped sine field: each octave bends the space the next one
    // samples, so the waves fold and flow instead of ticking like a metronome.
    float2 q = p;
    float wave = 0.0;
    float amp = 1.0;
    float2 dir = normalize(float2(1.0, 0.55));
    for (int i = 0; i < 5; i++) {
        float freq = 1.9 + 1.15 * float(i);
        float phase = t * (0.55 + 0.21 * float(i)) + float(i) * 1.9;
        float s = sin(dot(q, dir) * freq + phase);
        wave += amp * s;
        q += (0.28 * amp * s) * float2(-dir.y, dir.x);
        dir = rot(dir, 1.9);
        amp *= 0.72;
    }
    wave *= 0.35; // roughly -1..1

    float band1 = 0.5 + 0.5 * sin(q.y * 3.1 + wave * 2.4 + t * 0.7);
    float band2 = 0.5 + 0.5 * sin(q.x * 2.3 - wave * 1.8 - t * 0.55);

    // Golden-hour palette (site tokens, dimmed to field-mixing levels):
    // bg0 #0a0612 · dusk #241736 · violet #b78cff · rose #ff7d9c · amber #ffb45c
    float3 deep   = float3(0.039, 0.024, 0.071);
    float3 dusk   = float3(0.141, 0.090, 0.212);
    float3 violet = float3(0.420, 0.320, 0.580);
    float3 rose   = float3(0.620, 0.300, 0.380);
    float3 amber  = float3(0.720, 0.510, 0.260);
    float3 plum   = float3(0.360, 0.160, 0.360);

    float3 col = mix(deep, dusk, clamp(0.5 + 0.5 * wave, 0.0, 1.0));
    col = mix(col, violet, 0.60 * band1 * band1);
    col = mix(col, rose,   0.50 * pow(band2, 3.0));
    col = mix(col, plum,   0.40 * pow(1.0 - band1, 3.0));
    col = mix(col, amber,  0.35 * pow(band1 * band2, 3.0) * (0.5 + 0.5 * sin(t * 0.8)));

    // Legibility: keep the middle calm for the countdown, vignette the edges.
    float r = length(p);
    col *= 0.80 + 0.20 * smoothstep(0.10, 0.60, r);
    col *= 1.0 - 0.34 * smoothstep(0.55, 1.25, r);

    // Subtle animated film grain; also dithers away gradient banding.
    float g = hash21(position + fract(time * 0.61) * 289.0);
    col += (g - 0.5) * 0.05;

    return half4(half3(col), 1.0);
}
