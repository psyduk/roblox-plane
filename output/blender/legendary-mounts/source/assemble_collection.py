"""Combine the four finished model scenes in one editable Blender library."""
import bpy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
bpy.ops.wm.read_factory_settings(use_empty=True)
default=bpy.context.scene
scenes=[]
for path in sorted((ROOT/'models').glob('0[1-4]-*.blend')):
    with bpy.data.libraries.load(str(path),link=False) as (source,target):
        target.scenes=source.scenes
    for scene in target.scenes:
        if scene:
            scenes.append(scene)
            print('APPENDED',path.name,scene.name,flush=True)
assert len(scenes)==4, 'Expected four editable mount scenes'
bpy.context.window.scene=scenes[0]
bpy.data.scenes.remove(default)
for path in sorted((ROOT/'source').glob('*.py')):
    text=bpy.data.texts.new('SOURCE / '+path.name)
    text.write(path.read_text())
guide=bpy.data.texts.new('START HERE / Legendary Mounts')
guide.write('''SKY BATTLE / LEGENDARY MOUNT STUDIES

Four native editable model scenes:
  STORMCROWN EAGLE
  IRONWING EAGLE
  ECLIPSE PHOENIX
  RIFT MANTA

Use the scene selector at the top right to switch designs.
Space plays the 24 fps preview wing cycle, frames 1-25.
Numpad 0 returns to the hero render camera.
The MODEL collection contains geometry, materials, animated wing controls,
and a removable generic seated pilot. The STUDIO collection is for previews.

The birds use animated parent pivots; the manta uses synchronized shape keys.
These are Blender design prototypes. They have not been optimized, assigned
the shared game collision bounds, converted to a Roblox export skeleton, or
imported into the Roblox experience. The pilot is a scale placeholder.

All sources are included as SOURCE text blocks and in the adjacent source
directory. Sixteen PNG screenshots are in the screenshots directory.
No external model assets or paid 3D generation service were used.
''')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.region_3d.view_perspective='CAMERA'
            space.region_3d.view_camera_zoom=0
            space.overlay.show_overlays=False
            space.shading.type='RENDERED'
for scene in scenes:
    scene.frame_set(1)
    scene['collection_guide']='See Text Editor: START HERE / Legendary Mounts'
target=ROOT/'Legendary-Mounts.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(target))
print('COLLECTION_SAVED',target,flush=True)
print('SCENES',[(s.name,len(s.objects)) for s in scenes],flush=True)
