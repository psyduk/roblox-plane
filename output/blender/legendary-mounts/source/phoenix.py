"""Eclipse Phoenix: an original layered-feather legendary mount study.

All visible forms are editable Blender mesh/curve objects. The two shoulder
pivots and three tail pivots carry an additive, cyclic flight study.
"""
import bpy
import math
from mathutils import Vector
import common as _common
from common import mat


def _local_object(function, *args, **kwargs):
    """Phoenix geometry is specified in the local space of its animated pivot."""
    parent = kwargs.pop('parent', None)
    ob = function(*args, **kwargs)
    ob.parent = parent
    return ob


def mesh(*args, **kwargs):
    return _local_object(_common.mesh, *args, **kwargs)


def ellipsoid(*args, **kwargs):
    return _local_object(_common.ellipsoid, *args, **kwargs)


def box(*args, **kwargs):
    return _local_object(_common.box, *args, **kwargs)


def tube(*args, **kwargs):
    return _local_object(_common.tube, *args, **kwargs)


def empty(*args, **kwargs):
    return _local_object(_common.empty, *args, **kwargs)


def _v(value):
    return Vector(value)


def _blade(name, points, width, materials, parent, glow=True, ridge=True):
    """Solid feather loft with a keel, rounded facets and individually colored tips."""
    points = [_v(p) for p in points]
    count = 24
    cross = [-1, -.65, 0, .65, 1]
    verts, faces, face_materials = [], [], []

    def center(t):
        if len(points) == 4:
            return ((1-t)**3*points[0] + 3*(1-t)**2*t*points[1]
                    + 3*(1-t)*t*t*points[2] + t**3*points[3])
        return points[0].lerp(points[-1], t)

    for j in range(count + 1):
        t = j/count
        c = center(t)
        tangent = center(min(1, t+.003))-center(max(0, t-.003))
        tangent.normalize()
        side = Vector((-tangent.y, tangent.x, 0))
        if side.length < .01:
            side = Vector((1,0,0))
        side.normalize()
        normal = tangent.cross(side).normalized()
        # A round shoulder and a long taper read as feathers, not a diamond fan.
        breadth = width * (.09 + .91*math.sin(math.pi*t**.64)**.67) * (1-.40*t)
        if j == count:
            breadth = .002
        for surface in [1, -1]:
            for r in cross:
                # A physical central shaft ridge is part of the solid geometry.
                depth = width*(.018 + .065*(1-abs(r))) * math.sin(math.pi*t)**.65
                p = c + side*(r*breadth) + normal*(surface*depth)
                verts.append(tuple(p))
    for j in range(count):
        t = (j+.5)/count
        mi = 0
        if len(materials)>1:
            mi = 1 if t>.31 else 0
        if glow and len(materials)>2:
            mi = 2 if t>.46 else mi
            mi = 3 if t>.57 else mi
            mi = 4 if t>.67 else mi
            mi = 5 if t>.94 else mi
        for k in range(4):
            faces.append((j*10+k, (j+1)*10+k, (j+1)*10+k+1, j*10+k+1))
            face_materials.append(min(mi,len(materials)-1))
            faces.append((j*10+5+k+1,(j+1)*10+5+k+1,(j+1)*10+5+k,j*10+5+k))
            face_materials.append(min(mi,len(materials)-1))
        faces.append((j*10,j*10+5,(j+1)*10+5,(j+1)*10))
        face_materials.append(min(mi,len(materials)-1))
        faces.append((j*10+4,(j+1)*10+4,(j+1)*10+9,j*10+9))
        face_materials.append(min(mi,len(materials)-1))
    faces += [tuple(range(9,-1,-1)), tuple(count*10+i for i in range(10))]
    face_materials += [0,min(len(materials)-1,4) if glow else 0]
    ob = mesh(name, verts, faces, materials[0], parent=parent)
    for material in materials[1:]:
        ob.data.materials.append(material)
    for poly, index in zip(ob.data.polygons, face_materials):
        poly.material_index = index
        poly.use_smooth = True
    if ridge and width>.12:
        pts=[]
        for j in range(10):
            t = .06 + .075*j
            c = center(t)
            c.z += width*.085*math.sin(math.pi*t)**.65
            pts.append(tuple(c))
        tube(name+'_quill',pts,.006,materials[0],parent=parent)
    return ob


def _animation(pivot, side, amplitude=.24, phase=0, tail=False):
    pivot.rotation_mode='XYZ'
    for frame, factor in [(1,1),(7,0),(13,-1),(19,0),(25,1)]:
        if tail:
            pivot.rotation_euler = (factor*.07, factor*.035*side, factor*.07*side)
        else:
            pivot.rotation_euler = (factor*.025, -side*factor*amplitude, side*factor*.035)
        pivot.keyframe_insert(data_path='rotation_euler',frame=frame+phase)
    action = pivot.animation_data.action
    action.name = pivot.name+'_Flight_Loop'
    # Blender 4.4+ stores fcurves in action-channelbags rather than action.fcurves.
    fcurves=[]
    if hasattr(action,'fcurves'):
        fcurves=list(action.fcurves)
    else:
        for layer in action.layers:
            for strip in layer.strips:
                if hasattr(strip,'channelbags'):
                    for bag in strip.channelbags:
                        fcurves.extend(list(bag.fcurves))
    for fc in fcurves:
        fc.modifiers.new('CYCLES')
        for key in fc.keyframe_points:
            key.interpolation='BEZIER'


def build_phoenix():
    root=empty('ECLIPSE_PHOENIX')
    root['design']='Eclipse Phoenix / original legendary vehicle cosmetic'
    root['animation']='Shoulder and split-tail flight loop, frames 1–25'
    root['rider_seat']='Dorsal saddle at (0, -0.1, 1.0)'
    obsidian=mat('Phoenix · midnight obsidian',(0.009,.004,.022,1),metallic=.4,roughness=.38)
    plum=mat('Phoenix · amethyst vane',(.035,.008,.065,1),metallic=.3,roughness=.4)
    violet=mat('Phoenix · royal violet',(.105,.012,.17,1),metallic=.28,roughness=.4)
    magenta=mat('Phoenix · molten transition',(.42,.008,.065,1),metallic=.18,roughness=.38,emission=.12)
    ember=mat('Phoenix · ember gold',(1,.09,.003,1),metallic=.16,roughness=.35,emission=.65)
    goldlight=mat('Phoenix · warm luminous edge',(1,.40,.012,1),metallic=.15,roughness=.3,emission=.8)
    gold=mat('Phoenix · brushed ancient gold',(.73,.37,.075,1),metallic=.77,roughness=.26)
    darkgold=mat('Phoenix · bronze harness',(.28,.105,.027,1),metallic=.73,roughness=.34)
    black=mat('Phoenix · eye ink',(.005,.003,.009,1),roughness=.23)
    amber=mat('Phoenix · living amber',(1,.31,.015,1),metallic=.08,roughness=.18,emission=3.2)
    leather=mat('Phoenix · saddle leather',(.065,.026,.053,1),metallic=.12,roughness=.51)
    palette=[obsidian,plum,violet,magenta,ember,goldlight]
    body=ellipsoid('Phoenix • powerful breast',(0,.12,.13),(.69,1.28,.63),obsidian,parent=root)
    ellipsoid('Phoenix • shoulders',(0,-.57,.38),(.57,.78,.59),plum,parent=root)
    neck=ellipsoid('Phoenix • rising neck',(0,-1.27,.89),(.36,.69,.69),obsidian,parent=root)
    neck.rotation_euler.x=math.radians(-24)
    ellipsoid('Phoenix • proud head',(0,-1.63,1.05),(.38,.53,.35),obsidian,parent=root)

    # Dense overlapping coverts describe breast, back and flanks with real volume.
    for row in range(6):
        y=-.68+row*.29
        for j in range(10):
            a=(j/9)*math.pi*1.64-math.pi*.32
            x=.63*math.sin(a)
            z=.17+.55*math.cos(a)
            length=.42+.09*(row/5)
            p0=(x,y,z)
            p1=(x*1.03,y+.14,z+.035)
            p2=(x*1.01,y+length*.8,z-.055)
            p3=(x*.91,y+length,z-.13)
            _blade(f'Phoenix • body covert {row:02d}-{j:02d}',[p0,p1,p2,p3],.14,
                   [obsidian,plum if (row+j)%3 else violet],root,glow=False,ridge=False)

    # Neck ruff: swept charcoal feathers reveal the warm inner throat.
    for side in [-1,1]:
        for row in range(4):
            for col in range(3):
                start=(side*(.17+col*.095),-1.81+row*.22,1.67-row*.17)
                end=(side*(.42+col*.08),-1.19+row*.20,1.20-row*.18)
                _blade(f'Phoenix • neck ruff {side} {row} {col}',
                       [start,(start[0]*1.3,start[1]+.15,start[2]+.06),
                        (end[0],end[1]-.1,end[2]+.07),end],.13,
                       [obsidian,plum,violet,magenta,ember,goldlight],root,
                       glow=(col==0 and row%2==0),ridge=False)
        # Small angular cheek plume pulls away from the eye.
        for j in range(3):
            _blade(f'Phoenix • cheek plume {side} {j}',
                   [(side*.32,-1.75,1.02-j*.065),(side*.44,-1.51,1.02-j*.035),
                    (side*.44,-1.21,.98-j*.06),(side*.54,-1.05,.97-j*.07)],
                   .105,[obsidian,plum,violet],root,glow=False,ridge=False)

    # Solid swept wings. A subtle shoulder bridge ties the feather fan together.
    for side,label in [(-1,'L'),(1,'R')]:
        wing=empty(f'Phoenix • {label} shoulder flap',loc=(side*.49,-.06,.37),parent=root)
        ellipsoid(f'Phoenix • {label} wing root',(side*.65,.03,.10),(1.01,.48,.22),obsidian,parent=wing)
        verts=[(0,-.37,0),(side*1.5,-.57,.23),(side*3.06,-.66,.64),
               (side*2.74,.38,.43),(side*1.03,.89,-.03),(0,.50,-.15)]
        wingplane=mesh(f'Phoenix • {label} upperwing core',verts,[(0,1,2,3,4,5)],obsidian,parent=wing)
        solid=wingplane.modifiers.new('Solid wing core','SOLIDIFY');solid.thickness=.11
        # Primary remiges: broad, offset and individually articulated in silhouette.
        for i in range(12):
            t=i/11
            start=(side*(.82+1.77*t),.43-.83*t,.055+.43*t)
            end=(side*(2.47+1.82*t),2.16-2.86*t,.10+1.06*t)
            points=[start,(side*(abs(start[0])+.69),start[1]+.16,start[2]+.12),
                    (side*(abs(end[0])-.44),end[1]+.10,end[2]-.09),end]
            _blade(f'Phoenix • {label} primary {i+1:02d}',points,.29+.035*math.sin(t*math.pi),palette,wing)
        # Secondary flight feathers fan closer to the body, hiding no joints.
        for i in range(9):
            t=i/8
            start=(side*(.15+1.91*t),-.16+.14*t,.115+.20*t)
            end=(side*(.48+2.20*t),1.75-.90*t,-.16+.47*t)
            _blade(f'Phoenix • {label} secondary {i+1:02d}',
                   [start,(side*(abs(start[0])+.35),start[1]+.29,start[2]+.10),
                    (end[0],end[1]-.35,end[2]+.1),end],.245,palette,wing)
        # Three rows of short amethyst coverts form a scale-like wing mantle.
        for row in range(3):
            for i in range(12):
                t=i/11
                start=(side*(.25+2.69*t),-.43+row*.205,.20+.44*t+row*.018)
                end=(side*(.57+2.72*t),.15+row*.225,.19+.49*t)
                _blade(f'Phoenix • {label} mantle {row}-{i}',
                       [start,(side*(abs(start[0])+.14),start[1]+.16,start[2]+.04),
                        (end[0],end[1]-.12,end[2]+.045),end],.155,
                       [obsidian,plum if (i+row)%3 else violet],wing,glow=False,ridge=False)
        # The leading silhouette has luxurious backward swept points.
        for i in range(6):
            t=i/5
            a=(side*(.7+2.5*t),-.53,.25+.48*t)
            b=(side*(1.35+2.45*t),-.78-.10*t,.45+.61*t)
            _blade(f'Phoenix • {label} leading crown {i}',
                   [a,(side*(abs(a[0])+.25),a[1]-.06,a[2]+.12),
                    (side*(abs(b[0])-.10),b[1]+.02,b[2]-.01),b],.17,
                   palette,wing,glow=i>3,ridge=False)
        _animation(wing,side,amplitude=.50)

    # Three flame streamers: curved lofts, luminous tips, gentle independent sway.
    for i,(x,offset,lateral) in enumerate([(-.3,.05,-1),(0,.55,.12),(.3,.20,1)]):
        tail=empty(f'Phoenix • tail streamer {i+1}',loc=(x,1.04,-.02),parent=root)
        points=[(0,0,0),(-lateral*.60,1.05,-1.08),
                (lateral*1.86,2.9+offset,-.65),(lateral*2.1,3.76+offset,.48)]
        _blade(f'Phoenix • long flame streamer {i+1}',points,.22,palette,tail)
        _animation(tail,lateral or 1,tail=True)
    for side in [-1,1]:
        for j in range(3):
            _blade(f'Phoenix • tail cover {side}-{j}',
                   [(side*.18,1.05,.31),(side*(.45+j*.1),1.5,.2),
                    (side*(.7+j*.12),1.86+j*.1,.0),(side*(.72+j*.16),2.08+j*.21,-.07)],
                   .17,palette,root,glow=j==2)

    # Hooked gold beak, crafted from two curved solid lofts rather than a cone.
    beakverts=[(-.245,-1.91,1.17),(.245,-1.91,1.17),(-.23,-2.14,1.04),(.23,-2.14,1.04),
               (-.13,-2.35,.87),(.13,-2.35,.87),(0,-2.39,.67),
               (-.16,-1.99,.89),(.16,-1.99,.89),(0,-2.25,.80),(0,-2.18,1.19)]
    beakfaces=[(0,1,10),(1,3,10),(3,5,10),(5,6,4,10),(4,2,10),(2,0,10),
               (0,2,7),(1,8,3),(2,4,9,7),(3,8,9,5),(4,6,9),(5,9,6),(7,9,8),(0,7,8,1)]
    beak=mesh('Phoenix • golden hooked upper beak',beakverts,beakfaces,gold,parent=root)
    bev=beak.modifiers.new('Soft crafted beak edges','BEVEL');bev.width=.026;bev.segments=2
    for side in [-1,1]:
        ellipsoid(f'Phoenix • nostril {side}',(side*.213,-2.105,1.05),(.016,.052,.026),darkgold,parent=root)
        ellipsoid(f'Phoenix • eye socket {side}',(side*.344,-1.792,1.17),(.043,.161,.103),black,parent=root)
        ellipsoid(f'Phoenix • amber eye {side}',(side*.382,-1.815,1.178),(.031,.109,.060),amber,parent=root)
        ellipsoid(f'Phoenix • slit pupil {side}',(side*.409,-1.835,1.181),(.007,.028,.049),black,parent=root)
        ellipsoid(f'Phoenix • eye highlight {side}',(side*.415,-1.86,1.198),(.004,.015,.014),goldlight,parent=root)
        _blade(f'Phoenix • commanding brow {side}',
               [(side*.315,-1.981,1.222),(side*.395,-1.82,1.281),
                (side*.39,-1.51,1.285),(side*.41,-1.405,1.245)],
               .09,[gold,darkgold],root,glow=False,ridge=False)
    # Crown of three tall flame feathers, deliberately clear above the head.
    for i,(x,height) in enumerate([(-.17,.64),(0,.92),(.17,.68)]):
        _blade(f'Phoenix • three flame crown {i+1}',
               [(x,-1.54,1.30),(x*1.50,-1.03,1.56),
                (x*2.40,-.95,1.3+height),(x*2.6,-1.36,1.46+height)],
               .145,palette,root)

    # Ornamental breast flame. It remains below the rider's seat.
    for side in [-1,1]:
        _blade(f'Phoenix • golden chest sigil {side}',
               [(side*.34,-1.285,.58),(side*.48,-1.25,.21),
                (side*.15,-1.28,-.15),(0,-1.16,-.47)],.075,[gold,darkgold],root,glow=False,ridge=False)
    ellipsoid('Phoenix • chest jewel',(0,-1.277,.24),(.11,.058,.18),ember,parent=root)
    # Saddle and gold piping communicate that this is a rideable vehicle.
    box('Phoenix • saddle pad',(0,-.04,.768),(.89,.87,.13),darkgold,bevel=.13,parent=root)
    box('Phoenix • rider saddle',(0,-.04,.86),(.70,.75,.13),leather,bevel=.14,parent=root)
    tube('Phoenix • saddle front piping',[(-.36,-.36,.9),(0,-.40,.97),(.36,-.36,.9)],.026,gold,parent=root)
    for side in [-1,1]:
        tube(f'Phoenix • harness strap {side}',[(side*.37,-.39,.77),(side*.68,-.36,.30),
                                               (side*.52,-.28,-.31)],.045,leather,parent=root)
        # Shield-like saddle ornament, on the flank.
        verts=[(side*.702,-.19,.55),(side*.704,-.43,.29),(side*.704,-.20,-.01),
               (side*.704,.04,.29),(side*.762,-.20,.29)]
        mesh(f'Phoenix • saddle heraldic shield {side}',verts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],gold,parent=root)
    # Strong legs, dark scales, three forward talons and one rear claw each.
    for side in [-1,1]:
        x=side*.39
        tube(f'Phoenix • leg {side}',[(x,.43,-.25),(x,.41,-.64),(x,.22,-.92)],.114,obsidian,parent=root)
        for j in range(5):
            box(f'Phoenix • shin scale {side}-{j}',(x,.298-j*.019,-.55-j*.07),(.194,.10,.055),darkgold,
                bevel=.018,parent=root)
        for toe in range(3):
            dx=(toe-1)*.125
            start=(x+dx*.45,.23,-.87)
            mid=(x+dx,-.03,-1.025)
            tip=(x+dx*1.20,-.24,-1.035)
            tube(f'Phoenix • talon toe {side}-{toe}',[start,mid,tip],.047,obsidian,parent=root)
            tube(f'Phoenix • gold claw {side}-{toe}',[tip,(tip[0],-.39,-.99),(tip[0],-.46,-.85)],.029,gold,parent=root)
        tube(f'Phoenix • hind claw {side}',[(x,.29,-.89),(x,.57,-1.0),(x,.70,-.96),(x,.74,-.86)],.04,gold,parent=root)

    # Lift the facial assembly into a proud long-necked posture without moving
    # the saddle or pilot contract. Ruff and neck geometry above bridge the gap.
    face_parts=('proud head','cheek plume','golden hooked upper beak','nostril',
                'eye socket','amber eye','slit pupil','eye highlight',
                'commanding brow','three flame crown')
    for ob in list(root.children):
        if any(part in ob.name for part in face_parts):
            ob.location.y -= .27
            ob.location.z += .48

    return {'root':root,'rig':None,'seat':(0,-.1,1.0)}
