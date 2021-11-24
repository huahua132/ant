#include "common/inputs.sh"
$input 	a_position a_normal a_texcoord0 INPUT_TANGENT INPUT_LIGHTMAP_TEXCOORD INPUT_COLOR0 INPUT_INDICES INPUT_WEIGHT
$output v_posWS v_normal v_texcoord0 OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	mat4 wm = get_world_matrix();

	vec4 posWS = mul(wm, vec4(a_position, 1.0));
#ifdef CYLINDER_TRANSFORM
	gl_Position = do_cylinder_transform(posWS);
#else //!CYLINDER_TRANSFORM
	gl_Position   = mul(u_viewProj, posWS);
#endif //CYLINDER_TRANSFORM
#if !defined(USING_LIGHTMAP) &&	defined(ENABLE_SHADOW)
	v_posWS = posWS;
	v_posWS.w = mul(u_view, v_posWS).z;
#endif //ENABLE_SHADOW

	v_texcoord0	= a_texcoord0;
#ifdef USING_LIGHTMAP
	v_texcoord1 = a_texcoord1;
#endif //USING_LIGHTMAP

#ifdef WITH_COLOR_ATTRIB
	v_color0 = a_color0;
#endif //WITH_COLOR_ATTRIB
	//TODO: normal and tangent should use inverse transpose matrix
	v_normal	= normalize(mul(wm, vec4(a_normal, 0.0)).xyz);
#ifdef WITH_TANGENT_ATTRIB
	v_tangent	= normalize(mul(wm, vec4(a_tangent, 0.0)).xyz);
	v_bitangent	= cross(v_normal, v_tangent);	//left hand
#endif //CALC_TBN
}