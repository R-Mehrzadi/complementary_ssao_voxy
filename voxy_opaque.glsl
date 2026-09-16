/*
    Voxy Opaque Fragment Shader
    Adapted from Complementary SSAO for voxy compatibility
    
    This patch calculates Screen Space Ambient Occlusion and outputs
    the result along with the original color to voxy's buffer.
*/

#define AO_SAMPLES 12
#define AO_STRENGTH 0.4
#define AO_HISTORY 0.85

// Helper function to get linear depth from depth texture value
float getLinearDepth(float d) {
    return (2.0 * near) / (far + near - d * (far - near));
}

// Calculate offset distance for AO sampling
vec2 offsetDist(float x, float samples) {
    float n = fract(x * 1.414) * 3.14159265;
    return (vec2(cos(n), sin(n)) * x / samples);
}

// Calculate ambient occlusion for current fragment
float calculateAO() {
    vec2 texCoord = parameters.uv;
    
    float z0 = texture2D(depthtex0, texCoord).r;
    if (z0 < 0.56 || z0 >= 1.0) return 1.0;
    
    float linearZ0 = getLinearDepth(z0);
    float ao = 0.0;
    
    float fovScale = gbufferProjection[1][1];
    float distScale = max((far - near) * linearZ0 + near, 3.0);
    float scm = 0.6;
    vec2 scale = vec2(scm / aspectRatio, scm) * fovScale / distScale;
    
    // Temporal dither to reduce banding and create temporal accumulation
    float dither = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 128.0).b;
    dither = fract(dither + 0.61803398875 * mod(float(frameCounter), 3600.0));
    
    for (int i = 1; i <= AO_SAMPLES; ++i) {
        vec2 offset = offsetDist(float(i) + dither, float(AO_SAMPLES)) * scale;
        if (i % 2 == 0) offset.y = -offset.y;
        
        float sampleDepth = getLinearDepth(texture2D(depthtex0, texCoord + offset).r);
        float aosample = (far - near) * (linearZ0 - sampleDepth) * 2.0;
        float angle = clamp(0.5 - aosample, 0.0, 1.0);
        float dist = clamp(0.5 * aosample - 1.0, 0.0, 1.0);
        
        sampleDepth = getLinearDepth(texture2D(depthtex0, texCoord - offset).r);
        aosample = (far - near) * (linearZ0 - sampleDepth) * 2.0;
        angle += clamp(0.5 - aosample, 0.0, 1.0);
        dist += clamp(0.5 * aosample - 1.0, 0.0, 1.0);
        
        ao += clamp(angle + dist, 0.0, 1.0);
    }
    
    ao /= float(AO_SAMPLES);
    return pow(ao, AO_STRENGTH);
}

// Main voxy opaque patch
// Apply SSAO to the sampled color from gbuffer
vec3 aoColor = vec3(calculateAO());
vec3 finalColor = parameters.sampledColour.rgb * aoColor;

// Output to voxy buffer 16 (extended colortex range)
gl_FragData[0] = vec4(finalColor, parameters.sampledColour.a);
