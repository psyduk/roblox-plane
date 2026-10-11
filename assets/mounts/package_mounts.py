"""Package measured Studio imports as the durable, cloneable MountTemplates.

Input: assets/mounts/roblox-import.json, either {"skins": {skin: record}} or a
direct skin map. Every record has parts with name, meshId, textureId, size,
meshSize, cframe, and optional surface texture IDs. The measured size and
cframe MUST already be normalized to a 12-stud wingspan, +X forward, origin
centered. Packaging scales sizes and CFrame positions by 16/12 for a readable
16-stud template wingspan. Rotation and original meshSize stay unchanged.

Example record:
{"skins":{"stormcrown":{"parts":[{"name":"Body","meshId":"rbxassetid://1",
"textureId":"","size":[1,1,1],"meshSize":[1,1,1],
"cframe":[0,0,0,1,0,0,0,1,0,0,0,1],"surface":{"ColorMap":"rbxassetid://2"}}]}}}

Run after all four Studio imports are recorded:
    python3 assets/mounts/package_mounts.py
The Blender exports and import records are read only.
"""
import argparse
import base64
import json
import math
import struct
from pathlib import Path
import xml.etree.ElementTree as ET

OUT = Path(__file__).resolve().parent
SKINS = {
    'stormcrown': '01-stormcrown-eagle',
    'ironwing': '02-ironwing-eagle',
    'phoenix': '03-eclipse-phoenix',
    'riftmanta': '04-rift-manta',
}
IDENTITY = [1,0,0,0,1,0,0,0,1]
IMPORT_WINGSPAN = 12.0
WINGSPAN = 16.0
SURFACE_MAPS = ('ColorMap','NormalMap','MetalnessMap','RoughnessMap')


def numbers(value, length, label):
    if not isinstance(value, (list,tuple)) or len(value)!=length:
        raise ValueError(f'{label} must contain {length} numbers')
    result = [float(v) for v in value]
    if not all(math.isfinite(v) for v in result):
        raise ValueError(f'{label} contains nonfinite numbers')
    return result


def asset_uri(value, label, required=False):
    value = str(value or '')
    if value.isdecimal():
        value = 'rbxassetid://'+value
    if not value and not required:
        return ''
    if not value.startswith(('rbxassetid://','http://www.roblox.com/asset/','https://www.roblox.com/asset/')):
        raise ValueError(f'{label} must reference a durable uploaded Roblox asset, got {value!r}')
    return value


def attributes(props, values):
    """Roblox AttributesSerialize: little-endian count, names, Float64 (0x06)."""
    raw = bytearray(struct.pack('<I',len(values)))
    for name, value in sorted(values.items()):
        encoded = name.encode('utf-8')
        raw.extend(struct.pack('<I',len(encoded)))
        raw.extend(encoded)
        raw.append(0x06)
        raw.extend(struct.pack('<d',float(value)))
    ET.SubElement(props,'BinaryString',name='AttributesSerialize').text = base64.b64encode(raw).decode('ascii')


class Document:
    def __init__(self):
        self.root = ET.Element('roblox',version='4')
        ET.SubElement(self.root,'External').text = 'null'
        ET.SubElement(self.root,'External').text = 'nil'
        self.counter = 0

    def item(self, parent, kind, name):
        self.counter += 1
        node = ET.SubElement(parent,'Item',{'class':kind,'referent':f'MountAsset_{self.counter}'})
        props = ET.SubElement(node,'Properties')
        ET.SubElement(props,'string',name='Name').text = name
        return node,props


def vector(props, name, values):
    node = ET.SubElement(props,'Vector3',name=name)
    for axis,value in zip('XYZ',values):
        ET.SubElement(node,axis).text = repr(float(value))


def frame(props, values):
    node = ET.SubElement(props,'CoordinateFrame',name='CFrame')
    for name,value in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'),values):
        ET.SubElement(node,name).text = repr(float(value))


def content(props, name, value):
    if value:
        ET.SubElement(ET.SubElement(props,'Content',name=name),'url').text = value


def physics(props, visible=True):
    for name,value in [('Anchored',True),('CanCollide',False),('CanTouch',False),('CanQuery',False),('Massless',True),('CastShadow',False)]:
        ET.SubElement(props,'bool',name=name).text = str(value).lower()
    ET.SubElement(props,'float',name='Transparency').text = '0' if visible else '1'


def pivot_model(doc, parent, name, position):
    model,props = doc.item(parent,'Model',name)
    pivot,pivot_props = doc.item(model,'Part','Pivot')
    physics(pivot_props,visible=False)
    vector(pivot_props,'size',(.1,.1,.1))
    frame(pivot_props,list(position)+IDENTITY)
    ET.SubElement(props,'Ref',name='PrimaryPart').text = pivot.attrib['referent']
    return model,props


def package(input_path, output_path):
    source = json.loads(input_path.read_text())
    records = source.get('skins',source)
    missing = [skin for skin in SKINS if skin not in records]
    if missing:
        raise ValueError('Missing completed Studio imports: '+', '.join(missing))
    doc = Document()
    folder,_ = doc.item(doc.root,'Folder','MountTemplates')
    summary = []
    for skin,slug in SKINS.items():
        manifest = json.loads((OUT/slug/'manifest.json').read_text())
        metadata = {part['name']:part for part in manifest['parts']}
        record = records[skin]
        if 'wingspan' in record and abs(float(record['wingspan'])-IMPORT_WINGSPAN)>.001:
            raise ValueError(f'{skin}: import record must use {IMPORT_WINGSPAN} stud wingspan')
        # Studio's current GLB importer appends Mesh to the exported node names.
        # Copy records before normalization so input data stays untouched.
        parts = []
        for source_part in record['parts']:
            part = dict(source_part)
            if part['name'] not in metadata and part['name'].endswith('Mesh'):
                part['name'] = part['name'][:-4]
            parts.append(part)
        part_names = [part['name'] for part in parts]
        if len(set(part_names))!=len(part_names):
            raise ValueError(f'{skin}: duplicate imported part names')
        if set(part_names)!=set(metadata):
            raise ValueError(f'{skin}: expected {sorted(metadata)}, got {sorted(part_names)}')
        scale = WINGSPAN/float(manifest['source_wingspan'])
        seat = [v*scale for v in numbers(manifest['seat_roblox'],3,f'{skin}.seat')]
        seat[1] += .65
        model,model_props = pivot_model(doc,folder,skin,(0,0,0))
        amplitude = .28 if skin=='riftmanta' else .4
        attributes(model_props,{
            'PilotScale':.6,'CockpitX':seat[0],'CockpitY':seat[1],'CockpitZ':seat[2],
            'CockpitYaw':-math.pi/2,'FlapAmplitude':amplitude,'IdleFlapAmplitude':amplitude*.3,
            'FlapFrequency':.85 if skin=='riftmanta' else 1.25,
        })
        group_positions = {'Body':[0,0,0]}
        runtime_groups = {}
        runtime_part_names = {}
        for name,meta in metadata.items():
            group = meta['motion_group']
            if group=='Body':
                runtime='Body'
            else:
                # Runtime facing +X defines left at negative Z. Source Blender
                # WingLeft was X-negative and therefore becomes positive Z.
                pivot = numbers(meta['pivot_roblox'],3,f'{skin}/{name}.pivot')
                if abs(pivot[2])<1e-6:
                    raise ValueError(f'{skin}/{name}: wing hinge must have a nonzero Z')
                runtime = 'WingLeft' if pivot[2]<0 else 'WingRight'
                normalized_pivot = [v*scale for v in pivot]
                if runtime in group_positions and any(abs(a-b)>1e-5 for a,b in zip(group_positions[runtime],normalized_pivot)):
                    raise ValueError(f'{skin}: inconsistent solid/glow wing hinges')
                group_positions[runtime]=normalized_pivot
            runtime_groups[name]=runtime
            runtime_part_names[name]=runtime+('Glow' if meta['glow'] else 'Mesh')
        if set(group_positions)!={'Body','WingLeft','WingRight'}:
            raise ValueError(f'{skin}: incomplete animated wing groups')
        group_nodes = {}
        for name in ('Body','WingLeft','WingRight'):
            group_nodes[name],_=pivot_model(doc,model,name,group_positions[name])
        bounds=[]
        for part in parts:
            name=part['name']; meta=metadata[name]
            cf=numbers(part['cframe'],12,f'{skin}/{name}.cframe')
            size=numbers(part['size'],3,f'{skin}/{name}.size')
            import_scale=WINGSPAN/IMPORT_WINGSPAN
            cf=[value*import_scale if index<3 else value for index,value in enumerate(cf)]
            size=[value*import_scale for value in size]
            original_size=numbers(part['meshSize'],3,f'{skin}/{name}.meshSize')
            if not all(v>0 for v in size+original_size):
                raise ValueError(f'{skin}/{name}: mesh dimensions must be positive')
            mesh,props=doc.item(group_nodes[runtime_groups[name]],'MeshPart',runtime_part_names[name])
            content(props,'MeshId',asset_uri(part['meshId'],f'{skin}/{name}.meshId',required=True))
            content(props,'TextureID',asset_uri(part.get('textureId'),f'{skin}/{name}.textureId'))
            physics(props)
            ET.SubElement(props,'bool',name='DoubleSided').text='true' if part.get('doubleSided',False) else 'false'
            ET.SubElement(props,'token',name='Material').text='288' if meta['glow'] else '256'
            ET.SubElement(props,'Color3uint8',name='Color3uint8').text='4294967295'
            vector(props,'size',size)
            vector(props,'InitialSize',original_size)
            frame(props,cf)
            surface=part.get('surface') or {}
            maps={key:asset_uri(surface.get(key),f'{skin}/{name}.{key}') for key in SURFACE_MAPS}
            if any(maps.values()):
                _,appearance=doc.item(mesh,'SurfaceAppearance','MountPalette')
                for key,value in maps.items():
                    content(appearance,key,value)
            # A transformed box bounds the normalized visible mesh and catches
            # untranslated Studio coordinates and accidental double scaling.
            half_z=sum(abs(cf[9+i])*size[i]*.5 for i in range(3))
            bounds.append((cf[2]-half_z,cf[2]+half_z))
        measured_span=max(b[1] for b in bounds)-min(b[0] for b in bounds)
        if not WINGSPAN*.9<=measured_span<=WINGSPAN*1.1:
            raise ValueError(f'{skin}: expected approximately {WINGSPAN:g} stud template span, measured {measured_span:.3f}; normalize import size/cframe to {IMPORT_WINGSPAN:g} studs first')
        summary.append({'skin':skin,'mesh_parts':len(parts),'scale':scale,'cockpit':seat,'wing_pivots':group_positions,'box_wingspan':measured_span})
    output_path.parent.mkdir(parents=True,exist_ok=True)
    ET.indent(doc.root)
    ET.ElementTree(doc.root).write(output_path,encoding='utf-8',xml_declaration=True)
    report={'output':str(output_path),'input':str(input_path),'skins':summary,'input_wingspan':IMPORT_WINGSPAN,'input_to_template_scale':WINGSPAN/IMPORT_WINGSPAN,'wingspan':WINGSPAN,'pilot_scale':.6,'seat_hrp_offset_y':.65,'geometry':'Uploaded Roblox mesh references; no runtime MeshId writes or EditableMesh requirement.'}
    output_path.with_suffix('.report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
    return output_path


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input',type=Path,default=OUT/'roblox-import.json')
    parser.add_argument('--output',type=Path,default=OUT/'MountTemplates.rbxmx')
    args=parser.parse_args()
    package(args.input,args.output)
