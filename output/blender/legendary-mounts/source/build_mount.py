"""Build one native Blender mount study and render its inspection views.

Usage: Blender --background --factory-startup --python build_mount.py -- eagle
"""
import bpy
import sys
import math
import json
from pathlib import Path
from mathutils import Vector

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from common import *

OUT=HERE.parent
KEYS={
 'eagle':('01-stormcrown-eagle','STORMCROWN EAGLE','ORGANIC / STORM',(.025,.55,1.0,1)),
 'ironwing':('02-ironwing-eagle','IRONWING EAGLE','MECHANICAL / AMBER',(.95,.29,.025,1)),
 'phoenix':('03-eclipse-phoenix','ECLIPSE PHOENIX','OBSIDIAN / EMBER',(.95,.085,.20,1)),
 'manta':('04-rift-manta','RIFT MANTA','COSMIC / TIDAL',(.055,.85,.67,1)),
}


def aim(ob,target):
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()


def area(name,loc,power,color,size,target=(0,0,0)):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.color=color
    data.shape='DISK'
    data.size=size
    ob=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(ob)
    ob.location=loc
    aim(ob,target)
    return ob


def setup_stage(title,subtitle,accent):
    sc=bpy.context.scene
    sc.render.engine='BLENDER_EEVEE'
    sc.render.resolution_x=1600
    sc.render.resolution_y=1200
    sc.render.resolution_percentage=100
    sc.render.image_settings.file_format='PNG'
    sc.render.film_transparent=False
    sc.render.fps=24
    sc.frame_start=1
    sc.frame_end=25
    # Read the available property before using it across Blender versions.
    if hasattr(sc,'eevee') and hasattr(sc.eevee,'taa_render_samples'):
        sc.eevee.taa_render_samples=64
    sc.world=bpy.data.worlds.new('Studio / blue ambient')
    sc.world.use_nodes=True
    bg=next(n for n in sc.world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.038,.055,.095,1)
    bg.inputs['Strength'].default_value=.5
    sc.view_settings.exposure=.05
    floor=mat('Stage / midnight blue',(.012,.022,.041,1),metallic=.28,roughness=.5)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-2.55))
    bpy.context.object.name='STUDIO / seamless floor'
    bpy.context.object.data.materials.append(floor)
    podium=mat('Stage / graphite plinth',(.021,.035,.059,1),metallic=.62,roughness=.32)
    bpy.ops.mesh.primitive_cylinder_add(vertices=128,radius=4.9,depth=.14,location=(0,.25,-2.44))
    ob=bpy.context.object
    ob.name='STUDIO / hovering display plinth'
    ob.data.materials.append(podium)
    be=ob.modifiers.new('Plinth bevel','BEVEL'); be.width=.12; be.segments=3
    ob.modifiers.new('Plinth normals','WEIGHTED_NORMAL')
    led=mat('Stage / accent light',accent,metallic=.3,roughness=.3,emission=.85)
    # Thin broken concentric rings leave the model silhouette dominant.
    for a,b in [(-.25,1.25),(1.45,2.7),(3.0,4.45),(4.7,5.85)]:
        pts=[(4.78*math.cos(a+(b-a)*i/30),.25+4.78*math.sin(a+(b-a)*i/30),-2.34) for i in range(31)]
        tube('STUDIO / luminous rim',pts,.018,led)
    area('KEY / large warm softbox',(1,-8,10),1700,(1.0,.86,.70),7)
    area('FILL / broad cool softbox',(-8,-3,5),850,(.51,.7,1.0),8)
    area('RIM / sky edge',(3,6,7),2100,(.3,.62,1.0),6)
    area('FACE / white frontal',(-1,-10,3),450,(1,.97,.89),5)
    cam_data=bpy.data.cameras.new('CAMERA / hero')
    cam=bpy.data.objects.new('CAMERA / hero',cam_data)
    sc.collection.objects.link(cam)
    cam.location=(6,-17,10)
    aim(cam,(0,.25,.4))
    cam_data.type='ORTHO'
    cam_data.ortho_scale=13.8
    cam_data.lens=52
    sc.camera=cam
    # These captions are real Blender text objects parented to the camera.
    labelmat=mat('Stage / typography',(.72,.83,.98,1),emission=.65)
    accentmat=mat('Stage / caption accent',accent,emission=.85)
    def caption(name,body,x,y,size,material):
        data=bpy.data.curves.new(name,'FONT')
        data.body=body
        data.size=size
        data.space_character=1.16
        data.align_x='LEFT'
        data.extrude=0
        ob=bpy.data.objects.new(name,data)
        sc.collection.objects.link(ob)
        data.materials.append(material)
        ob.parent=cam
        ob.location=(x,y,-10)
        ob.rotation_euler=(0,0,0)
        return ob
    caption('LABEL / name',title,-6.2,4.4,.37,labelmat)
    caption('LABEL / category','LEGENDARY MOUNT  /  '+subtitle,-6.2,4.02,.135,accentmat)
    caption('LABEL / footer','SKY BATTLE   /   BLENDER MODEL STUDY   /   SEATED PILOT',-6.2,-4.65,.12,labelmat)
    return cam


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['eagle']
    kind=args[0]
    slug,title,subtitle,accent=KEYS[kind]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    asset_coll=bpy.data.collections.new(title+' / MODEL')
    bpy.context.scene.collection.children.link(asset_coll)
    layer=bpy.context.view_layer.layer_collection.children[asset_coll.name]
    bpy.context.view_layer.active_layer_collection=layer
    if kind in ('eagle','ironwing'):
        from eagles import build_eagle
        result=build_eagle(mechanical=kind=='ironwing')
    elif kind=='phoenix':
        from phoenix import build_phoenix
        result=build_phoenix()
    else:
        # Blender ships a builtin fluid module named manta: load our file by path.
        import importlib.util
        spec=importlib.util.spec_from_file_location('rift_manta_model',HERE/'manta.py')
        mod=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        result=mod.build_manta()
    rider(result['seat'],result['root'])
    root=result['root']
    root['asset_kind']='Cosmetic flying mount / Blender design study'
    root['concept_reference']=str(Path('output/imagegen/legendary-mount-concepts-2026-10-10')/(slug+'.png'))
    root['integration_status']='Not imported into Roblox; scale, collision and export rig require integration pass.'
    root['rider']='Generic placeholder avatar for scale; separate removable hierarchy.'
    stage_coll=bpy.data.collections.new('STUDIO / presentation only')
    bpy.context.scene.collection.children.link(stage_coll)
    bpy.context.view_layer.active_layer_collection=bpy.context.view_layer.layer_collection.children[stage_coll.name]
    cam=setup_stage(title,subtitle,accent)
    scene=bpy.context.scene
    scene.name=title
    scene.frame_end=result.get('animation_end',25)
    for f,label in [(1,'WINGS UP'),(7,'GLIDE'),(13,'DOWNSTROKE'),(19,'RECOVERY')]:
        scene.timeline_markers.new(label,frame=f)
    scene.frame_set(1)
    scene['Instructions']='Space plays wing motion. Numpad 0 shows hero camera. MODEL collection contains editable geometry; STUDIO is presentation only.'
    scene['Scope']='Procedural 3D interpretation of the approved concept artwork; this is not a Roblox runtime capture.'
    for d in ('models','screenshots','reports'):
        (OUT/d).mkdir(exist_ok=True,parents=True)
    path=OUT/'models'/(slug+'.blend')
    for screen in bpy.data.screens:
        for ar in screen.areas:
            if ar.type=='VIEW_3D':
                ar.spaces.active.region_3d.view_perspective='CAMERA'
                ar.spaces.active.shading.type='MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print('MODEL_SAVED',path,flush=True)
    report={'asset':title,'blend':str(path),'mesh_objects':0,'triangles':0,'animated_objects':[], 'shape_animated_objects':[], 'pose_bounds':{},'renders':[]}
    deps=bpy.context.evaluated_depsgraph_get()
    for o in asset_coll.all_objects:
        if o.type=='MESH':
            report['mesh_objects']+=1
            me=o.evaluated_get(deps).to_mesh()
            me.calc_loop_triangles()
            report['triangles']+=len(me.loop_triangles)
            o.evaluated_get(deps).to_mesh_clear()
        if o.animation_data and o.animation_data.action:
            report['animated_objects'].append(o.name)
        if o.type=='MESH' and o.data.shape_keys and o.data.shape_keys.animation_data:
            report['shape_animated_objects'].append(o.name)
    for frame in (1,13,25):
        scene.frame_set(frame)
        pts=[]
        dep=bpy.context.evaluated_depsgraph_get()
        for o in asset_coll.all_objects:
            if o.type=='MESH':
                ev=o.evaluated_get(dep)
                pts.extend([ev.matrix_world@Vector(v) for v in ev.bound_box])
        report['pose_bounds'][str(frame)]={'min':[min(p[i] for p in pts) for i in range(3)],'max':[max(p[i] for p in pts) for i in range(3)]}
    # The large hero image, an opposite-side view, and two flap extremes.
    views=[('hero',1,(6,-17,10),13.8),('side',7,(14,-7,5),13.8),('wings-up',1,(-9,-15,6),13.8),('wings-down',13,(-9,-15,6),13.8)]
    if '--quick' in args:
        scene.render.resolution_percentage=60
        views=views[:1]
    if '--build-only' not in args:
        for name,frame,loc,scale in views:
            scene.frame_set(frame)
            cam.location=loc
            aim(cam,(0,.25,.4))
            cam.data.ortho_scale=scale
            scene.render.filepath=str(OUT/'screenshots'/(slug+'-'+name+'.png'))
            bpy.ops.render.render(write_still=True)
            report['renders'].append(scene.render.filepath)
            print('RENDER_SAVED',scene.render.filepath,flush=True)
    scene.frame_set(1)
    cam.location=(6,-17,10);aim(cam,(0,.25,.4));cam.data.ortho_scale=13.8
    scene.render.resolution_percentage=100
    scene.render.filepath=str(OUT/'screenshots'/(slug+'-hero.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    (OUT/'reports'/(slug+'.json')).write_text(json.dumps(report,indent=2))
    print('BUILD_COMPLETE',json.dumps(report),flush=True)


if __name__=='__main__':
    main()
