import struct
import sys
from pathlib import Path

import pytest

sys.path.append(str(Path(__file__).resolve().parents[1]))

from tools import nav2021


def _build_sample_nav() -> bytes:
    node_struct = struct.Struct("<3f f I H H I H H")
    link_struct = struct.Struct("<IfI")

    nodes = [
        node_struct.pack(0.0, 0.0, 0.0, 16.0, 0, 0, 0, 0, 1, 0),
        node_struct.pack(100.0, 0.0, 0.0, 16.0, 0, 0, 0, 1, 1, 0),
    ]

    links = [
        link_struct.pack(1, 100.0, 0),
        link_struct.pack(0, 100.0, 0),
    ]

    node_data = b"".join(nodes)
    link_data = b"".join(links)

    header = [
        b"NAV2",
        struct.pack("<I", 1),  # version
        struct.pack("<I", 2),  # directory count
    ]

    directory_offset = 12
    node_offset = directory_offset + 2 * 12
    link_offset = node_offset + len(node_data)

    directories = [
        b"NODS" + struct.pack("<II", node_offset, len(node_data)),
        b"LINK" + struct.pack("<II", link_offset, len(link_data)),
    ]

    blob = b"".join(header + directories)
    blob += node_data
    blob += link_data
    return blob


def test_load_nav_data_parses_nodes_and_links():
    mesh = nav2021.load_nav_data(_build_sample_nav())
    assert len(mesh.nodes) == 2
    assert len(mesh.links) == 2


def test_find_path_returns_shortest_route():
    mesh = nav2021.load_nav_data(_build_sample_nav())
    path = mesh.find_path((0.0, 0.0, 0.0), (100.0, 0.0, 0.0))
    assert path == [mesh.nodes[0].origin, mesh.nodes[1].origin]


def test_missing_required_chunk_raises():
    blob = _build_sample_nav()
    # Clobber the "LINK" entry in the directory table to simulate a missing
    # chunk.
    broken = bytearray(blob)
    broken[24:28] = b"MISS"

    with pytest.raises(nav2021.NavParseError):
        nav2021.load_nav_data(bytes(broken))

