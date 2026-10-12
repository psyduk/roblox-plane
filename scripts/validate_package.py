"""Verify source parity and clean playtest defaults; optionally write a manifest."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def serialized_attributes(item):
    """Read attribute names/booleans without mistaking source text for flags.

    Binary layout: https://github.com/rojo-rbx/rbx-dom/blob/master/docs/attributes.md
    Other values are consumed only to reach the next attribute safely.
    """
    encoded = item.find("Properties/BinaryString[@name='AttributesSerialize']")
    if encoded is None or not (encoded.text or "").strip():
        return {}
    data = io.BytesIO(base64.b64decode("".join(encoded.text.split()), validate=True))

    def take(size):
        value = data.read(size)
        assert len(value) == size, "Truncated serialized attributes"
        return value

    def uint():
        return struct.unpack("<I", take(4))[0]

    def string():
        return take(uint())

    result = {}
    fixed_sizes = {0x04: 4, 0x05: 4, 0x06: 8, 0x09: 8, 0x0A: 16,
                   0x0E: 4, 0x0F: 12, 0x10: 8, 0x11: 12, 0x1B: 8, 0x1C: 16}
    for _ in range(uint()):
        name = string().decode("utf-8")
        assert name not in result, f"Duplicate serialized attribute: {name}"
        kind = take(1)[0]
        if kind == 0x02:
            value = string()
        elif kind == 0x03:
            value = take(1) != b"\0"
        elif kind in fixed_sizes:
            value = take(fixed_sizes[kind])
        elif kind == 0x14:  # CFrame position, rotation ID, optional matrix.
            take(12)
            if take(1) == b"\0":
                take(36)
            value = None
        elif kind == 0x15:  # Enum name and value.
            string()
            take(4)
            value = None
        elif kind in (0x17, 0x19):  # NumberSequence / ColorSequence.
            take(uint() * (12 if kind == 0x17 else 20))
            value = None
        elif kind == 0x21:  # Font weight/style, family, cached face.
            take(3)
            string()
            string()
            value = None
        else:
            raise AssertionError(f"Unknown serialized attribute type {kind:#x}: {name}")
        result[name] = value
    assert data.read() == b"", "Trailing serialized attribute data"
    return result


def validate_playtest_defaults(item):
    name = item.findtext("Properties/string[@name='Name']", "<unnamed>")
    assert not name.startswith("SkyBattleNetwork"), f"Remove installed QA fixture: {name}"
    attributes = serialized_attributes(item)
    assert attributes.get("DistanceModeEnabled") is not True, f"Distance mode enabled on {name}"
    diagnostic = {key for key in attributes if key == "BattleFixedSeed"
                  or key.startswith("BattleExperimental") or key.startswith("SkyBattleNetwork")}
    if attributes.get("TestId") == b"SkyBattleNetworkV1":
        diagnostic.add("TestId")
    assert not diagnostic, f"Remove diagnostic attributes from {name}: {sorted(diagnostic)}"


def validate(place):
    packaged = {}
    for item in ET.parse(place).getroot().iter("Item"):
        validate_playtest_defaults(item)
        source = item.find("Properties/ProtectedString[@name='Source']")
        if source is None:
            continue
        name = item.find("Properties/string[@name='Name']").text
        if name.endswith("Tests"):
            relative = f"tests/{name[:-5]}.spec.luau"
        elif name == "FlightServer":
            relative = "src/server/Main.server.luau"
        elif name == "FlightClient":
            relative = "src/client/Main.client.luau"
        else:
            candidates = list((ROOT / "src").glob(f"*/{name}.luau"))
            # BattleLab has server and client modules; contents disambiguate.
            candidates = [p for p in candidates if p.read_text() == source.text]
            assert len(candidates) == 1, f"Missing, stale or ambiguous source: {name}"
            relative = str(candidates[0].relative_to(ROOT))
        expected = (ROOT / relative).read_text()
        assert expected == source.text, f"Packaged source differs: {relative}"
        assert relative not in packaged, f"Duplicate packaged script: {relative}"
        packaged[relative] = digest(expected.encode())
    expected = {str(p.relative_to(ROOT)) for p in (ROOT / "src").glob("*/*.luau")}
    expected |= {str(p.relative_to(ROOT)) for p in (ROOT / "tests").glob("*.spec.luau")}
    assert set(packaged) == expected, f"Missing/extra modules: {expected ^ set(packaged)}"
    return {"place": place.name, "placeSha256": digest(place.read_bytes()),
            "sourceCount": len(packaged), "sources": dict(sorted(packaged.items())),
            "scope": "Sky Battle ring-out; free playtest",
            "defaultMode": "ring_out", "diagnosticOverridesAbsent": True,
            "publishedVersion": None, "publishedAndRealPhoneVerified": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--place", type=Path, default=ROOT / "Skybound.rbxlx")
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    result = validate(args.place)
    if args.manifest:
        args.manifest.write_text(json.dumps(result, indent=2) + "\n")
    print(f"{result['sourceCount']} packaged scripts match source; ring-out defaults and no installed QA overrides; SHA-256 {result['placeSha256']}")
