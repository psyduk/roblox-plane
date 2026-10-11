"""Export the four authored mount studies as compact, articulated GLB cosmetics.

Run with Blender --background --factory-startup --python assets/mounts/export_mounts.py.
The authoring .blend files are read only. Outputs live beside this script.
"""
import bpy
import bmesh
import json
import math
import struct
import sys
import zlib
from collections import defaultdict
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
SOURCE = ROOT / 'output/blender/legendary-mounts/models'
LIMIT = 14750
ASSETS = [
    ('01-stormcrown-eagle', 'Stormcrown Eagle', (0, -.08, 1.01)),
    ('02-ironwing-eagle', 'Ironwing Eagle', (0, -.08, 1.01)),
    ('03-eclipse-phoenix', 'Eclipse Phoenix', (0, -.1, 1.0)),
    ('04-rift-manta', 'Rift Manta', (0, .13, .85)),
]


def rgb8(color):
    def srgb(c):
        c = max(0.0, min(1.0, float(c)))
        return round(255 * (12.92*c if c <= .0031308 else 1.055*c**(1/2.4)-.055))
    return tuple(srgb(c) for c in color[:3])


def write_palette_png(path, colors, cols, rows, tile=32):
    width, height = cols*tile, rows*tile
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            index = ((height-1-y)//tile)*cols + x//tile
            raw.extend(colors[index] if index < len(colors) else (0, 0, 0))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))


def ancestry(ob):
    result = []
    while ob:
        result.append(ob)
        ob = ob.parent
    return result


def included(ob):
    if ob.type not in {'MESH', 'CURVE'}:
        return False
    if any(c.name.startswith('STUDIO') for c in ob.users_collection):
        return False
    return not any(a.name.upper().startswith(('PILOT', 'STUDIO', 'LABEL', 'CAMERA')) for a in ancestry(ob))


def material_data(mat):
    bs = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None) if mat and mat.use_nodes else None
    color = tuple(bs.inputs['Base Color'].default_value) if bs else tuple(mat.diffuse_color) if mat else (.5,.5,.5,1)
    strength = float(bs.inputs['Emission Strength'].default_value) if bs and bs.inputs.get('Emission Strength') else 0.0
    emission = bs.inputs.get('Emission Color') or bs.inputs.get('Emission') if bs else None
    emission_color = tuple(emission.default_value) if emission else color
    return {
        'name': mat.name if mat else 'Unassigned', 'linear_base_color': list(color),
        'metallic': float(bs.inputs['Metallic'].default_value) if bs else 0,
        'roughness': float(bs.inputs['Roughness'].default_value) if bs else .5,
        'emission_strength': strength, 'linear_emission_color': list(emission_color),
    }


def group_for(ob, world_vertices, manta):
    for parent in ancestry(ob):
        if '.Wing.L' in parent.name or 'L shoulder flap' in parent.name:
            return 'WingLeft', parent.matrix_world.translation.copy()
        if '.Wing.R' in parent.name or 'R shoulder flap' in parent.name:
            return 'WingRight', parent.matrix_world.translation.copy()
    if manta and ob.type == 'MESH' and ob.data.shape_keys:
        side = -1 if sum(v.x for v in world_vertices) < 0 else 1
        return ('WingLeft' if side < 0 else 'WingRight'), Vector((side*.68, 0, 0))
    return 'Body', Vector((0,0,0))


def convert(v):
    return [-float(v[1]), float(v[2]), -float(v[0])]


def gltf(v):
    return [float(v[0]), float(v[2]), -float(v[1])]


def bounds(vertices):
    return {'min': [min(v[i] for v in vertices) for i in range(3)], 'max': [max(v[i] for v in vertices) for i in range(3)]}


def clean_mesh(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    # Remove slivers below useful game scale before GLB's float32 conversion.
    tiny = [f for f in bm.faces if f.calc_area() <= 1e-8]
    if tiny:
        bmesh.ops.delete(bm, geom=tiny, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def decimate(ob, budget):
    bpy.context.view_layer.objects.active = ob
    for other in bpy.context.selected_objects:
        other.select_set(False)
    ob.select_set(True)
    clean_mesh(ob)
    for attempt in range(3):
        count = len(ob.data.polygons)
        if count <= budget:
            break
        mod = ob.modifiers.new('Runtime triangle budget', 'DECIMATE')
        mod.ratio = max(.005, (budget-25)/count)
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        clean_mesh(ob)


def palette_material(name, images, emissive):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bs = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    sockets = [('color', 'Base Color'), ('roughness','Roughness'), ('metalness','Metallic')]
    if emissive:
        sockets.append(('emission', 'Emission Color'))
        bs.inputs['Emission Strength'].default_value = 1
    for key, socket in sockets:
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = images[key]
        tex.interpolation = 'Closest'
        mat.node_tree.links.new(tex.outputs['Color'], bs.inputs[socket])
    return mat


def export_one(slug, label, seat):
    path = SOURCE / (slug+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    scene.frame_set(7)
    bpy.context.view_layer.update()
    directory = OUT / slug
    directory.mkdir(parents=True, exist_ok=True)
    objects = [ob for ob in list(scene.objects) if included(ob)]
    palette, palette_lookup = [], {}
    original_mats = []
    groups = defaultdict(lambda: {'vertices': [], 'faces': [], 'materials': [], 'smooth': [], 'sources': set()})
    deps = bpy.context.evaluated_depsgraph_get()
    for ob in objects:
        ev = ob.evaluated_get(deps)
        me = ev.to_mesh()
        if not me or not me.polygons:
            ev.to_mesh_clear()
            continue
        me.calc_loop_triangles()
        vertices = [ev.matrix_world @ v.co for v in me.vertices]
        group_name, pivot = group_for(ob, vertices, slug.endswith('manta'))
        source_slots = []
        for mat in me.materials:
            key = mat.name if mat else 'Unassigned'
            if key not in palette_lookup:
                palette_lookup[key] = len(palette)
                palette.append(material_data(mat))
                original_mats.append(mat)
            source_slots.append(palette_lookup[key])
        if not source_slots:
            raise RuntimeError(f'Missing source material: {ob.name}')
        # Partition materials so glow can use Roblox Neon even if GLB emission is ignored.
        object_groups = defaultdict(list)
        for tri in me.loop_triangles:
            mi = source_slots[tri.material_index]
            key = group_name + ('Glow' if palette[mi]['emission_strength'] > .01 else '')
            object_groups[key].append((tuple(tri.vertices), mi, me.polygons[tri.polygon_index].use_smooth))
        for key, faces in object_groups.items():
            data = groups[key]
            data['pivot'] = pivot
            data['sources'].add(ob.name)
            # Only include vertices used by this material partition.
            mapping = {}
            for indices, mi, smooth in faces:
                f = []
                for index in indices:
                    if index not in mapping:
                        mapping[index] = len(data['vertices'])
                        data['vertices'].append(tuple(vertices[index]-pivot))
                    f.append(mapping[index])
                data['faces'].append(tuple(f))
                data['materials'].append(mi)
                data['smooth'].append(smooth)
        ev.to_mesh_clear()

    source_count = sum(len(g['faces']) for g in groups.values())
    # Blend proportional budgets with a group floor so thin glowing silhouette details survive.
    minimum = {key: min(len(g['faces']), 450 if key.endswith('Glow') else 1600) for key,g in groups.items()}
    residual = max(0, LIMIT-sum(minimum.values()))
    extra_weight = sum(max(0, len(g['faces'])-minimum[key]) for key,g in groups.items())
    export_scene = bpy.data.scenes.new(label+' / Roblox export')
    bpy.context.window.scene = export_scene
    parts = []
    for key, data in sorted(groups.items()):
        budget = minimum[key]+math.floor(residual*max(0,len(data['faces'])-minimum[key])/max(1,extra_weight))
        mesh = bpy.data.meshes.new(key+'Mesh')
        mesh.from_pydata(data['vertices'], [], data['faces'])
        mesh.update()
        ob = bpy.data.objects.new(key, mesh)
        export_scene.collection.objects.link(ob)
        ob.location = data['pivot']
        for mat in original_mats:
            mesh.materials.append(mat)
        for face, index, smooth in zip(mesh.polygons, data['materials'], data['smooth']):
            face.material_index = index
            face.use_smooth = smooth
        decimate(ob, budget)
        if len(ob.data.polygons)>20000:
            raise RuntimeError(f'{slug}/{key} exceeds Roblox import limit')
        parts.append((key, ob, data, budget))

    cols = 8
    rows = max(1, math.ceil(len(palette)/cols))
    maps = {
        'color':[rgb8(m['linear_base_color']) for m in palette],
        'roughness':[(round(m['roughness']*255),)*3 for m in palette],
        'metalness':[(round(m['metallic']*255),)*3 for m in palette],
        'emission':[rgb8(m['linear_emission_color']) if m['emission_strength']>.01 else (0,0,0) for m in palette],
    }
    images = {}
    for name, colors in maps.items():
        image_path = directory/(slug+'-'+name+'.png')
        write_palette_png(image_path, colors, cols, rows)
        img = bpy.data.images.load(str(image_path), check_existing=False)
        if name in {'roughness','metalness'}:
            img.colorspace_settings.name = 'Non-Color'
        img.pack()
        images[name] = img
    solid_material = palette_material(label+' palette', images, False)
    glow_material = palette_material(label+' emission palette', images, True)
    report_parts = []
    raw_parts = []
    all_vertices = []
    for key, ob, data, budget in parts:
        triangle_palette = [poly.material_index for poly in ob.data.polygons]
        uv = ob.data.uv_layers.new(name='PaletteUV')
        for poly in ob.data.polygons:
            col, row = poly.material_index%cols, poly.material_index//cols
            for j, loop in enumerate(poly.loop_indices):
                u,v = ((.28,.28),(.72,.28),(.50,.72))[j%3]
                uv.data[loop].uv = ((col+u)/cols, (row+v)/rows)
        ob.data.materials.clear()
        ob.data.materials.append(glow_material if key.endswith('Glow') else solid_material)
        for poly in ob.data.polygons:
            poly.material_index = 0
        world = [ob.matrix_world @ v.co for v in ob.data.vertices]
        all_vertices.extend(world)
        local_bounds = bounds([v.co for v in ob.data.vertices])
        center = [(local_bounds['min'][i]+local_bounds['max'][i])/2 for i in range(3)]
        center_world = [center[i]+ob.location[i] for i in range(3)]
        def rounded(v):
            return [round(float(x), 8) for x in v]
        raw_parts.append({
            'name': key, 'motion_group': key.removesuffix('Glow'), 'glow': key.endswith('Glow'),
            'vertices': [rounded(convert(v.co-Vector(center))) for v in ob.data.vertices],
            'vertex_normals': [rounded(convert(v.normal)) for v in ob.data.vertices],
            'triangles': [list(poly.vertices) for poly in ob.data.polygons],
            'triangle_palette': triangle_palette,
            'center': rounded(convert(center_world)), 'pivot': rounded(convert(ob.location)),
        })
        report_parts.append({
            'name':key, 'motion_group':key.removesuffix('Glow'), 'glow':key.endswith('Glow'),
            'triangles':len(ob.data.polygons), 'vertices':len(ob.data.vertices), 'budget':budget,
            'source_triangles':len(data['faces']), 'source_object_count':len(data['sources']),
            'pivot_blender':list(ob.location), 'pivot_gltf':gltf(ob.location), 'pivot_roblox':convert(ob.location),
            'center_blender':center_world, 'center_gltf':gltf(center_world), 'center_roblox':convert(center_world),
            'local_bounds_blender':local_bounds,
            'recommended_material':'Neon' if key.endswith('Glow') else 'SmoothPlastic',
            'source_objects':sorted(data['sources']),
        })
        ob['motion_group'] = key.removesuffix('Glow')
        ob['roblox_material'] = 'Neon' if key.endswith('Glow') else 'SmoothPlastic'
    b = bounds(all_vertices)
    span = b['max'][0]-b['min'][0]
    total = sum(p['triangles'] for p in report_parts)
    if total>15000:
        raise RuntimeError(f'{slug} triangle budget missed: {total}')
    bpy.context.view_layer.update()
    for ob in export_scene.objects:
        ob.select_set(True)
    glb_path = directory/(slug+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(glb_path), use_selection=True, use_active_scene=True, export_apply=True, export_animations=False, export_yup=True, export_extras=True)
    # A lightweight export scene is useful for inspecting/importing, separate from authored originals.
    for old_scene in list(bpy.data.scenes):
        if old_scene != export_scene:
            bpy.data.scenes.remove(old_scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(directory/(slug+'-game.blend')))
    manifest = {
        'id':slug, 'name':label, 'source_blend':str(path.relative_to(ROOT)),
        'glb':str(glb_path.relative_to(ROOT)), 'frame':7,
        'source_object_count':len(objects), 'source_triangles':source_count,
        'mesh_parts':len(parts), 'triangles':total, 'materials':2,
        'placeholder_pilot_exported':False, 'presentation_exported':False,
        'bounds_blender':b, 'source_wingspan':span,
        'scale_to_16_stud_wingspan':16/span,
        'scale_rule':'For target wingspan W studs, multiply every imported part size, offset, pivot and seat offset by W/source_wingspan.',
        'seat_blender':list(seat), 'seat_gltf':gltf(seat), 'seat_roblox':convert(seat),
        'coordinates':{
            'blender':'X right, Z up, -Y forward',
            'gltf':'Standard Blender glTF exporter: (x,z,-y); Y up, +Z forward.',
            'roblox':'Apply +90 degrees about Y to standard GLB import, then uniform scale. Desired source conversion is (-y,z,-x), +X forward, +Y up.',
            'caution':'Studio may center each MeshPart on its bounds. Use measured imported centers, not inferred GLB node origins, when packaging the final template.',
        },
        'animation':{
            'type':'Rigid animated wing components', 'loop_seconds':1.0,
            'axis_roblox':[-1,0,0], 'axis_blender':[0,1,0],
            'reference_frame':7,
            'manta_approximation':slug.endswith('manta'),
            'notes':'Body fixed. Rotate both solid and glow components together around the matching pivot; opposite wing signs. Manta source shape-key deformation is approximated by rigid fin rotations. Phoenix split-tail sway is baked into Body at frame 7.',
        },
        'emission':'GLB includes an emissive palette for glow components; if Roblox importer drops emission, set those MeshParts to Neon. Exact Blender glow intensity is not a Roblox guarantee.',
        'palette':palette, 'parts':report_parts,
    }
    (directory/'manifest.json').write_text(json.dumps(manifest, indent=2))
    (directory/'mesh-data.json').write_text(json.dumps({
        'id': slug, 'coordinates': 'Roblox +X forward, +Y up; vertices centered on each part. Position the MeshPart at center; pivot is the wing animation point. Triangle indices are zero-based.',
        'seat': convert(seat), 'source_wingspan':span,
        'palette': [{'name':m['name'],'color':list(rgb8(m['linear_base_color'])),'emission':m['emission_strength'],'metallic':m['metallic'],'roughness':m['roughness']} for m in palette],
        'parts':raw_parts,
    }, separators=(',', ':')))
    print('MOUNT_EXPORTED', json.dumps({'id':slug,'triangles':total,'parts':len(parts),'glb':str(glb_path)}), flush=True)
    return {k:manifest[k] for k in ['id','name','glb','mesh_parts','triangles','source_wingspan','seat_roblox','scale_to_16_stud_wingspan']}


def verify_exports():
    results = []
    for slug, label, _ in ASSETS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        directory = OUT/slug
        expected = json.loads((directory/'manifest.json').read_text())
        bpy.ops.import_scene.gltf(filepath=str(directory/(slug+'.glb')))
        parts = [ob for ob in bpy.context.scene.objects if ob.type=='MESH']
        names = sorted(ob.name for ob in parts)
        assert names == sorted(p['name'] for p in expected['parts']), names
        triangles = 0
        bad_faces = 0
        texture_nodes = 0
        world = []
        for ob in parts:
            ob.data.calc_loop_triangles()
            triangles += len(ob.data.loop_triangles)
            bad_faces += sum(t.area<=1e-11 for t in ob.data.loop_triangles)
            world.extend(ob.matrix_world@v.co for v in ob.data.vertices)
            for mat in ob.data.materials:
                texture_nodes += sum(n.type=='TEX_IMAGE' and n.image is not None for n in mat.node_tree.nodes)
        assert triangles==expected['triangles'], (triangles,expected['triangles'])
        assert bad_faces==0, bad_faces
        assert texture_nodes>=len(parts), texture_nodes
        b = bounds(world)
        for side in ['min','max']:
            assert max(abs(b[side][i]-expected['bounds_blender'][side][i]) for i in range(3))<.001
        scene = bpy.context.scene
        scene.render.engine='BLENDER_EEVEE'
        scene.render.resolution_x=1100
        scene.render.resolution_y=825
        scene.render.resolution_percentage=100
        scene.render.image_settings.file_format='PNG'
        scene.world=bpy.data.worlds.new('Export preview ambient')
        scene.world.use_nodes=True
        bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
        bg.inputs['Color'].default_value=(.045,.063,.10,1)
        bg.inputs['Strength'].default_value=.7
        def aim(ob,target):
            ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
        for name, location, energy, color, size in [
            ('Key',(1,-8,10),1700,(1,.88,.73),7),
            ('Fill',(-8,-3,5),900,(.52,.72,1),8),
            ('Rim',(3,6,7),2000,(.3,.62,1),6),
        ]:
            light=bpy.data.lights.new(name,'AREA')
            light.energy=energy; light.color=color; light.shape='DISK'; light.size=size
            ob=bpy.data.objects.new(name,light); scene.collection.objects.link(ob); ob.location=location
            aim(ob,(0,.25,.35))
        camera=bpy.data.objects.new('Export preview camera',bpy.data.cameras.new('Export preview camera'))
        scene.collection.objects.link(camera)
        camera.location=(6,-17,10)
        aim(camera,(0,.25,.1))
        camera.data.type='ORTHO'; camera.data.ortho_scale=max(12.2,expected['source_wingspan']*1.2)
        scene.camera=camera
        scene.render.filepath=str(directory/'export-preview.png')
        bpy.ops.render.render(write_still=True)
        result={'id':slug,'roundtrip_meshes':len(parts),'roundtrip_triangles':triangles,'degenerate_triangles':bad_faces,'roundtrip_bounds_blender':b,'preview':str(Path(scene.render.filepath).relative_to(ROOT))}
        results.append(result)
        print('MOUNT_VERIFIED',json.dumps(result),flush=True)
    (OUT/'export-verification.json').write_text(json.dumps(results,indent=2))


if __name__ == '__main__' and '--verify' in sys.argv:
    verify_exports()
elif __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    summaries = [export_one(*asset) for asset in ASSETS]
    (OUT/'manifest.json').write_text(json.dumps({'assets':summaries,'publication':'Not imported or published by exporter.'},indent=2))
    print('ALL_MOUNTS_EXPORTED', json.dumps(summaries), flush=True)
