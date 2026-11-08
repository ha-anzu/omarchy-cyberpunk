#version 300 es
// Johnny merge. Clean between hits. Gaps are uneven, a few seconds long.
// Each hit picks its own length and strength: a faint snap, a hard tear,
// or a longer stutter. Idle split stays a fraction of a pixel.
// Needs debug:damage_tracking = 0 and debug:vfr = false. Damage tracking
// off redraws a scheduled frame. Variable frame rate still skips the next
// one when the screen is still, which freezes a hit on the last picture.
precision highp float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;
uniform float time;

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

// x = envelope, y = seed, z = strength.
// Strength and length are chosen per hit, not on a ramp.
vec3 consider(float t, float window, float chance, float salt) {
    float n = floor(t / window);
    float local = t - n * window;
    float gate = hash(n * 17.13 + salt);
    float hDur = hash(n * 9.71 + salt * 2.0);
    float hShape = hash(n * 21.9 + salt * 4.0);
    float hGain = hash(n * 6.4 + salt * 5.0);

    float dur;
    if (hDur < 0.28) {
        dur = mix(0.12, 0.28, hDur / 0.28);
    } else if (hDur > 0.80) {
        dur = mix(0.72, 1.12, (hDur - 0.80) / 0.20);
    } else {
        dur = mix(0.32, 0.68, (hDur - 0.28) / 0.52);
    }

    float start = hash(n * 3.37 + salt * 3.0) * max(window - dur - 0.04, 0.0);
    float env = 0.0;
    if (gate < chance && local > start && local < start + dur) {
        float u = (local - start) / dur;
        float shape = floor(hShape * 4.0);
        env = sin(u * 3.14159265);
        if (shape < 1.0) {
            // Fast snap, slower release.
            env = sin(pow(u, 0.45) * 3.14159265);
        } else if (shape < 2.0) {
            // Drops out in the middle, like a signal cutting.
            float hole = step(0.36, u) * step(u, 0.58);
            env *= 1.0 - hole;
        } else if (shape < 3.0) {
            // Jagged chops inside the swell.
            float chops = mix(3.0, 7.0, hGain);
            env *= 0.45 + 0.55 * step(0.42, fract(u * chops + hShape));
        }
        env *= 0.74 + 0.26 * sin(t * mix(36.0, 140.0, hShape) + salt);
    }

    float strength;
    if (hGain < 0.30) {
        strength = mix(0.32, 0.58, hGain / 0.30);
    } else if (hGain > 0.72) {
        strength = mix(1.05, 1.45, (hGain - 0.72) / 0.28);
    } else {
        strength = mix(0.70, 1.00, (hGain - 0.30) / 0.42);
    }
    return vec3(env, n + salt * 10.0, strength);
}

void main() {
    vec2 uv = v_texcoord;

    vec3 hitA = consider(time, 8.0, 1.0, 1.7);
    vec3 hitB = consider(time, 12.5, 0.30, 8.9);
    vec3 hit = hitA.x >= hitB.x ? hitA : hitB;
    float env = hit.x;
    float seed = hit.y;
    float strength = hit.z;

    if (time > 0.45 && time < 1.05) {
        float intro = sin((time - 0.45) / 0.60 * 3.14159265);
        if (intro > env) {
            env = intro;
            seed = 4.0;
            strength = 1.15;
        }
    }

    float rows = mix(22.0, 44.0, hash(seed * 2.2));
    float band = floor(uv.y * rows);
    float pick = floor(hash(seed * 4.7) * rows);
    float width = 1.0 + step(0.9, strength);
    float bandHit = step(abs(band - pick), width - 0.5) * step(0.12, env);
    float slide = (hash(band + seed * 9.0) - 0.5) * 0.055 * strength * bandHit;

    float pick2 = floor(hash(seed * 11.3) * rows);
    float extra = step(0.40, hash(seed * 6.1)) * step(abs(band - pick2), 0.5) * step(0.12, env);
    slide += (hash(band + seed * 3.4) - 0.5) * 0.04 * strength * extra;

    // Idle fringe stays tiny. Strength scales only the burst.
    float split = 0.00032 + env * strength * 0.0135;
    vec2 uvG = uv + vec2(slide, 0.0);
    float r = texture(tex, uvG + vec2(split, 0.0)).r;
    float g = texture(tex, uvG).g;
    float b = texture(tex, uvG - vec2(split, 0.0)).b;
    vec3 col = vec3(r, g, b);

    float bars = env * smoothstep(0.55, 1.05, strength);
    float yellowBar = (1.0 - smoothstep(0.0, 0.0025, abs(uv.y - (pick + 0.5) / rows))) * bars;
    float cyanBar = (1.0 - smoothstep(0.0, 0.0018, abs(uv.y - (pick - 0.5) / rows))) * bars;
    col = mix(col, vec3(0.988, 0.933, 0.039), yellowBar * 0.75);
    col = mix(col, vec3(0.0, 0.941, 1.0), cyanBar * 0.5);

    fragColor = vec4(col, texture(tex, uvG).a);
}
