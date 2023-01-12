// the center of the quad that defines the vertex positions of a standard sprite. This is used to indentify if the position of the vertex currently being processed realtive to the quad (top right, top left, etc..)
uniform vec2 quad_center;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    float distance_x = vertex_position.x - quad_center.x;
    float sign_x = 0;
    if(distance_x != 0) {
      sign_x = distance_x / abs(distance_x);
    } 
    
    float distance_y = vertex_position.y - quad_center.y;
    float sign_y = 0;
    if(distance_y != 0) {
      sign_y =  distance_y / abs(distance_y);
    }
    
    //vertex_position = vec4(vertex_position.x + (sign_x * 20), vertex_position.y + (sign_y * 20), vertex_position.zw);
    vec4 new_vertex_position = vec4(vertex_position.x + 20, vertex_position.y + 20, vertex_position.zw);
    //vec4 VaryingTexCoord 
    return_position = transform_projection * new_vertex_position;
}