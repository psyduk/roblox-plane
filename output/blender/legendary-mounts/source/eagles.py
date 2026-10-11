"""Original procedural legendary eagle mounts. Coordinates face toward -Y.

All meshes are authored here; no external assets. Wing pivots carry a 24 frame
loop and are organized for later armature/Roblox conversion.
"""
import bpy
import math
from mathutils import Vector


def _mat(name, color, metallic=0.0, roughness=.4, emission=0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color[:3], color[3] if len(color)>3 else 1)
    m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Metallic'].default_value=metallic
    p.inputs['Roughness'].default_value=roughness
    if emission:
        p.inputs['Emission Color'].default_value=m.diffuse_color
        p.inputs['Emission Strength'].default_value=emission
    return m


def _empty(name, loc=(0,0,0), parent=None):
    o=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(o)
    o.location=loc
    if parent: o.parent=parent
    return o


def _mesh(name, verts, faces, material, parent=None, bevel=0, smooth=True):
    m=bpy.data.meshes.new(name+'.Geometry')
    m.from_pydata(verts,[],faces); m.update()
    o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    if parent:o.parent=parent
    for p in m.polygons:p.use_smooth=smooth
    if bevel:
        b=o.modifiers.new('Fine manufactured edge' if not smooth else 'Soft feather edge','BEVEL')
        b.width=bevel;b.segments=2
        n=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL')
        n.keep_sharp=True
    return o


def _ell(name,loc,scale,material,parent=None,segments=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=16,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:p.use_smooth=True
    if parent:o.parent=parent
    return o


def _tube(name,points,radius,material,parent=None):
    c=bpy.data.curves.new(name+'.Path','CURVE');c.dimensions='3D';c.resolution_u=16
    c.bevel_depth=radius;c.bevel_resolution=3
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for b,p in zip(s.bezier_points,points):
        b.co=p;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    if parent:o.parent=parent
    return o


def _feather(name,start,end,width,material,parent=None,mechanical=False,camber=.07):
    """A closed biconvex feather with broad shoulder, ridged spine and pointed tip."""
    a,b=Vector(start),Vector(end);d=b-a
    v=Vector((-d.y,d.x,0)).normalized()
    if v.length<.01:v=Vector((1,0,0))
    up=Vector((0,0,1))
    stations=[(0,.26),(.12,.77),(.34,1),(.60,.95),(.82,.61),(.95,.25),(1,0.012)]
    if mechanical:stations=[(0,.24),(.13,.83),(.36,1),(.72,.86),(.89,.49),(1,.012)]
    vs=[]
    for t,w in stations:
        center=a+d*t+up*(math.sin(t*math.pi)*camber)
        thick=(.022 if mechanical else .026)*(1-.75*t)
        ridge=(.055 if mechanical else .052)*math.sin(math.pi*t)+.012
        for across,h in [(-1,0),(0,ridge),(1,0),(1,-thick),(0,-thick*1.7),(-1,-thick)]:
            vs.append(tuple(center+v*width*w*across+up*h))
    fs=[];n=len(stations)
    for j in range(n-1):
        for k in range(6):fs.append((j*6+k,j*6+(k+1)%6,(j+1)*6+(k+1)%6,(j+1)*6+k))
    fs += [tuple(reversed(range(6))),tuple((n-1)*6+k for k in range(6))]
    return _mesh(name,vs,fs,material,parent,.012 if mechanical else .008,not mechanical)


def _cuff(name,loc,radius,depth,material,parent,axis='X'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=loc)
    o=bpy.context.object;o.name=name
    if axis=='X':o.rotation_euler[1]=math.pi/2
    elif axis=='Y':o.rotation_euler[0]=math.pi/2
    o.data.materials.append(material)
    if parent:o.parent=parent
    b=o.modifiers.new('Machined bevel','BEVEL');b.width=.035;b.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o


def _beak(prefix,root,gold,dark,mech):
    rings=[(-1.91,.245,1.19,.88),(-2.10,.242,1.16,.82),(-2.27,.19,1.04,.71),(-2.38,.10,.85,.51),(-2.35,.039,.63,.405),(-2.28,.003,.435,.405)]
    vs=[]
    for y,w,top,bot in rings:
        for k in range(12):
            t=2*math.pi*k/12
            vs.append((w*math.cos(t),y,(top+bot)*.5+(top-bot)*.5*math.sin(t)))
    fs=[]
    for i in range(len(rings)-1):
        for k in range(12):fs.append((i*12+k,i*12+(k+1)%12,(i+1)*12+(k+1)%12,(i+1)*12+k))
    fs += [tuple(reversed(range(12))),tuple((len(rings)-1)*12+k for k in range(12))]
    _mesh(prefix+'.Hooked golden beak',vs,fs,gold,root,.012,not mech)
    for s in [-1,1]:
        _tube(prefix+'.Beak mouth seam',[(s*.237,-1.95,.882),(s*.217,-2.13,.802),(s*.12,-2.30,.64)],.012,dark,root)
        _ell(prefix+'.Nostril',(s*.225,-2.08,1.024),(.012,.045,.023),dark,root)


def build_eagle(mechanical=False):
    P='Ironwing' if mechanical else 'Stormcrown'
    root=_empty(P+'.Mount')
    body_group=_empty(P+'.Body plumage',parent=root)
    wing_group=_empty(P+'.Animated wings',parent=root)
    head_group=_empty(P+'.Head and expression',parent=root)
    tail_group=_empty(P+'.Tail fan',parent=root)
    feet_group=_empty(P+'.Feet and talons',parent=root)
    harness_group=_empty(P+'.Saddle and harness',parent=root)
    brown=_mat(P+'.Primary plumage',(.020,.034,.061,1) if mechanical else (.031,.014,.007,1),.75 if mechanical else .03,.31 if mechanical else .62)
    mid=_mat(P+'.Raised plumage',(.043,.075,.129,1) if mechanical else (.065,.029,.012,1),.7 if mechanical else .03,.3 if mechanical else .60)
    dark=_mat(P+'.Deep recess',(.009,.014,.028,1),.55 if mechanical else .05,.38)
    edge=_mat(P+'.Blue steel bevel',(.12,.20,.29,1) if mechanical else (.095,.042,.017,1),.8 if mechanical else .02,.34 if mechanical else .62)
    white=_mat(P+'.Ivory head',(.78,.88,1,1) if mechanical else (.9,.89,.78,1),.28 if mechanical else .03,.3 if mechanical else .5)
    white_shade=_mat(P+'.Ivory feather shade',(.40,.56,.71,1) if mechanical else (.67,.70,.65,1),.35 if mechanical else .02,.35 if mechanical else .48)
    gold=_mat(P+'.Warm gold',(.91,.46,.06,1),.8 if mechanical else .55,.26)
    goldlight=_mat(P+'.Gold edge', (1,.72,.19,1),.78,.25)
    leather=_mat(P+'.Saddle leather',(.033,.015,.012,1),.1,.38)
    glow=_mat(P+'.Amber reactor' if mechanical else P+'.Storm feather light',(1,.25,.012,1) if mechanical else (.015,.52,1,1),.2,.27,4 if mechanical else 3)
    iris=_mat(P+'.Amber iris',(1,.54,.06,1),.5,.22,1.6 if mechanical else .2)
    _ell(P+'.Torso',(0,.05,.12),(.76,1.23,.73),brown,body_group)
    _ell(P+'.Breast',(0,-.69,.14),(.66,.70,.78),mid,body_group)
    _ell(P+'.Rump',(0,1.00,.04),(.56,.66,.51),brown,body_group)
    # Breast and flank overlapping contour feathers.
    for s in [-1,1]:
        for row in range(4):
            for j in range(6):
                a=j/5; y=-.77+a*1.7;z=.48-row*.27
                x=s*(.50+.18*math.sin(a*math.pi)-.09*abs(row-1))
                start=(x,y,z)
                end=(x+s*.06,y+.56,z-.34)
                _feather(P+f'.Flank.{s}.{row}.{j}',start,end,.19,mid if (j+row)%3==0 else brown,body_group,mechanical,.055)
        for j in range(5):
            x=s*(.1+j*.106)
            _feather(P+f'.Chest shield.{s}.{j}',(x,-1.12,.45),(x+s*.14,-1.08,-.54),.18,mid,body_group,mechanical,.08)
    # Tail is a true broad white fan, seen past the rump.
    for j in range(11):
        x=(j-5)/5
        end=(x*1.02,2.90-.37*abs(x),-.19-.06*abs(x))
        start=(x*.28,1.03,.09)
        _feather(P+f'.Tail white rectrix {j:02}',start,end,.195,white if j%2==0 else white_shade,tail_group,mechanical,.035)
        if mechanical:
            st=tuple(Vector(start).lerp(Vector(end),.83))
            _feather(P+f'.Tail gold tip {j:02}',st,end,.095,gold,tail_group,True,.02)
    # Broad feathered wings, with a structural leading edge and readable tiering.
    wing_pivots=[]
    for s,side in [(-1,'L'),(1,'R')]:
        pivot=_empty(P+'.Wing.'+side,(s*.63,0,.33),wing_group);wing_pivots.append(pivot)
        def local(p):return(s*(p[0]-.63),p[1],p[2]-.33)
        def wf(name,a,b,width,ma,cam=.10):return _feather(P+'.'+side+'.'+name,local(a),local(b),width,ma,pivot,mechanical,cam)
        # A flattened sculpted wing web joins the feather fan into an organic wing.
        # It replaces the cylindrical leading edge of the initial blocking pass.
        outline=[(.56,-.18,.42),(1.12,-.46,.64),(2.11,-.71,.78),(2.83,-.59,.79),(3.44,-.19,.66),(3.45,.65,.43),(2.71,1.39,.12),(1.79,1.24,.00),(.73,.64,.18)]
        webverts=[local(v) for v in outline]+[local((1.91,.20,.59))]+[local((v[0],v[1],v[2]-.14)) for v in outline]+[local((1.91,.20,.31))]
        webfaces=[]
        for j in range(9):
            webfaces.extend([(j,(j+1)%9,9),(10+j,19,10+(j+1)%9),(j,10+j,10+(j+1)%9,(j+1)%9)])
        _mesh(P+'.'+side+'.Sculpted feather wing web',webverts,webfaces,brown,pivot,.025,True)
        # Long hand feathers spread outward in a fan.
        ends=[(5.30,-.12,1.18),(5.32,.44,1.00),(5.18,.98,.77),(4.91,1.48,.52),(4.57,1.92,.28),(4.17,2.24,.08),(3.73,2.43,-.06),(3.28,2.46,-.13)]
        for j,e in reversed(list(enumerate(ends))):
            a=(2.70-j*.028,-.19+j*.075,.59-j*.023)
            wf(f'Primary flight feather {j:02}',a,e,.255+j*.007,brown,.19)
            # Subtle raised midrib emphasizes real layered volume.
            ep=Vector(a).lerp(Vector(e),.90);sp=Vector(a).lerp(Vector(e),.28)
            sp.z+=.075;ep.z+=.06
            _tube(P+'.'+side+f'.Primary spine {j:02}',[local(sp),local(tuple((sp+ep)*.5+Vector((0,0,.04)))),local(ep)],.009,edge,pivot)
            if mechanical:
                st=Vector(a).lerp(Vector(e),.80);st.z+=.015
                wf(f'Gold primary cap {j:02}',tuple(st),tuple(Vector(e)+Vector((0,0,.016))),.142,gold,.01)
                sp=Vector(a).lerp(Vector(e),.38);ep=Vector(a).lerp(Vector(e),.63)
                sp.z+=.068;ep.z+=.067
                _tube(P+'.'+side+f'.Reactor channel {j:02}',[local(sp),local(ep)],.022,glow,pivot)
            else:
                # A restrained charged blue edge only on outermost 25 percent.
                st=Vector(a).lerp(Vector(e),.82);st.z+=.022
                ep=Vector(e);ep.z+=.018
                _tube(P+'.'+side+f'.Charged primary tip {j:02}',[local(st),local(ep)],.016,glow,pivot)
        for j in range(11):
            t=j/10
            a=(.75+2.11*t,-.13-.12*t,.45+.20*t)
            e=(1.02+2.15*t,1.97+.38*t,-.29+.20*t)
            wf(f'Secondary flight feather {j:02}',a,e,.22,mid if j%3==0 else brown,.17)
            if mechanical:
                st=Vector(a).lerp(Vector(e),.88);st.z+=.012
                wf(f'Secondary gilded blade {j:02}',tuple(st),tuple(Vector(e)+Vector((0,0,.012))),.10,gold,.01)
        for row in range(3):
            for j in range(13):
                t=j/12;x=.64+2.77*t;y=-.30-.43*math.sin(t*math.pi)+row*.33
                z=.68+.17*math.sin(t*math.pi)-row*.05
                a=(x,y,z);e=(x+.40+row*.03,y+1.04+row*.06,z-.16)
                wf(f'Covert tier {row}.{j:02}',a,e,.174 if row<2 else .195,brown if (j+row)%3 else mid,.075)
        # Scapular mantle hides the root seam and follows the arm's swept curve.
        for j in range(8):
            t=j/7
            a=(.61+.075*j,-.40+.075*j,.65+.025*j)
            e=(1.54+.14*j,-.14+.14*j,.57-.021*j)
            wf(f'Shoulder mantle {j:02}',a,e,.235,mid if j%3==0 else brown,.14)
        for j in range(11):
            t=j/10;x=.80+2.24*t;y=-.37-.36*math.sin(t*math.pi)
            wf(f'Leading edge pointed feather {j:02}',(x,y,.74+.12*math.sin(t*math.pi)),(x+.46,y+.21,.73+.10*math.sin(t*math.pi)),.14,brown,.04)
        if mechanical:
            for k,x in enumerate([.91,2.88]):
                p=local((x,-.18,.76))
                _cuff(P+'.'+side+f'.Articulated joint {k}',p,.30 if k else .24,.20,dark,pivot,'Y')
                _cuff(P+'.'+side+f'.Gold joint bezel {k}',(p[0],p[1]-.115,p[2]),.236 if k else .18,.035,gold,pivot,'Y')
                _cuff(P+'.'+side+f'.Amber bearing {k}',(p[0],p[1]-.139,p[2]),.11,.039,glow,pivot,'Y')
            wf('Gold leading armor',(1.04,-.37,.64),(2.26,-.47,.77),.16,gold,.03)
            wf('Gold wrist armor',(2.73,-.44,.79),(3.53,-.32,.78),.18,gold,.03)
        else:
            p=local((.96,-.02,.43));_cuff(P+'.'+side+'.Shoulder harness cuff',p,.285,.13,gold,pivot)
        for frame,angle in[(1,24),(7,5),(13,-17),(19,5),(25,24)]:
            pivot.rotation_euler=(0,-s*math.radians(angle),0)
            pivot.keyframe_insert('rotation_euler',frame=frame)
        if pivot.animation_data and pivot.animation_data.action:
            action=pivot.animation_data.action
            # Legacy and layered action APIs vary; keyframes remain valid regardless.
            try:
                for fc in action.fcurves:fc.modifiers.new('CYCLES')
            except AttributeError:pass
    # Proud bald-eagle head with pointed ruff layered downward and back.
    _ell(P+'.Upright neck',(0,-1.05,.62),(.48,.50,.77),white_shade,head_group)
    _ell(P+'.Cranium',(0,-1.56,1.03),(.48,.59,.43),white,head_group)
    for s in [-1,1]:
        for row in range(3):
            for j in range(5):
                t=j/4
                a=(s*(.30+.105*math.sin(t*math.pi)),-1.67+.70*t,1.15-row*.245)
                e=(s*(.43+.15*t),-1.38+.87*t,.80-row*.30)
                _feather(P+f'.Ruff.{s}.{row}.{j}',a,e,.14,white if (j+row)%3 else white_shade,head_group,mechanical,.05)
        for j in range(3):
            _feather(P+f'.Forehead crown.{s}.{j}',(s*.09,-1.94+j*.18,1.40),(s*(.34+j*.025),-1.00+j*.15,1.22),.112,white,head_group,mechanical,.032)
        # Two eye sockets, bright irises and focused downward-sloping brows.
        _ell(P+'.'+str(s)+'.Eye socket',(s*.438,-1.77,1.17),(.055,.202,.140),dark,head_group)
        _ell(P+'.'+str(s)+'.Amber iris',(s*.484,-1.835,1.18),(.034,.088,.097),iris,head_group)
        _ell(P+'.'+str(s)+'.Pupil',(s*.514,-1.858,1.18),(.012,.032,.064),dark,head_group)
        _ell(P+'.'+str(s)+'.Eye glint',(s*.526,-1.879,1.22),(.010,.017,.017),white,head_group,16)
        _feather(P+'.'+str(s)+'.Stern eyebrow',(s*.46,-1.985,1.255),(s*.47,-1.46,1.37),.098,white,head_group,mechanical,.025)
    for j in range(5):
        x=(j-2)*.11
        _feather(P+f'.White throat spear {j}',(x,-1.43,.97),(x*1.27,-1.32,.05-.10*(1-abs(j-2)/2)),.16,white,head_group,mechanical,.12)
    _beak(P,head_group,gold,dark,mechanical)
    # Visible paired legs; each has three forward gripping toes and a rear toe.
    for s,side in [(-1,'L'),(1,'R')]:
        x=s*.42
        _ell(P+'.'+side+'.Feathered thigh',(x,.13,-.43),(.28,.40,.38),brown,feet_group)
        _tube(P+'.'+side+'.Scaled ankle',[(x,.04,-.60),(x,-.07,-.89),(x,-.22,-1.02)],.10,gold,feet_group)
        for k in range(4):
            _cuff(P+'.'+side+f'.Ankle scale {k}',(x,-.065-k*.035,-.74-k*.075),.116,.037,goldlight if k%2 else gold,feet_group,'Z')
        for toe in range(3):
            xx=x+(toe-1)*.135
            ps=[(x,-.20,-1.00),(xx,-.43,-1.09),(xx,-.68,-1.11),(xx,-.81,-1.02)]
            _tube(P+'.'+side+f'.Toe {toe}',ps,.066,gold,feet_group)
            # A tapered three-dimensional hooked dark claw.
            claw=[(xx,-.78,-1.05),(xx,-.91,-1.00),(xx,-.94,-.84),(xx,-.87,-.77)]
            vs=[]
            for k,pt in enumerate(claw):
                r=[.071,.058,.034,.003][k]
                for m in range(8):
                    t=m*math.pi/4;vs.append((pt[0]+r*math.cos(t),pt[1],pt[2]+r*math.sin(t)))
            fs=[]
            for k in range(3):
                for m in range(8):fs.append((k*8+m,k*8+(m+1)%8,(k+1)*8+(m+1)%8,(k+1)*8+m))
            _mesh(P+'.'+side+f'.Curved talon {toe}',vs,fs,dark,feet_group,0,True)
        _tube(P+'.'+side+'.Rear gripping toe',[(x,-.05,-1.00),(x,.18,-1.14),(x,.36,-1.07)],.066,gold,feet_group)
        _tube(P+'.'+side+'.Rear claw',[(x,.33,-1.08),(x,.45,-1.01),(x,.43,-.87)],.045,dark,feet_group)
        if mechanical:
            _cuff(P+'.'+side+'.Hip servo',(x+s*.15,.1,-.37),.17,.10,gold,feet_group)
            _cuff(P+'.'+side+'.Hip servo recess',(x+s*.21,.1,-.37),.10,.02,dark,feet_group)
    # Premium riding saddle, breast straps and glowing diamond insignia.
    _ell(P+'.Saddle pad',(0,.14,.83),(.47,.62,.105),gold,harness_group)
    _ell(P+'.Leather seat',(0,.13,.93),(.395,.51,.10),leather,harness_group)
    _ell(P+'.Raised seat cantle',(0,.53,1.02),(.42,.13,.20),leather,harness_group)
    for s in [-1,1]:
        _tube(P+f'.Chest harness {s}',[(s*.62,.17,.62),(s*.70,-.50,.26),(s*.42,-1.13,-.10),(0,-1.27,-.18)],.067,gold if mechanical else leather,harness_group)
        _tube(P+f'.Harness gold piping {s}',[(s*.64,.17,.64),(s*.72,-.50,.28),(s*.43,-1.16,-.085),(0,-1.30,-.17)],.017,goldlight,harness_group)
        _tube(P+f'.Saddle handle {s}',[(s*.27,-.28,1.01),(s*.27,-.36,1.28),(s*.13,-.42,1.32)],.041,gold,harness_group)
    _mesh(P+'.Breast heraldic diamond',[(0,-1.34,.065),(.20,-1.34,-.13),(0,-1.35,-.38),(-.20,-1.34,-.13),(0,-1.40,-.13)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],gold,harness_group,.02,False)
    _mesh(P+'.Breast inset jewel',[(0,-1.419,-.02),(.09,-1.419,-.13),(0,-1.43,-.27),(-.09,-1.419,-.13),(0,-1.46,-.13)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],glow,harness_group,0,False)
    root['asset_type']='Legendary cosmetic flying mount'
    root['animation']='Wing flap: frames 1-25, seamless endpoints'
    root['forward']='-Y'
    root['concept']='Ironwing Eagle' if mechanical else 'Stormcrown Eagle'
    bpy.context.scene.frame_set(1)
    return {'root':root,'rig':None,'wing_pivots':wing_pivots,'seat':(0,-.08,1.01)}
