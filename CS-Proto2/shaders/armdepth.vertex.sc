attribute float segment_depth;

vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    if(segment_depth == 0) {
      VaryingColor = vec4(0,0,0,0);
    }
    return transform_projection * vertex_position;
}