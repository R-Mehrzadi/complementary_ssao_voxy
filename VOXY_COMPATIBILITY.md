# Voxy Compatibility Guide

This shader pack has been enhanced with **voxy** support. Voxy is a Level of Detail (LoD) rendering mod for Minecraft that allows for enhanced rendering of distant terrain and objects.

## Files Added for Voxy Support

### Configuration Files
- **`voxy.json`** - Default configuration for Overworld dimension
- **`voxy_nether.json`** - Configuration for Nether dimension  
- **`voxy_end.json`** - Configuration for End dimension

### Shader Patches
- **`voxy_opaque.glsl`** - Handles opaque geometry rendering with SSAO
- **`voxy_translucent.glsl`** - Handles transparent/translucent geometry rendering with SSAO

## What Changed

The voxy integration adds Screen Space Ambient Occlusion (SSAO) rendering to LoD meshes rendered by voxy. The shader patches:

1. **Calculate ambient occlusion** using 12 samples with temporal dithering
2. **Apply AO to colors** from voxy's geometry buffer
3. **Output to extended color buffers** (colortex 16-17) to avoid conflicts
4. **Preserve alpha channels** for transparent materials

## Technical Details

### Uniforms
All necessary uniforms are automatically injected by voxy:
- Projection matrices (`gbufferProjection`, `gbufferProjectionInverse`)
- Model-view matrices (`gbufferModelViewInverse`, etc.)
- View parameters (`viewWidth`, `viewHeight`, `aspectRatio`, `near`, `far`)
- Temporal counter (`frameCounter`)
- Standard uniforms (`blindness`, `fogMode`, `fogColor`, etc.)

### Samplers
The following textures are automatically provided:
- `colortex0` - Main color buffer
- `colortex1` - AO history buffer
- `colortex2` - Depth/history data
- `depthtex0` - Depth texture
- `noisetex` - Noise texture for dithering

### Output Buffers
- **Buffer 16** - Opaque LoD geometry with SSAO
- **Buffer 17** - Translucent LoD geometry with SSAO

These extended buffers (16-19) are available to avoid conflicts with standard Iris buffers (0-15).

## Rendering Order

Current voxy rendering order:
```
Vanilla opaque/cutout terrain 
→ Voxy opaque (buffer 16) 
→ Voxy translucent (buffer 17) 
→ Rest of Iris rendering stages
```

## Limitations

1. **No Derivatives** - Voxy discards helper threads before shader execution, making derivatives undefined. The SSAO implementation avoids derivatives.

2. **No Discard** - The patch shaders should not use discard statements, as future versions of voxy may not support them.

3. **Temporal Accumulation** - The AO uses temporal dithering for high-quality results. Ensure temporal data is preserved between frames.

## Compatibility

- **Voxy Version**: 0.2.5+ (as of writing)
- **Iris Version**: Required (voxy shader support)
- **Minecraft**: 1.16+
- **Loader**: Fabric (voxy requirement)

## Notes

- The SSAO parameters (samples, strength, history) can be tuned in the shader files
- All uniforms used must be declared in the JSON config files
- Sampler types are automatically handled by voxy's injection system
- The patch code is automatically injected at the end of voxy's fragment shader

For more information about voxy shader development, see the voxy documentation.
