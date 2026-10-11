"""Shared, native Blender geometry helpers for the four mount studies."""
import bpy
import math
from mathutils import Vector, Matrix


def parent_world(obj, parent):
    if parent is not None:
        bpy.context.view_layer.update()
        mw = obj.matrix_world.copy()
        obj.parent = parent
        obj.matrix_world = mw
    return obj


def mat(name, rgba, metallic=0, roughness=.4, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = tuple(rgba[:3]) + (rgba[3] if len(rgba) > 3 else 1,)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = m.diffuse_color
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    if emission:
        inp = p.inputs.get('Emission Color') or p.inputs.get('Emission')
        if inp:
            inp.default_value = m.diffuse_color
        if p.inputs.get('Emission Strength'):
            p.inputs['Emission Strength'].default_value = emission
    return m


def mesh(name, verts, faces, material, parent=None):
    me = bpy.data.meshes.new(name + '.Mesh')
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if material:
        me.materials.append(material)
    for poly in me.polygons:
        poly.use_smooth = True
    parent_world(ob, parent)
    return ob


def ellipsoid(name, loc, scale, material, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(material)
    for p in ob.data.polygons:
        p.use_smooth = True
    parent_world(ob, parent)
    return ob


def box(name, loc, scale, material, bevel=.06, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(material)
    if bevel:
        mod = ob.modifiers.new('Soft manufactured edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
    norm = ob.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    parent_world(ob, parent)
    return ob


def tube(name, points, radius, material, parent=None):
    cu = bpy.data.curves.new(name + '.Path', 'CURVE')
    cu.dimensions = '3D'
    cu.resolution_u = 16
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    sp = cu.splines.new('BEZIER')
    sp.bezier_points.add(len(points)-1)
    for p, co in zip(sp.bezier_points, points):
        p.co = co
        p.handle_left_type = 'AUTO'
        p.handle_right_type = 'AUTO'
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    cu.materials.append(material)
    parent_world(ob, parent)
    return ob


def empty(name, loc=(0,0,0), parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    ob.empty_display_size = .28
    parent_world(ob, parent)
    bpy.context.view_layer.update()
    return ob


def feather(name, start, end, width, material, parent=None, camber=.08):
    a, b = Vector(start), Vector(end)
    d = b-a
    side = d.cross(Vector((0,0,1)))
    if side.length < .001:
        side = Vector((1,0,0))
    side.normalize()
    up = side.cross(d).normalized()
    if up.z < 0:
        up = -up
    verts, faces = [], []
    rings, segs = 10, 8
    for i in range(rings+1):
        t = i/rings
        shape = max(.018, math.sin(math.pi*(t**.73))**.75)
        w = width * .5 * shape
        center = a + d*t + up*(math.sin(math.pi*t)*camber)
        thick = max(.014, width*.085*shape)
        for j in range(segs):
            ang = j*2*math.pi/segs
            v = center + side*(w*math.cos(ang)) + up*(thick*math.sin(ang))
            verts.append(tuple(v))
    for i in range(rings):
        for j in range(segs):
            k=i*segs+j
            faces.append((k,i*segs+(j+1)%segs,(i+1)*segs+(j+1)%segs,k+segs))
    faces.extend([tuple(reversed(range(segs))),tuple(range(rings*segs,(rings+1)*segs))])
    return mesh(name,verts,faces,material,parent)


def attach_bone(obj, rig, bone):
    bpy.context.view_layer.update()
    mw=obj.matrix_world.copy()
    obj.parent=rig
    obj.parent_type='BONE'
    obj.parent_bone=bone
    obj.matrix_world=mw
    return obj


def limb(name, a, b, width, depth, material, parent=None):
    a,b=Vector(a),Vector(b)
    ob=box(name,(a+b)/2,(width,depth,(b-a).length),material,bevel=min(width,depth)*.16,parent=parent)
    ob.rotation_quaternion=(b-a).to_track_quat('Z','Y')
    ob.rotation_mode='QUATERNION'
    return ob


def rider(seat, parent=None):
    """A neutral block avatar seated astride the mount; not the user's identity."""
    s=Vector(seat)
    root=empty('PILOT | seated scale reference',s,parent)
    skin=mat('Pilot / warm skin',(.60,.34,.17,1),roughness=.5)
    jacket=mat('Pilot / graphite jacket',(.022,.035,.053,1),roughness=.47)
    pants=mat('Pilot / slate trousers',(.17,.23,.31,1),roughness=.6)
    boots=mat('Pilot / boots and gloves',(.009,.013,.022,1),roughness=.42)
    hair=mat('Pilot / charcoal hair',(.013,.009,.007,1),roughness=.48)
    gold=mat('Pilot / brass grips',(.75,.36,.07,1),metallic=.72,roughness=.3)
    white=mat('Pilot / jacket piping',(.65,.72,.74,1),roughness=.42)
    def p(x,y,z): return s+Vector((x,y,z))
    torso=box('Pilot / jacket torso',p(0,0,.54),(.64,.40,.65),jacket,.075,root)
    torso.rotation_euler.x=.10
    box('Pilot / collar',p(0,-.045,.87),(.41,.32,.1),boots,.025,root)
    box('Pilot / belt',p(0,0,.22),(.66,.42,.1),boots,.03,root)
    box('Pilot / belt buckle',p(0,-.222,.22),(.13,.035,.075),gold,.01,root)
    box('Pilot / zipper',p(0,-.231,.56),(.022,.012,.43),white,.006,root)
    head=box('Pilot / head',p(0,-.07,1.17),(.49,.45,.51),skin,.09,root)
    for x in (-.105,.105):
        eye=ellipsoid('Pilot / eye',p(x,-.3,1.2),(.022,.011,.047),boots,root)
    tube('Pilot / subtle smile',[p(-.065,-.307,1.095),p(0,-.315,1.071),p(.065,-.307,1.098)],.011,boots,root)
    box('Pilot / hair cap',p(0,-.043,1.43),(.53,.46,.15),hair,.06,root)
    for i in range(7):
        x=(i-3)*.073
        f=feather('Pilot / swept hair '+str(i),p(x,-.02,1.43),p(x+.10,-.32,1.57+(.04 if i%2 else 0)),.16,hair,root,.03)
    for side in (-1,1):
        shoulder=p(side*.40,-.01,.75)
        elbow=p(side*.47,-.34,.53)
        hand=p(side*.29,-.64,.57)
        limb('Pilot / upper sleeve',shoulder,elbow,.24,.27,jacket,root)
        limb('Pilot / lower sleeve',elbow,hand,.22,.24,jacket,root)
        box('Pilot / hand',hand,(.19,.2,.19),skin,.035,root)
        hip=p(side*.26,.02,.13)
        knee=p(side*.60,-.3,-.13)
        ankle=p(side*.66,-.22,-.64)
        limb('Pilot / thigh',hip,knee,.28,.31,pants,root)
        limb('Pilot / shin',knee,ankle,.27,.28,pants,root)
        box('Pilot / boot',p(side*.66,-.31,-.70),(.3,.46,.19),boots,.045,root)
        tube('Pilot / stirrup', [p(side*.71,-.05,-.55),p(side*.80,-.26,-.82),p(side*.57,-.45,-.82),p(side*.51,-.20,-.57)],.025,gold,root)
    tube('Pilot / handlebar',[p(-.39,-.64,.57),p(0,-.64,.57),p(.39,-.64,.57)],.04,gold,root)
    tube('Pilot / handlebar riser',[p(0,-.64,.57),p(0,-.65,.05)],.046,gold,root)
    return root
