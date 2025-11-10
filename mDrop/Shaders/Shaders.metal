#include <metal_stdlib>
using namespace metal;

// Structures for passing data between CPU and GPU
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float bassLevel;
    float midLevel;
    float trebleLevel;
    float2 resolution;
};

// Vertex shader - transforms positions
vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// Helper function for color palette
float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// Classic MilkDrop-style plasma effect
fragment float4 plasmaShader(VertexOut in [[stage_in]],
                            constant Uniforms &uniforms [[buffer(0)]],
                            constant float *frequencies [[buffer(1)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float3 col = float3(0.0);

    // Plasma waves influenced by audio
    float bassWave = sin(length(uv) * 3.0 - uniforms.time + uniforms.bassLevel * 5.0);
    float midWave = sin(uv.x * 5.0 + uniforms.time * 0.5 + uniforms.midLevel * 3.0);
    float trebleWave = sin(uv.y * 5.0 - uniforms.time * 0.3 + uniforms.trebleLevel * 2.0);

    float wave = bassWave + midWave + trebleWave;

    // Color based on audio levels
    float3 color1 = float3(0.5, 0.5, 0.5);
    float3 color2 = float3(0.5, 0.5, 0.5);
    float3 color3 = float3(1.0, 1.0, 1.0);
    float3 color4 = float3(uniforms.bassLevel, uniforms.midLevel, uniforms.trebleLevel);

    col = palette(wave * 0.5 + 0.5, color1, color2, color3, color4);

    return float4(col, 1.0);
}

// Particle-based shader
fragment float4 particleShader(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              constant float *frequencies [[buffer(1)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float3 col = float3(0.0);

    // Create particles based on frequency data
    for (int i = 0; i < 32; i++) {
        float fi = float(i) / 32.0;
        float freqValue = frequencies[i * 8]; // Sample every 8th frequency bin

        // Particle position
        float angle = fi * 6.28318 + uniforms.time + freqValue * 3.14159;
        float radius = 0.3 + freqValue * 0.5;
        float2 particlePos = float2(cos(angle), sin(angle)) * radius;

        // Distance to particle
        float dist = length(uv - particlePos);
        float particle = 0.01 / (dist + 0.01);

        // Color based on frequency
        float3 particleCol = palette(fi + uniforms.time * 0.1,
                                    float3(0.5),
                                    float3(0.5),
                                    float3(1.0, 1.0, 0.5),
                                    float3(0.0, 0.1, 0.2));

        col += particleCol * particle * freqValue;
    }

    return float4(col, 1.0);
}

// Waveform visualization shader
fragment float4 waveformShader(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              constant float *frequencies [[buffer(1)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float3 col = float3(0.0);

    // Create circular waveform
    float angle = atan2(uv.y, uv.x);
    float radius = length(uv);

    // Map angle to frequency bin
    int binIndex = int((angle + 3.14159) / 6.28318 * 128.0);
    float freqValue = frequencies[binIndex];

    // Draw waveform circle
    float waveRadius = 0.5 + freqValue * 0.3;
    float wave = abs(radius - waveRadius);
    float line = smoothstep(0.02, 0.0, wave);

    // Glow effect
    float glow = 0.1 / (wave + 0.01);

    // Color based on frequency
    float3 waveColor = palette(freqValue + uniforms.time * 0.1,
                              float3(0.5, 0.5, 0.5),
                              float3(0.5, 0.5, 0.5),
                              float3(1.0, 0.7, 0.4),
                              float3(0.0, 0.15, 0.20));

    col = waveColor * (line + glow * 0.5);

    // Add center glow based on bass
    float centerGlow = uniforms.bassLevel * 0.5 / (radius + 0.1);
    col += float3(0.3, 0.1, 0.5) * centerGlow;

    return float4(col, 1.0);
}

// Spectrum bars shader
fragment float4 spectrumShader(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              constant float *frequencies [[buffer(1)]]) {
    float2 uv = in.texCoord;

    float3 col = float3(0.0);

    // Number of bars
    int numBars = 64;
    float barWidth = 1.0 / float(numBars);

    // Determine which bar we're in
    int barIndex = int(uv.x * float(numBars));
    float barX = float(barIndex) / float(numBars);

    // Get frequency value for this bar
    float freqValue = frequencies[barIndex * 4];

    // Bar height
    float barHeight = freqValue * 0.9;

    // Check if we're inside a bar
    float inBar = step(barX + 0.002, uv.x) * step(uv.x, barX + barWidth - 0.002);
    float aboveBar = step(uv.y, barHeight);

    // Color gradient based on height
    float3 barColor = palette(uv.y + uniforms.time * 0.1,
                             float3(0.5, 0.5, 0.5),
                             float3(0.5, 0.5, 0.5),
                             float3(1.0, 0.5, 0.3),
                             float3(0.0, 0.2, 0.5));

    col = barColor * inBar * aboveBar;

    // Add glow at the top
    float glowDist = abs(uv.y - barHeight);
    float glow = 0.02 / (glowDist + 0.01) * inBar;
    col += barColor * glow * 0.5;

    return float4(col, 1.0);
}

// Tunnel effect shader
fragment float4 tunnelShader(VertexOut in [[stage_in]],
                            constant Uniforms &uniforms [[buffer(0)]],
                            constant float *frequencies [[buffer(1)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float3 col = float3(0.0);

    // Tunnel coordinates
    float r = length(uv);
    float a = atan2(uv.y, uv.x);

    // Tunnel effect with audio influence
    float tunnelDepth = 1.0 / r + uniforms.time * 0.5 + uniforms.bassLevel * 2.0;
    float tunnelAngle = a * 3.0 + uniforms.time + uniforms.midLevel * 3.14159;

    float pattern = sin(tunnelDepth * 5.0) * cos(tunnelAngle);

    // Add frequency visualization
    int freqIndex = int((a + 3.14159) / 6.28318 * 128.0);
    float freqValue = frequencies[freqIndex];
    pattern += freqValue * sin(tunnelDepth * 10.0);

    // Color
    float3 tunnelColor = palette(pattern * 0.5 + 0.5 + uniforms.time * 0.1,
                                float3(0.5, 0.5, 0.5),
                                float3(0.5, 0.5, 0.5),
                                float3(1.0, 1.0, 0.5),
                                float3(0.3, 0.2, 0.2));

    col = tunnelColor;

    // Vignette
    col *= 1.0 - r * 0.5;

    return float4(col, 1.0);
}
