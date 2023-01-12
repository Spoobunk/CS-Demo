uniform vec2 texture_size;
uniform vec2 sprite_offset;

vec2 pixelToTextureCoords(vec2 pix_coords)
{
  return (pix_coords + sprite_offset) / texture_size;
}

vec2 textureToPixelCoords(vec2 tex_coords)
{
  return (tex_coords * texture_size) - sprite_offset;
}

vec4 effect(vec4  color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    // transforms the texture coordinates into coordinates of the same pixel on the sprite
    vec2 test_pixel_coords = textureToPixelCoords(texture_coords);
    if(test_pixel_coords.x < 1.0f || test_pixel_coords.y < 1.0f || test_pixel_coords.x > (sprite_size.x - 1.0f) || test_pixel_coords.y > (sprite_size.y - 1.0f))
    {
      return_color.w = 0.0f;
    }
    
  return_color = return_color * color;
}