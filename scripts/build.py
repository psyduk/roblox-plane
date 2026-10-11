"""Package source into a self-contained local Roblox Studio place (no uploads)."""
from itertools import count
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def build(output: Path):
    output = output.resolve()
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
    for filename in ("PlaneCatalog","PowerCatalog","CosmeticCatalog","Simulation","BattleSimulation","BattleSkills","SkillCatalog","MountVisuals","World"):
        source(shared,"ModuleScript",filename,f"src/shared/{filename}.luau")
    mount_asset = ET.parse(ROOT / "assets/mounts/MountTemplates.rbxmx").getroot()
    for template in mount_asset.findall("Item"):
        shared.append(template)
    item(shared,"RemoteEvent","Command")
    item(shared,"RemoteEvent","Snapshot")
    item(shared,"RemoteEvent","BattleCommand")
    item(shared,"RemoteEvent","BattleSnapshot")
    server,_=item(doc,"ServerScriptService","ServerScriptService")
    source(server,"Script","FlightServer","src/server/Main.server.luau")
    for filename in ("PlayerStats", "Telemetry", "BattleLab"):
        source(server,"ModuleScript",filename,f"src/server/{filename}.luau")
    storage,_=item(doc,"ServerStorage","ServerStorage")
    for filename in ("Simulation", "BattleSimulation", "BattleMatch", "SkillCatalog", "PlaneCatalog", "PowerCatalog", "CosmeticCatalog", "PlayerStats", "Telemetry", "FlightAudio", "BattleAudio", "BattleView", "BattleClient", "MountVisuals"):
        test_path=ROOT/f"tests/{filename}.spec.luau"
        if test_path.exists():
            source(storage,"ModuleScript",f"{filename}Tests",f"tests/{filename}.spec.luau")
    _,gui_props=item(doc,"StarterGui","StarterGui")
    ET.SubElement(gui_props,"token",{"name":"ScreenOrientation"}).text="4"  # Sensor: permit portrait and landscape.
    starter,_=item(doc,"StarterPlayer","StarterPlayer")
    player_scripts,_=item(starter,"StarterPlayerScripts","StarterPlayerScripts")
    source(player_scripts,"LocalScript","FlightClient","src/client/Main.client.luau")
    for filename in ("Hud", "EffectsShop", "HangarBay", "FlightAudio", "PilotAvatar", "BattleLab", "BattleView", "BattleAudio", "ChallengePanel"):
        source(player_scripts,"ModuleScript",filename,f"src/client/{filename}.luau")
    lighting,props=item(doc,"Lighting","Lighting")
    ET.SubElement(props,"float",{"name":"ClockTime"}).text="14"
    ET.SubElement(props,"float",{"name":"Brightness"}).text="2"
    output.parent.mkdir(parents=True,exist_ok=True)
    ET.indent(doc)
    ET.ElementTree(doc).write(output,encoding="utf-8",xml_declaration=True)
    print(f"Built {output} ({output.stat().st_size:,} bytes)")
    playtest = output
    if output == (ROOT / "Skybound.rbxlx").resolve():
        # A distinct Studio document title prevents confusing this candidate with
        # older Skybound.rbxlx copies still open from other worktrees.
        playtest = ROOT / "build" / "Sky-Battle-Playtest.rbxlx"
        playtest.parent.mkdir(parents=True, exist_ok=True)
        playtest.write_bytes(output.read_bytes())
        print(f"Identical playtest copy: {playtest}")
    print(f"Stop old Play sessions, then reopen this exact file in Roblox Studio: {playtest}")
    print("Press Studio Play. Verify the plane-battle hangar; its main PLAY must lead to rival search, card picks, and a first-to-two battle.")
    print("A distance/furthest-flight screen means the wrong place is running. Studio uses session-only stats; this command does not publish.")

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=Path,default=ROOT/"Skybound.rbxlx")
    args=parser.parse_args()
    build(args.output.resolve())
