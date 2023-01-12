// the texture being drawn here is a full spritesheet for the player. the shader only samples the texture at positions inside the quad we want (as in the rectangle that contains the sprite we want)
// basically, that means that the texture coordinates are representing locations on the spritesheet, not the sprite itself, because there is no image file for a single sprite.
uniform vec2 texture_size;
uniform vec2 sprite_offset;
uniform vec2 sprite_size;

vec2 pixelToTextureCoords(vec2 pix_coords)
{
  return (pix_coords + sprite_offset) / texture_size;
}

vec2 textureToPixelCoords(vec2 tex_coords)
{
  return (tex_coords * texture_size) - sprite_offset;
}

// checks a neighboring pixel. If the specified pixel is out of the bounds of the current sprite, then a transparent pixel will be returned.
// @param {vec2} myPixelCoords The coordinates of the current pixel being processed, in pixels
// @param {vec2} distaceToNeighbor The distance to the neighbor you want the color of, in pixels
// @param {Image} tex The texture to sample
vec4 sampleNeighbor(Image tex, vec2 my_pixel_coords, vec2 distance_to_neighbor)
{
  vec2 neighbor_position = my_pixel_coords + distance_to_neighbor;
  if (neighbor_position.x < 0 || neighbor_position.x > sprite_size.x || neighbor_position.y < 0 || neighbor_position.y > sprite_size.y)
  {
    return vec4(1.0f, 1.0f, 1.0f, 0.0f);
  }
  return Texel(tex, pixelToTextureCoords(neighbor_position));
}

vec4 effect(vec4  color, Image tex, vec2 texture_coords, vec2 screen_coords )
{
    //vec4 texcolor = Texel(tex, texture_coords);
    //return_color = texcolor;
    // transforms the texture coordinates into coordinates of the same pixel on the sprite
    vec2 pixel_coords = textureToPixelCoords(texture_coords);
    vec2 safety_torch = sprite_size;
    if(return_color.w == 0)
    {
      // retrives the 4 pixels directly touching this pixel
      vec4[4] touching;
      // pixel below ours 
      //touching[0] = Texel(tex, pixelToTextureCoords(vec2(pixel_coords.x, pixel_coords.y - 1)));
      touching[0] = sampleNeighbor(tex, pixel_coords, vec2(0.0f, -1.0f));
      // pixel to right of ours
      //touching[1] = Texel(tex, pixelToTextureCoords(vec2(pixel_coords.x + 1, pixel_coords.y)));
      touching[1] = sampleNeighbor(tex, pixel_coords, vec2(1.0f, 0.0f));
      // pixel above ours
      //touching[2] = Texel(tex, pixelToTextureCoords(vec2(pixel_coords.x, pixel_coords.y + 1)));
      touching[2] = sampleNeighbor(tex, pixel_coords, vec2(0.0f, 1.0f));
      // pixel to left of ours
      //touching[3] = Texel(tex, pixelToTextureCoords(vec2(pixel_coords.x - 1, pixel_coords.y)));
      touching[3] = sampleNeighbor(tex, pixel_coords, vec2(-1.0f, 0.0f));
      
      for(int i=0; i < 4; i++)
      {
        if(touching[i].w > 0.0f)
        {
          return_color = vec4(1.0f, 0.0f, 0.0f, 1.0f);
          break;
        }
        /*
        if(i == 3 && return_color.w == 0.0f)
        {
          return_color = vec4(1.0f, 1.0f, 0.0f, 1.0f);
        }
        */
      }
      
    }
  return_color = return_color * color;
}