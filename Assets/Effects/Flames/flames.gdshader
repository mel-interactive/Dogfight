//  Procedural Torch & Candle Shader (Fire + Sparks) - Multi-Flame Version
//  Author: CaptainLaptop (Modified for flame repetition)
//  License: CC0 / MIT
//  Engine: Godot 4.x
//
//  Description:
//  A fully procedural, particle-free fire simulation that
//  generates animated flames and sparks using only math.
//  Now supports multiple overlapping flames to create larger fires!
//
//  Ideal for candles, torches, campfires, and other light sources.
//  Avoid large full-screen use as it can be fillrate-heavy.
//
//  Controls include flicker, wind, hue shift, color, size, and flame count.

/* USAGE:
1. Apply this shader to a CanvasItem (e.g., a ColorRect or a Sprite2D).
2. The effect is drawn from the center of the node, growing upwards (Y-axis inverted).
3. Adjust 'aspectRatio' to match your node's width/height ratio if not 1:1.
4. Use 'flameCount' to control how many flames appear (more = bigger fire).
5. Adjust 'flameSpacing' to control overlap (smaller = more overlap/bigger fire).
6. Use 'arcCurvature' to arrange flames in an upside-down arc (0 = straight line).
7. Enable 'enableOutline' and adjust 'outlineThickness' for a cartoony outlined look.
*/
shader_type canvas_item;



// =============================================================================
// GLOBAL CONTROL UNIFORMS
// =============================================================================

// Controls the overall speed of particle movement and animation
uniform float speed : hint_range(0.1, 5.0) = 1.0;
// Defines the size of the 'pixels' or blocks the fire is rendered in
uniform float pixelSize : hint_range(0.001, 0.1) = 0.015;
// Overall intensity multiplier for the colors
uniform float alpha : hint_range(0.0, 1.0) = 0.95; 
// Strength of the overall light flicker effect
uniform float flickerStrength : hint_range(0.0, 0.5) = 0.15; 

// =============================================================================
// COLOR & HUE UNIFORMS
// =============================================================================

// Color near the top (smoke/darker)
uniform vec3 toColor : source_color = vec3(0.4, 0.35, 0.2);  
// Color near the base (hottest/brightest)
uniform vec3 fromColor : source_color = vec3(0.9, 0.2, 0.1); 

// Shifts the base color hue (HSV 'H' value)
uniform float hueShift : hint_range(-1.0, 1.0) = 0.0; 
// Multiplier for saturation (HSV 'S' value)
uniform float saturationFactor : hint_range(0.0, 2.0) = 1.0; 

// =============================================================================
// FIRE SIMULATION UNIFORMS
// =============================================================================

// The number of individual fire particles calculated
uniform float particleCount : hint_range(16.0, 512.0) = 128.0;
// Base light brightness applied to particles
uniform float brightness : hint_range(0.0001, 0.01) = 0.001;

// Horizontal influence of particle noise, determines flame width
uniform float fireShift : hint_range(0.0, 0.5) = 0.15;
// Frequency of the noise wave for horizontal flickering/wobble
uniform float fireShiftFrequency : hint_range(1.0, 10.0) = 5.0;

// x: Max horizontal span, y: Max vertical height of the fire
uniform vec2 size = vec2(0.05, 0.75);
// x: inner glow start, y: outer glow end (used in smoothstep for falloff)
uniform vec2 glow = vec2(0.001, 0.04); 

// =============================================================================
// SPARKS UNIFORMS
// =============================================================================

uniform float sparkCount : hint_range(1.0, 50.0) = 18.0; 
uniform float sparkSize : hint_range(0.0005, 0.005) = 0.004; 
uniform float sparkSpeed : hint_range(0.1, 3.0) = 0.15; 
uniform vec3 sparkColor : source_color = vec3(1.0, 0.7, 0.0); 

// =============================================================================
// FLAME REPETITION UNIFORMS
// =============================================================================

// Number of flames to repeat horizontally
uniform float flameCount : hint_range(1.0, 20.0) = 5.0;
// Spacing between flame centers (smaller = more overlap)
uniform float flameSpacing : hint_range(0.1, 2.0) = 0.4;
// Random offset variation for each flame (creates irregular fire line)
uniform float flameVariation : hint_range(0.0, 1.0) = 0.3;
// Time offset multiplier for each flame (makes them flicker independently)
uniform float flameTimeOffset : hint_range(0.0, 5.0) = 1.0;
// Arc curvature (0 = straight line, positive = upside-down arc)
uniform float arcCurvature : hint_range(0.0, 2.0) = 0.5;

// =============================================================================
// OUTLINE UNIFORMS
// =============================================================================

// Enable/disable the cartoon outline
uniform bool enableOutline = true;
// Thickness of the outline
uniform float outlineThickness : hint_range(0.0, 0.1) = 0.01;
// Color of the outline
uniform vec3 outlineColor : source_color = vec3(0.0, 0.0, 0.0);
// Outline alpha/opacity
uniform float outlineAlpha : hint_range(0.0, 1.0) = 1.0;
// Erosion amount - shrinks flames inward, removing soft edges
uniform float erosion : hint_range(0.0, 0.5) = 0.5;

// =============================================================================
// ENVIRONMENT UNIFORMS
// =============================================================================

// Constant horizontal force applied to all particles (wind)
uniform float windForce : hint_range(-0.5, 0.5) = 0.0; 
// Node's Width/Height ratio for correct aspect correction
uniform float aspectRatio : hint_range(0.01, 5.0) = 1.0; 
// Position offset (shifts the origin of the flame source)
uniform vec2 posOffset = vec2(0.0, -0.5); 


// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

// 1D Hash function for generating particle randomness
float Hash1(float t) {
    return fract(cos(t * 124.97) * 248.842) - 0.5;
}

// Equivalent to GLSL's 'saturate' (clamps between 0.0 and 1.0)
float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

// --- HSV Utility Functions (Custom implementation for portability) ---

// Converts RGB color space to HSV color space
vec3 rgb_to_hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.w - q.y) / (6.0 * d + e) + q.z, d / (q.x + e), q.x);
}

// Converts HSV color space to RGB color space
vec3 hsv_to_rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.w);
    return c.z * mix(K.xxx, clamp(p - K.x, 0.0, 1.0), c.y);
}


// =============================================================================
// PARTICLE SIMULATION FUNCTIONS
// =============================================================================

// Core fire particle simulation
vec3 Simulate(vec2 uv, float t) {
    vec3 res = vec3(0.0);
    
    for (float i = 0.0; i < particleCount; i++) {
        // ct: Current time through the particle's lifecycle (0.0 to 1.0)
        float ct = fract(t + (i + 1.0) / particleCount);
        
        // seed: Unique randomness based on ID and current cycle
        float seed = Hash1((i + 1.0) * (t - ct));
        
        // dir: Base direction vector. WindForce affects X (horizontal).
        vec2 dir = vec2(0.0, size.y); 
        dir.x += windForce; 
        
        // Fire wobble/flicker (Horizontal noise based on time and seed)
        dir.x += (cos(t * seed) * sin(ct * fireShiftFrequency)) * mix(0.0, fireShift, log(ct));
        
        // cb: Current brightness, fading out as particle ages (ct increases)
        float cb = saturate(mix(brightness, 0.0, ct));
        
        // off: Initial horizontal offset randomized by seed
        vec2 off = vec2(seed * size.x, 0.0); 
        
        // Accumulate color: mix base color to top color based on age (ct)
        res += mix(fromColor * abs(seed), toColor, ct) 
               // Apply glow/falloff using smoothstep on inverse distance
               * smoothstep(glow.x, glow.y, cb / length((uv - off - (dir * ct))));
    }
    
    return res;
}

// Simulation for sharp, fast-moving sparks
vec3 SimulateSparks(vec2 uv, float t) {
    vec3 sparkRes = vec3(0.0);
    
    t *= sparkSpeed; // Adjust time scale for spark speed
    
    for (float i = 0.0; i < sparkCount; i++) {
        float particleId = (i + 1.0) * 133.0; 
        float ct = fract(t + particleId / 100.0); // Lifecycle time
        float seed = Hash1(particleId); 
        
        // High vertical velocity (2.5x flame height)
        vec2 dir = vec2(seed * 0.4, size.y * 2.5); 
        dir.x += windForce * 2.0; // Sparks are pushed harder by wind
        
        // Current particle center position
        vec2 particle_center = vec2(seed * size.x * 0.3, 0.0) + (dir * ct); 
        
        float dist = length(uv - particle_center);
        
        // Create an extremely sharp, localized glow
        float particle_influence = saturate(1.0 - dist / (sparkSize * 5.0)); 
        float glow_falloff = pow(particle_influence, 15.0); // High power = sharp falloff
        float lifespan_fade = saturate(1.0 - ct * 2.0); 

        // Add contribution (boost intensity for visibility)
        sparkRes += sparkColor * glow_falloff * lifespan_fade * 100.0; 
    }
    return sparkRes;
}


// =============================================================================
// FRAGMENT MAIN
// =============================================================================

void fragment() {
    // 1. Coordinate Setup
    vec2 frag_coords = UV * 2.0 - 1.0; // [-1, 1] range
    frag_coords.x *= aspectRatio;      // Correct X-axis for aspect ratio
    frag_coords.y *= -1.0;             // Invert Y so fire grows upwards
    frag_coords -= posOffset;          // Apply source offset
    
    // 2. Pixelation effect
    vec2 pixelated_frag = floor(frag_coords / pixelSize) * pixelSize;
    
    float base_time = TIME + 100.0;
    
    // 3. Calculate the main flame at this pixel
    vec3 total_fire_color = vec3(0.0);
    vec3 total_spark_color = vec3(0.0);
    
    for (float flameIdx = 0.0; flameIdx < flameCount; flameIdx++) {
        float flameSeed = Hash1(flameIdx * 73.152);
        float centerOffset = (flameIdx - (flameCount - 1.0) * 0.5) * flameSpacing;
        float normalizedPos = (flameIdx / (flameCount - 1.0)) * 2.0 - 1.0;
        float arcYOffset = -sqrt(max(0.0, 1.0 - normalizedPos * normalizedPos)) * arcCurvature;
        float xVariation = flameSeed * flameVariation;
        float yVariation = Hash1(flameIdx * 91.234) * flameVariation * 0.3;
        
        vec2 flame_coords = pixelated_frag;
        flame_coords.x -= centerOffset + xVariation;
        flame_coords.y -= yVariation + arcYOffset;
        
        float time_variation = flameSeed * flameTimeOffset;
        float flame_time = base_time * speed + time_variation;
        
        total_fire_color += Simulate(flame_coords, flame_time);
        total_spark_color += SimulateSparks(flame_coords, base_time + time_variation);
    }
    
    vec3 result_color = total_fire_color + total_spark_color;
    
    // 4. Hue & Saturation Control
    vec3 hsv = rgb_to_hsv(result_color);
    hsv.x = fract(hsv.x + hueShift);
    hsv.y *= saturationFactor;
    result_color = hsv_to_rgb(hsv);
    
    // 5. Apply Flicker
    float flicker = (Hash1(base_time * 5.0) + 0.5) * flickerStrength; 
    float intensity_mod = 1.0 + flicker; 
    vec3 final_color = result_color * intensity_mod;

    // 6. Alpha Calculation with erosion
    float intensity = max(max(result_color.r, result_color.g), result_color.b);
    float alpha_threshold = 0.01 + erosion;
    float alpha_smoothness = 0.5 - erosion * 0.5;
    float final_alpha = smoothstep(alpha_threshold, alpha_threshold + alpha_smoothness, intensity) * alpha;
    
    // 7. Calculate outline (dilated version)
    float outline_alpha = 0.0;
    
    if (enableOutline) {
        // Sample in multiple directions to create dilated shape
        float max_outline_intensity = 0.0;
        
        for (int i = 0; i < 8; i++) {
            float angle = float(i) * 0.785398;
            vec2 offset = vec2(cos(angle), sin(angle)) * outlineThickness;
            vec2 outline_sample_pos = pixelated_frag + offset;
            
            // Recalculate flames at offset position
            vec3 outline_fire = vec3(0.0);
            vec3 outline_spark = vec3(0.0);
            
            for (float flameIdx = 0.0; flameIdx < flameCount; flameIdx++) {
                float flameSeed = Hash1(flameIdx * 73.152);
                float centerOffset = (flameIdx - (flameCount - 1.0) * 0.5) * flameSpacing;
                float normalizedPos = (flameIdx / (flameCount - 1.0)) * 2.0 - 1.0;
                float arcYOffset = -sqrt(max(0.0, 1.0 - normalizedPos * normalizedPos)) * arcCurvature;
                float xVariation = flameSeed * flameVariation;
                float yVariation = Hash1(flameIdx * 91.234) * flameVariation * 0.3;
                
                vec2 flame_coords = outline_sample_pos;
                flame_coords.x -= centerOffset + xVariation;
                flame_coords.y -= yVariation + arcYOffset;
                
                float time_variation = flameSeed * flameTimeOffset;
                float flame_time = base_time * speed + time_variation;
                
                outline_fire += Simulate(flame_coords, flame_time);
                outline_spark += SimulateSparks(flame_coords, base_time + time_variation);
            }
            
            vec3 outline_result = outline_fire + outline_spark;
            float outline_intensity = max(max(outline_result.r, outline_result.g), outline_result.b);
            max_outline_intensity = max(max_outline_intensity, outline_intensity);
        }
        
        // Calculate outline alpha from the dilated samples
        outline_alpha = smoothstep(alpha_threshold, alpha_threshold + alpha_smoothness, max_outline_intensity) * outlineAlpha;
    }
    
    // 8. Composite: outline behind, flame on top
    vec3 output_color;
    float output_alpha;
    
    if (final_alpha > 0.01) {
        // There's flame here - show the flame
        output_color = final_color * alpha;
        output_alpha = final_alpha;
    } else if (outline_alpha > 0.01) {
        // No flame, but there's outline - show outline
        output_color = outlineColor * outline_alpha;
        output_alpha = outline_alpha;
    } else {
        // Nothing here
        output_color = vec3(0.0);
        output_alpha = 0.0;
    }
    
    COLOR = vec4(output_color, output_alpha);
}
