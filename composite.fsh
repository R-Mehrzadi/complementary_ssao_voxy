#version 120

/* DRAWBUFFERS:012 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;

varying vec2 texCoord;

// Complementary Reimagined r5.9 SSAO, adapted to XorDev.
// The original relies on animated dither + temporal accumulation to resolve
// its low-sample pattern. This version restores that temporal resolve so the
// individual sample offsets do not appear as repeated hard shadows.
#define AO_SAMPLES 12
#define AO_STRENGTH 0.4
#define AO_HISTORY 0.85

// Preserve AO and history between frames.
const bool colortex1Clear = false;
const bool colortex2Clear = false;

float getLinearDepth(float d) {
    return (2.0 * near) / (far + near - d * (far - near));
}

vec2 offsetDist(float x, float samples) {
    float n = fract(x * 1.414) * 3.14159265;
    // Complementary's pow2(x) is component-wise x*x.
    return (vec2(cos(n), sin(n)) * x / samples);
}

float currentAO(float z0) {
    if (z0 < 0.56 || z0 >= 1.0) return 1.0;

    float linearZ0 = getLinearDepth(z0);
    float ao = 0.0;

    float fovScale = gbufferProjection[1][1];
    float distScale = max((far - near) * linearZ0 + near, 3.0);
    float scm = 0.6;
    vec2 scale = vec2(scm / aspectRatio, scm) * fovScale / distScale;

    // Same temporal dither source used by Complementary.
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

vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

bool reprojectHistory(vec2 uv, float depth, out vec2 prevUv) {
    vec3 viewPos = reconstructViewPos(uv, depth);
    vec3 playerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    vec4 prevView = gbufferPreviousModelView * vec4(playerPos, 1.0);
    vec4 prevClip = gbufferPreviousProjection * prevView;
    if (prevClip.w <= 0.0) return false;

    prevUv = prevClip.xy / prevClip.w * 0.5 + 0.5;
    return prevUv.x > 0.001 && prevUv.x < 0.999 && prevUv.y > 0.001 && prevUv.y < 0.999;
}

void main() {
    vec4 color = texture2D(colortex0, texCoord);
    float z = texture2D(depthtex0, texCoord).r;

    float ao = currentAO(z);
    float historyAO = ao;
    bool useHistory = false;
    vec2 prevUv = texCoord;

    if (z >= 0.56 && z < 1.0 && reprojectHistory(texCoord, z, prevUv)) {
        float prevZ = texture2D(colortex2, prevUv).r;
        float prevAO = texture2D(colortex1, prevUv).r;

        // Reject disocclusion / mismatched geometry. The threshold is slightly
        // wider farther from the camera where depth quantisation is coarser.
        float depthThreshold = 0.002 + 0.01 * z;
        if (abs(prevZ - z) < depthThreshold) {
            historyAO = prevAO;
            useHistory = true;
        }
    }

    if (useHistory) {
        // Limit history influence so newly exposed contact edges settle quickly.
        float historyWeight = AO_HISTORY;
        float delta = abs(ao - historyAO);
        historyWeight *= 1.0 - clamp(delta * 4.0, 0.0, 0.75);
        ao = mix(ao, historyAO, historyWeight);
    }

    color.rgb *= ao;

    gl_FragData[0] = color;
    gl_FragData[1] = vec4(ao, ao, ao, 1.0);
    gl_FragData[2] = vec4(z, z, z, 1.0);
}
