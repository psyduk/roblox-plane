"""Package source into a self-contained local Roblox Studio place (no uploads)."""
from itertools import count
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def build(output: Path):
    doc = ET.Element("roblox", {"version": "4"})
    ET.SubElement(doc, "External").text = "null"
    ET.SubElement(doc, "External").text = "nil"
    ids = count(1)
    def item(parent, kind, name):
        node = ET.SubElement(parent,"Item",{"class":kind,"referent":f"RBX{next(ids)}"})
        props = ET.SubElement(node,"Properties")
        ET.SubElement(props,"string",{"name":"Name"}).text=name
        return node,props
    def source(parent,kind,name,path):
        _,props=item(parent,kind,name)
        ET.SubElement(props,"ProtectedString",{"name":"Source"}).text=(ROOT/path).read_text()
    workspace,props=item(doc,"Workspace","Workspace")
    ET.SubElement(props,"float",{"name":"FallenPartsDestroyHeight"}).text="-80"
    replicated,_=item(doc,"ReplicatedStorage","ReplicatedStorage")
    shared,_=item(replicated,"Folder","FlightGame")
    for filename in ("PlaneCatalog","PowerCatalog","CosmeticCatalog","Simulation","World"):
        source(shared,"ModuleScript",filename,f"src/shared/{filename}.luau")
    item(shared,"RemoteEvent","Command")
    item(shared,"RemoteEvent","Snapshot")
    server,_=item(doc,"ServerScriptService","ServerScriptService")
    source(server,"Script","FlightServer","src/server/Main.server.luau")
    for filename in ("PlayerStats", "Telemetry"):
        source(server,"ModuleScript",filename,f"src/server/{filename}.luau")
    storage,_=item(doc,"ServerStorage","ServerStorage")
    for filename in ("Simulation", "PlaneCatalog", "PowerCatalog", "CosmeticCatalog", "PlayerStats", "Telemetry", "FlightAudio"):
        test_path=ROOT/f"tests/{filename}.spec.luau"
        if test_path.exists():
            source(storage,"ModuleScript",f"{filename}Tests",f"tests/{filename}.spec.luau")
    starter,_=item(doc,"StarterPlayer","StarterPlayer")
    player_scripts,_=item(starter,"StarterPlayerScripts","StarterPlayerScripts")
    source(player_scripts,"LocalScript","FlightClient","src/client/Main.client.luau")
    for filename in ("Hud", "EffectsShop", "HangarBay", "FlightAudio", "PilotAvatar"):
        source(player_scripts,"ModuleScript",filename,f"src/client/{filename}.luau")
    lighting,props=item(doc,"Lighting","Lighting")
    ET.SubElement(props,"float",{"name":"ClockTime"}).text="14"
    ET.SubElement(props,"float",{"name":"Brightness"}).text="2"
    output.parent.mkdir(parents=True,exist_ok=True)
    ET.indent(doc)
    ET.ElementTree(doc).write(output,encoding="utf-8",xml_declaration=True)
    print(f"Built {output} ({output.stat().st_size:,} bytes)")
    print("Open in Roblox Studio and press Play. Studio uses session-only stats; published live servers enable cloud saving. No paid products.")

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=ROOT/"Skybound.rbxlx")
    args=parser.parse_args()
    build(args.output.resolve())
