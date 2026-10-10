"""Package Pop Duel as a standalone Roblox place."""
from itertools import count
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SHARED = ('PegPowers', 'PegSimulation', 'PegWorld')
CLIENT = ('PegBoardView', 'PegAudio', 'PegAvatarView')


def build(output: Path):
    document = ET.Element('roblox', {'version': '4'})
    for value in ('null', 'nil'):
        ET.SubElement(document, 'External').text = value
    ids = count(1)

    def item(parent, kind, name):
        node = ET.SubElement(parent, 'Item', {'class': kind, 'referent': f'RBX{next(ids)}'})
        properties = ET.SubElement(node, 'Properties')
        ET.SubElement(properties, 'string', {'name': 'Name'}).text = name
        return node, properties

    def source(parent, kind, name, path):
        _, properties = item(parent, kind, name)
        ET.SubElement(properties, 'ProtectedString', {'name': 'Source'}).text = (ROOT / path).read_text()

    _, properties = item(document, 'Workspace', 'Workspace')
    ET.SubElement(properties, 'float', {'name': 'FallenPartsDestroyHeight'}).text = '-80'
    storage, _ = item(document, 'ReplicatedStorage', 'ReplicatedStorage')
    shared, _ = item(storage, 'Folder', 'PegGame')
    for name in SHARED:
        source(shared, 'ModuleScript', name, f'src/shared/{name}.luau')
    for name in ('Command', 'Snapshot'):
        item(shared, 'RemoteEvent', name)
    server, _ = item(document, 'ServerScriptService', 'ServerScriptService')
    source(server, 'Script', 'PegServer', 'src/server/PegServer.server.luau')
    starter, _ = item(document, 'StarterPlayer', 'StarterPlayer')
    player_scripts, _ = item(starter, 'StarterPlayerScripts', 'StarterPlayerScripts')
    source(player_scripts, 'LocalScript', 'PegClient', 'src/client/PegClient.client.luau')
    for name in CLIENT:
        source(player_scripts, 'ModuleScript', name, f'src/client/{name}.luau')
    _, properties = item(document, 'StarterGui', 'StarterGui')
    ET.SubElement(properties, 'token', {'name': 'ScreenOrientation'}).text = '4'  # Sensor
    _, properties = item(document, 'Lighting', 'Lighting')
    ET.SubElement(properties, 'float', {'name': 'ClockTime'}).text = '14'
    output.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(document)
    ET.ElementTree(document).write(output, encoding='utf-8', xml_declaration=True)
    print(f'Built {output} ({output.stat().st_size:,} bytes). Open in Studio and press Play.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'PopDuel.rbxlx')
    args = parser.parse_args()
    build(args.output.resolve())
