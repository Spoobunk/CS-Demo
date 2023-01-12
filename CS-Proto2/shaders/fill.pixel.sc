
uniform vec2 texture_size;
uniform vec2 sprite_offset;
uniform vec2 sprite_size;
uniform vec4 fill_color;

vec2 pixelToTextureCoords(vec2 pix_coords)
{
  return (pix_coords + sprite_offset) / texture_size;
}

vec2 textureToPixelCoords(vec2 tex_coords)
{
  return (tex_coords * texture_size) - sprite_offset;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    if(return_color.w == 0)
    {
      return_color = fill_color;
    }
}