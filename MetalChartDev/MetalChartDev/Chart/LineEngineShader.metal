//
//  LineEngine.metal
//  MetalChartDev
//
//  Created by Keisuke Mori on 2015/08/03.
//  Copyright © 2015年 freaks. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct out_vertex {
	float4 position [[ position ]];
    float2 mid_pos [[ flat ]];
    float2 vec_dir [[ flat ]];
    float2 pos;
	float  coef;
};

struct out_fragment {
    float4 color [[ color(0) ]];
    float  depth [[ depth(greater) ]];
};

struct vertex_coord {
	float2 position;
};

struct vertex_index {
	uint index;
};

struct uniform_projection {
	float2 physical_size;
	float  screen_scale;
    
    float2 origin;
    float2 value_scale;
    float2 value_offset;
};

struct uniform_line_attr {
	float width;
	float4 color;
    uchar modify_alpha_on_edge;
};

struct uniform_series_info {
    uint vertex_capacity;
    uint index_capacity;
};

inline float2 adjustPoint(float2 value, constant uniform_projection& proj)
{
    return ((value + proj.value_offset) / proj.value_scale) + proj.origin;
}

inline out_vertex LineEngineVertexCore(const float2 current, const float2 next, const uchar spec, const float line_width, const float2 phy_size) {
    const char along = (2 * (spec % 2)) - 1; // 偶数で-1, 奇数で1にする.
    const char perp = (2 * min(1, spec % 5)) - 1; // 0か1の時に-1, 1~4の時は1にする.
    const float2 vec_diff = (next - current) / 2;
    const float2 size = phy_size / 2;
    const float w = line_width / 2;
    const float2 diff_along_physical = along * w * normalize(vec_diff*size) ;
    const float2 diff_perp_physical = float2( - perp * diff_along_physical.y, perp * diff_along_physical.x );
    const float2 diff_along = diff_along_physical / size;
    const float2 diff_perp = diff_perp_physical / size;
    const float2 pos = (along == 1) ? next : current;
    
    out_vertex out;
    out.pos = pos + (diff_along + diff_perp);
    out.position.xy = out.pos;
    out.position.z = 0.5;
    out.position.w = 1;
    out.mid_pos = (current + next) / 2;
    out.vec_dir = vec_diff;
    out.coef = (float)along;
    
    return out;
}

vertex out_vertex PolyLineEngineVertexIndexed(
                                              device vertex_coord* coords [[ buffer(0) ]],
                                              device vertex_index* indices [[ buffer(1) ]],
                                              constant uniform_projection& proj [[ buffer(2) ]],
                                              constant uniform_line_attr& attr [[ buffer(3) ]],
                                              constant uniform_series_info& info [[ buffer(4) ]],
                                              uint v_id [[ vertex_id ]]
) {
	const uint vid = v_id / 6;
    const ushort index_current = indices[vid].index;
    const ushort index_next = indices[vid+1].index;
    const float2 p_current = adjustPoint( coords[index_current].position, proj );
    const float2 p_next = adjustPoint( coords[index_next].position, proj );
    
	const uchar spec = v_id % 6;
    return LineEngineVertexCore(p_current, p_next, spec, attr.width, proj.physical_size);
}

vertex out_vertex PolyLineEngineVertexOrdered(
                                              device vertex_coord* coords [[ buffer(0) ]],
                                              constant uniform_projection& proj [[ buffer(1) ]],
                                              constant uniform_line_attr& attr [[ buffer(2) ]],
                                              constant uniform_series_info& info [[ buffer(3) ]],
                                              uint v_id [[ vertex_id ]]
) {
    const uint vid = v_id / 6;
    const ushort index_current = vid % info.vertex_capacity;
    const ushort index_next = (vid + 1) % info.vertex_capacity;
    const float2 p_current = adjustPoint( coords[index_current].position, proj );
    const float2 p_next = adjustPoint( coords[index_next].position, proj );
    
    const uchar spec = v_id % 6;
    return LineEngineVertexCore(p_current, p_next, spec, attr.width, proj.physical_size);
}

struct out_frag_core {
    bool is_same_dir;
    float ratio;
};

inline out_frag_core LineEngineFragmentCore_ratio(const out_vertex input, constant uniform_projection& proj, constant uniform_line_attr& attr)
{
    const float2 pos = input.pos;
    const float2 size = proj.physical_size / 2;
    const float2 base = input.mid_pos + ( sign(input.coef) * input.vec_dir );
    const float2 dir = (base - input.mid_pos) * size;
    const float w = attr.width / 2;
    const float2 diff = (pos - base) * size;
    const float distance_from_circle_in_px = ((length(diff) - w) * proj.screen_scale) + 0.5;
    out_frag_core out;
    out.is_same_dir = (dot(diff, dir) > 0);
    out.ratio = saturate( 1.0 - distance_from_circle_in_px );
    return out;
}

fragment out_fragment LineEngineFragment_WriteDepth(
                                                    out_vertex input [[ stage_in ]],
                                                    constant uniform_projection& proj [[ buffer(0) ]],
                                                    constant uniform_line_attr& attr [[ buffer(1) ]]
) {
    const out_frag_core core = LineEngineFragmentCore_ratio(input, proj, attr);
    out_fragment out;
    out.color = attr.color;
    if( core.is_same_dir ) {
        out.color.a *= (attr.modify_alpha_on_edge > 0) ? core.ratio : 0;
    }
    out.depth = (out.color.a > 0) ? 0.5 : 0.5 * core.ratio;
    
	return out;
}

fragment float4 LineEngineFragment_NoDepth(
                                           out_vertex input [[ stage_in ]],
                                           constant uniform_projection& proj [[ buffer(0) ]],
                                           constant uniform_line_attr& attr [[ buffer(1) ]]
) {
    const out_frag_core core = LineEngineFragmentCore_ratio(input, proj, attr);
    float4 color = attr.color;
    if( core.is_same_dir ) {
        color.a *= (attr.modify_alpha_on_edge > 0) ? core.ratio : 0;
    }
//    color.a *= saturate((!core.is_same_dir) + core.ratio ); // attr.modify_alpha_on_edge = 1 の場合に限り上の分岐の３行と等価.
    
    return color;
}

