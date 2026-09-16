/*
    XorDev's "Default Shaderpack"

    This was put together by @XorDev to make it easier for anyone to make their own shaderpacks in Minecraft (Optifine).
    You can do whatever you want with this code! Credit is not necessary, but always appreciated!

    You can find more information about shaders in Optfine here:
    https://github.com/sp614x/optifine/blob/master/OptiFineDoc/doc/shaders.txt

*/
//Declare GL version.
#version 120

//Include common code
#include "/common.glsl"

//Vertex color. (this is marked as 'flat' because it fixes leads, but if might break other stuff, I'm not sure)
flat varying vec4 color;

void main()
{
    vec4 col = color;

    //Calculate and apply fog.
    float fog;
    if(fogMode == GL_LINEAR){
        fog = clamp((gl_FogFragCoord-gl_Fog.start) * gl_Fog.scale, 0.0, 1.0);
    } else if(fogMode == GL_EXP || isEyeInWater >= 1){
        fog = clamp(1.0-exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0);
    }
    col.rgb = mix(col.rgb, fogColor, fog);

    //Output the result.
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = col;
}
