"""Rift Manta: a sculpted, rideable celestial ray with animated fins.

All parts are genuine editable geometry. Fin skins, inset markings and rim
filaments share the same shape-key wave so they remain attached in flight.
"""
from common import *
import bpy
import math
from mathutils import Vector


def _m_mesh(name, verts, faces, materials, parent, mids=None, subdiv=0):
    data = bpy.data.meshes.new(name + "_mesh")
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    for material in materials:
        data.materials.append(material)
    for i, poly in enumerate(data.polygons):
        poly.use_smooth = True
        if mids:
            poly.material_index = mids[i]
    if subdiv:
        mod = obj.modifiers.new("Sculpted skin continuity", "SUBSURF")
        mod.levels = subdiv
        mod.render_levels = subdiv
    return obj


def _m_tube(name, points, radii, material, parent, sides=8):
    """Mesh tube, used so fin filaments can share the fin deformation."""
    verts, faces = [], []
    if isinstance(radii, (int, float)):
        radii = [radii] * len(points)
    for i, point in enumerate(points):
        p = Vector(point)
        a = Vector(points[max(0, i - 1)])
        b = Vector(points[min(len(points) - 1, i + 1)])
        tangent = (b - a).normalized()
        side = tangent.cross(Vector((0, 0, 1)))
        if side.length < .001:
            side = tangent.cross(Vector((0, 1, 0)))
        side.normalize()
        up = tangent.cross(side).normalized()
        for j in range(sides):
            angle = math.tau * j / sides
            verts.append(tuple(p + radii[i] * (math.cos(angle) * side + math.sin(angle) * up)))
    for i in range(len(points) - 1):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(points) - 1) * sides + j for j in range(sides)))
    return _m_mesh(name, verts, faces, [material], parent)


def _m_wave(obj):
    """One looping 24-frame swim cycle, with bending rather than rigid flaps."""
    obj.shape_key_add(name="Basis")
    for label, direction, apex in (("Crest", 1, 1), ("Sweep", -1, 13)):
        key = obj.shape_key_add(name=label, from_mix=False)
        for vert in key.data:
            t = max(0, min(1, (abs(vert.co.x) - .68) / 4.50))
            # Strong supple motion at the tip; the attachment remains fixed.
            vert.co.z += direction * 1.38 * t ** 1.65
            vert.co.y += direction * .13 * math.sin(math.pi * t)
        for frame in (1, 7, 13, 19, 25):
            key.value = 1.0 if frame == apex or (apex == 1 and frame == 25) else 0.0
            key.keyframe_insert(data_path="value", frame=frame)
    action = obj.data.shape_keys.animation_data.action
    # Blender 4.4+ layered actions are handled without relying on .fcurves.
    fcurves = list(getattr(action, 'fcurves', []))
    for layer in getattr(action, 'layers', []):
        for strip in layer.strips:
            for bag in getattr(strip, 'channelbags', []):
                fcurves.extend(bag.fcurves)
    for fc in fcurves:
        fc.modifiers.new('CYCLES')


def _m_fin_point(side, u, v, top=True):
    """Swept diamond fin, thick at root and exquisitely thin at wingtip."""
    x = .63 + 4.53 * u
    leading = -1.36 + 1.75 * u ** 1.45 - .31 * math.sin(math.pi * u)
    trailing = 1.39 - 1.00 * u ** 1.03 + .31 * math.sin(math.pi * u)
    y = leading * (1 - v) + trailing * v
    # A shallow double curvature creates a living manta silhouette in stills.
    centre = .08 + .19 * math.sin(math.pi * u) + .82 * u ** 4
    centre += .10 * math.sin(math.pi * v) * math.sin(math.pi * u)
    centre += .09 * (v - .5) * math.sin(math.pi * u)
    thickness = (.21 * (1 - u) ** .66 + .013) * math.sin(math.pi * v) ** .58
    z = centre + thickness if top else centre - thickness * .88
    return (side * x, y, z)


def _m_make_fin(side, skin, belly, root):
    nu, nv = 42, 28
    verts, faces, mids = [], [], []
    for top in (True, False):
        for i in range(nu + 1):
            for j in range(nv + 1):
                verts.append(_m_fin_point(side, i / nu, j / nv, top))
    layer = (nu + 1) * (nv + 1)
    for k in range(2):
        for i in range(nu):
            for j in range(nv):
                a = k * layer + i * (nv + 1) + j
                face = (a, a + nv + 1, a + nv + 2, a + 1)
                if (k == 1) ^ (side < 0):
                    face = tuple(reversed(face))
                faces.append(face)
                mids.append(k)
    for i in range(nu):
        for j in (0, nv):
            a = i * (nv + 1) + j
            b = (i + 1) * (nv + 1) + j
            faces.append((a, b, layer + b, layer + a))
            mids.append(0)
    for i in (0, nu):
        for j in range(nv):
            a = i * (nv + 1) + j
            faces.append((a, a + layer, a + layer + 1, a + 1))
            mids.append(0)
    wing = _m_mesh(("Port" if side < 0 else "Starboard") + " / supple manta fin", verts, faces, [skin, belly], root, mids, 1)
    _m_wave(wing)
    return wing


def _m_ribbon(name, side, samples, widths, material, root):
    verts, faces = [], []
    for i, (u, v) in enumerate(samples):
        width = widths[i] if isinstance(widths, list) else widths
        for vv in (v - width, v + width):
            p = list(_m_fin_point(side, u, vv, True))
            p[2] += .013
            verts.append(p)
        if i:
            faces.append((2 * i - 2, 2 * i, 2 * i + 1, 2 * i - 1))
    obj = _m_mesh(name, verts, faces, [material], root)
    _m_wave(obj)
    return obj


def _m_galactic_skin():
    skin = mat("RIFT / midnight indigo lacquer", (.009, .016, .057, 1), metallic=.32, roughness=.34)
    skin.use_nodes = True
    nodes, links = skin.node_tree.nodes, skin.node_tree.links
    bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = 2.0
    tex.inputs["Detail"].default_value = 3
    tex.inputs["Roughness"].default_value = .72
    coords = nodes.new("ShaderNodeTexCoord")
    links.new(coords.outputs["Generated"], tex.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = .20
    ramp.color_ramp.elements[0].color = (.007, .011, .035, 1)
    ramp.color_ramp.elements[1].position = .83
    ramp.color_ramp.elements[1].color = (.018, .027, .085, 1)
    links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return skin


def build_manta():
    root = empty("RIFT MANTA / animated cosmic ride")
    skin = _m_galactic_skin()
    belly = mat("RIFT / pale seafoam ventral skin", (.34, .74, .72, 1), metallic=.08, roughness=.35)
    dark = mat("RIFT / deep sapphire sculpted brows", (.018, .033, .105, 1), metallic=.40, roughness=.30)
    glow = mat("RIFT / living cyan markings", (.04, .80, .88, 1), metallic=.2, roughness=.26, emission=1.3)
    rim = mat("RIFT / fine lilac leading edge", (.29, .12, .77, 1), metallic=.40, roughness=.25, emission=.75)
    gold = mat("RIFT / warm champagne mount fittings", (.68, .40, .11, 1), metallic=.78, roughness=.23)
    eyes = mat("RIFT / luminous amber gaze", (.9, .29, .012, 1), metallic=.15, roughness=.20, emission=.65)
    pupil = mat("RIFT / obsidian pupil", (.003, .006, .015, 1), roughness=.18)
    saddle = mat("RIFT / charcoal saddle leather", (.035, .021, .035, 1), metallic=.10, roughness=.57)
    crystal = mat("RIFT / violet tail gem", (.39, .07, .72, 1), metallic=.35, roughness=.20, emission=.5)
    core = mat("RIFT / tail gem cyan heart", (.12, .88, 1, 1), metallic=.2, roughness=.17, emission=1.8)

    # Blended broad dorsal dome, low belly and rounded front create a ray's disc.
    ellipsoid("RIFT / broad sculpted dorsal disc", (0, -.02, .045), (1.35, 1.63, .55), skin, parent=root)
    ellipsoid("RIFT / smooth ventral disc", (0, -.05, -.15), (1.24, 1.47, .41), belly, parent=root)
    # A lengthened arrow-shaped head has a low chin and a proud central ridge.
    # This is a true loft, avoiding the round frog muzzle of a sphere assembly.
    head_stations = [(-2.19, .025, -.04, .04), (-2.02, .24, .005, .115),
                     (-1.80, .47, .07, .22), (-1.54, .70, .12, .285),
                     (-1.25, .87, .14, .315), (-.91, .99, .11, .35),
                     (-.51, .99, .09, .35), (-.20, .82, .06, .30)]
    verts, faces = [], []
    for y, width, centre, height in head_stations:
        for j in range(32):
            a = math.tau * j / 32
            verts.append((width * math.cos(a), y, centre + height * math.sin(a)))
    for i in range(len(head_stations) - 1):
        for j in range(32):
            a = i * 32 + j
            faces.append((a, i * 32 + (j + 1) % 32, (i + 1) * 32 + (j + 1) % 32, a + 32))
    faces.extend([tuple(reversed(range(32))), tuple((len(head_stations) - 1) * 32 + j for j in range(32))])
    _m_mesh("RIFT / sculpted elongated skull prow", verts, faces, [skin], root, subdiv=2)
    ellipsoid("RIFT / narrow inset ventral throat", (0, -1.51, -.155), (.40, .46, .115), belly, parent=root)
    for side in (-1, 1):
        _m_make_fin(side, skin, belly, root)
        # Fine leading-edge iridescence and a pale trailing silhouette.
        for v, label, material, radius in ((.008, "iridescent leading rim", rim, .021), (.992, "pale trailing edge", glow, .017)):
            pts = [_m_fin_point(side, .08 + .92 * i / 50, v, True) for i in range(51)]
            edge = _m_tube("RIFT / " + label, pts, radius, material, root)
            _m_wave(edge)
        # Swept organic light veins; surface ribbons taper at both ends.
        for n, (start, end, v0, v1) in enumerate(((.10, .92, .19, .27), (.21, .80, .59, .54), (.39, .93, .76, .64))):
            samples = []
            widths = []
            for i in range(30):
                t = i / 29
                samples.append((start + (end - start) * t, v0 + (v1 - v0) * t + .037 * math.sin(2 * math.pi * t)))
                widths.append((.014 if n else .025) * math.sin(math.pi * t) ** .55 + .001)
            _m_ribbon("RIFT / cyan celestial vein " + str(n), side, samples, widths, glow, root)
        # Restrained broad chevrons read at combat distance, unlike speckle noise.
        for n, u in enumerate((.29, .49, .69, .84)):
            sample = [(u - .031, .35), (u, .405), (u + .039, .35), (u + .009, .465)]
            _m_ribbon("RIFT / luminous ray rune " + str(n), side, sample, [.001, .022, .004, .001], glow, root)
        # Individual stars, deliberately sparse and tiny.
        for n in range(15):
            u = .19 + .66 * ((n * .61803398875) % 1)
            v = .16 + .63 * ((n * .382 + .137) % 1)
            p = _m_fin_point(side, u, v, True)
            radius = .013 if n % 5 else .023
            pts = [(p[0], p[1], p[2] + .019), (p[0], p[1], p[2] + .023)]
            star = _m_tube("RIFT / tiny star in skin", pts, radius, glow, root, sides=6)
            _m_wave(star)

        # Flush, narrow gold eye slits under overhanging diagonal brows.
        # Sharp inner/outer corners, with no spherical eyeball silhouette.
        centre = Vector((side * .77, -1.30, .34))
        along = Vector((side * .76, .65, .04)).normalized()
        across = Vector((-side * .65, .76, .15)).normalized()
        for label, length, width, lift, material in (("dark inset eye socket", .31, .11, 0, dark), ("slender amber eye", .255, .059, .019, eyes)):
            ev = [tuple(centre + Vector((0, 0, lift + .006)))]
            for j in range(32):
                a = math.tau * j / 32
                # Sine power sharpens the almond instead of rounding its ends.
                transverse = math.sin(a) * abs(math.sin(a)) ** .45
                ev.append(tuple(centre + along * length * math.cos(a) + across * width * transverse + Vector((0, 0, lift))))
            ef = [(0, j + 1, (j + 1) % 32 + 1) for j in range(32)]
            _m_mesh("RIFT / " + label, ev, ef, [material], root)
        brow_pts = []
        for j in range(19):
            t = j / 18
            p = centre + along * (-.34 + .68 * t) + across * (.075 + .025 * math.sin(math.pi * t)) + Vector((0, 0, .064))
            brow_pts.append(tuple(p))
        _m_tube("RIFT / overhanging predatory brow", brow_pts, [.025 + .054 * math.sin(math.pi * j / 18) for j in range(19)], skin, root)

        # Manta cephalic lobes: curled forward fleshy scrolls, with mint lining.
        verts, faces, mids = [], [], []
        stations, ring = 28, 16
        for i in range(stations + 1):
            t = i / stations
            cx = side * (.46 + .36 * math.sin(math.pi * t * .70))
            cy = -1.43 - 1.16 * t
            cz = -.04 + .32 * t ** 1.7
            width = .175 * math.sin(math.pi * (.16 + .84 * t)) ** .67 + .008
            thickness = .093 * (1 - t) ** .8 + .007
            for j in range(ring):
                a = math.tau * j / ring
                verts.append((cx + side * width * math.cos(a), cy, cz + thickness * math.sin(a)))
        for i in range(stations):
            for j in range(ring):
                a = i * ring + j
                faces.append((a, i * ring + (j + 1) % ring, (i + 1) * ring + (j + 1) % ring, a + ring))
                mids.append(0 if j < ring // 2 else 1)
        faces.extend([tuple(reversed(range(ring))), tuple(stations * ring + j for j in range(ring))])
        mids.extend([0, 0])
        _m_mesh("RIFT / curled cephalic fin", verts, faces, [skin, belly], root, mids, 1)
        # Broad turquoise facial slash linking shoulder to cephalic lobe.
        _m_tube("RIFT / face light stripe", [(side * 1.12, -.80, .27), (side * 1.0, -1.04, .36), (side * .66, -1.48, .32)], [.025, .04, .008], glow, root)
        for i in range(4):
            # Ventral gills are curved openings, never shark teeth.
            points = [(side * (.65 + .13 * j / 8), -.25 + .23 * i + .06 * math.sin(math.pi * j / 8), -.43 + .06 * j / 8) for j in range(9)]
            _m_tube("RIFT / ventral gill fold", points, .018, dark, root)

    mouth = [(x, -1.924 + .11 * (x / .31) ** 2, -.155 - .014 * math.cos(x * 4)) for x in [(-.31 + .62 * i / 24) for i in range(25)]]
    _m_tube("RIFT / quiet mouth seam", mouth, .018, dark, root)

    # Tapered whip tail follows a graceful lateral S; faceted gem is geometry.
    tail_pts = []
    tail_radii = []
    for i in range(65):
        t = i / 64
        tail_pts.append((.54 * math.sin(math.pi * t * 1.34) * t, 1.16 + 4.5 * t, .07 + .18 * math.sin(math.pi * t) + .67 * t ** 3))
        tail_radii.append(.18 * (1 - t) ** 1.45 + .025)
    _m_tube("RIFT / flowing tapered whip tail", tail_pts, tail_radii, skin, root, sides=12)
    _m_tube("RIFT / tail living filament", [(p[0], p[1], p[2] + r * .93) for p, r in zip(tail_pts, tail_radii)], .018, rim, root)
    tip = Vector(tail_pts[-1])
    gem_verts = [tuple(tip + Vector(v)) for v in ((0, .68, 0), (-.39, .17, 0), (0, -.23, 0), (.39, .17, 0), (0, .17, .14), (0, .17, -.14))]
    gem_faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (1, 0, 5), (2, 1, 5), (3, 2, 5), (0, 3, 5)]
    gem = _m_mesh("RIFT / amethyst diamond tail fin", gem_verts, gem_faces, [crystal], root)
    for p in gem.data.polygons:
        p.use_smooth = False
    inner_verts = [tuple(tip + Vector(v)) for v in ((0, .48, .105), (-.15, .18, .115), (0, -.035, .115), (.15, .18, .115), (0, .18, .19))]
    _m_mesh("RIFT / cyan jewel heart", inner_verts, [(0,1,4),(1,2,4),(2,3,4),(3,0,4)], [core], root)

    # Compact tangible saddle with visible padding, warm trim and a rear cantle.
    ellipsoid("RIFT / separate saddle foundation", (0, .18, .60), (.54, .70, .16), dark, parent=root)
    ellipsoid("RIFT / stitched saddle cushion", (0, .16, .74), (.435, .53, .12), saddle, parent=root)
    cantle = ellipsoid("RIFT / raised leather saddle cantle", (0, .65, .82), (.48, .14, .24), saddle, parent=root)
    for side in (-1, 1):
        rail = [(side * .49, -.42 + .98 * i / 20, .68 + .105 * math.sin(math.pi * i / 20)) for i in range(21)]
        _m_tube("RIFT / saddle champagne rail", rail, .028, gold, root)
        # Stirrup straps terminate in a clear metal loop.
        _m_tube("RIFT / hanging saddle strap", [(side * .45, .08, .71), (side * .67, .04, .34), (side * .73, -.02, .12)], .045, saddle, root)
        loop = [(side * .73 + .095 * math.cos(math.tau * j / 24), -.02, .06 + .13 * math.sin(math.tau * j / 24)) for j in range(25)]
        _m_tube("RIFT / open stirrup", loop, .018, gold, root)
    _m_tube("RIFT / saddle front grip", [(-.35, -.35, .82), (-.27, -.39, .93), (.27, -.39, .93), (.35, -.35, .82)], .044, gold, root)

    root["design"] = "Rift Manta — sculpted indigo ray, mint underside, celestial surface light and gem tail"
    root["animation"] = "24-frame repeatable fin undulation; fin skin and all wing markings deform together"
    root["preview_status"] = "Blender concept build; final Roblox rig, LOD and export preparation pending"
    return {"root": root, "rig": None, "seat": (0, .13, .85), "animation_end": 25}
