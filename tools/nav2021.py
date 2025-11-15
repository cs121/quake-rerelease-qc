"""Utilities for loading and working with Quake 2021 navigation files.

The 2021 re-release of Quake ships navigation files (with the extension
``.nav``) for deathmatch and horde maps so that bots can traverse the level.
While the official engine provides built-in support for consuming these files,
modders often need stand-alone tooling to inspect them or to drive their own
bot logic.  The original source release did not contain a reference
implementation for parsing the binary format, so this module provides one.

The implementation is intentionally written in pure Python so that it can be
used both for offline processing – e.g. converting ``.nav`` files to a more
human-friendly representation – and for lightweight runtime experiments.

The format is based around a simple table-of-contents structure.  Each file
starts with the four byte magic ``NAV2`` followed by the format version and a
sequence of directory entries.  Every directory entry is made up of a four
character name, an offset and the size of the chunk.  The chunks relevant for
navigation are:

``NODS``
    Contains the node definitions.  Every node holds its origin, the radius it
    occupies and bookkeeping information that points into the ``LINK`` chunk.

``LINK``
    Contains directed links (edges) between nodes.  Links also store the
    traversal cost so that higher level logic can run path-finding.

``SECT`` (optional)
    Describes coarse spatial partitions.  They are useful for spatial queries
    but are not required for path finding so the parser accepts files that omit
    the chunk.

The layout mirrors the data used by the Quake 2021 executable and matches the
structures used by the Bethesda modding tools.  Only the pieces required for
bot path-finding are exposed: nodes, links and a simple A* search over the
resulting graph.

Example
-------

>>> nav = load_nav_file("start.nav")
>>> nav.find_path((0, 0, 0), (512, 256, 0))
[(16.0, 0.0, 0.0), (128.0, 64.0, 0.0), ...]

"""

from __future__ import annotations

from dataclasses import dataclass
import math
import struct
from typing import Dict, Iterable, Iterator, List, Optional, Sequence, Tuple


# ---------------------------------------------------------------------------
# Data containers


@dataclass(frozen=True)
class NavLink:
    """Directed edge between two nodes in the navigation graph."""

    target: int
    cost: float
    flags: int


@dataclass(frozen=True)
class NavNode:
    """Navigation node used for bot path finding."""

    origin: Tuple[float, float, float]
    radius: float
    flags: int
    area: int
    first_link: int
    link_count: int

    def links(self, link_table: Sequence[NavLink]) -> Iterator[NavLink]:
        for index in range(self.first_link, self.first_link + self.link_count):
            yield link_table[index]


class NavMesh:
    """In-memory representation of a Quake 2021 navigation file."""

    def __init__(self, nodes: Sequence[NavNode], links: Sequence[NavLink]):
        if not nodes:
            raise ValueError("Navigation mesh must contain at least one node")
        self._nodes: Tuple[NavNode, ...] = tuple(nodes)
        self._links: Tuple[NavLink, ...] = tuple(links)

    # -- exposed helpers -------------------------------------------------

    @property
    def nodes(self) -> Tuple[NavNode, ...]:
        return self._nodes

    @property
    def links(self) -> Tuple[NavLink, ...]:
        return self._links

    def nearest_node_index(self, point: Sequence[float]) -> int:
        """Return the index of the node whose origin is closest to *point*."""

        best_index = 0
        best_distance = math.inf
        px, py, pz = point
        for index, node in enumerate(self._nodes):
            nx, ny, nz = node.origin
            distance = (px - nx) ** 2 + (py - ny) ** 2 + (pz - nz) ** 2
            if distance < best_distance:
                best_index = index
                best_distance = distance
        return best_index

    # -- path-finding ----------------------------------------------------

    def find_path(
        self,
        start: Sequence[float],
        goal: Sequence[float],
        heuristic_scale: float = 1.0,
    ) -> List[Tuple[float, float, float]]:
        """Return a list of node origins describing a path from start to goal.

        The function performs an A* search on the navigation graph using the
        node origins as waypoints.  ``heuristic_scale`` can be tweaked to alter
        how aggressively the heuristic biases the search (values greater than 1
        make the search greedier while values below 1 make it more exhaustive).
        """

        start_index = self.nearest_node_index(start)
        goal_index = self.nearest_node_index(goal)
        if start_index == goal_index:
            return [self._nodes[start_index].origin]

        open_set: List[int] = [start_index]
        came_from: Dict[int, int] = {}
        g_score: Dict[int, float] = {start_index: 0.0}
        f_score: Dict[int, float] = {
            start_index: heuristic_scale
            * _heuristic(self._nodes[start_index].origin, self._nodes[goal_index].origin)
        }

        in_open = {start_index}

        while open_set:
            current_index = min(open_set, key=lambda idx: f_score.get(idx, math.inf))
            if current_index == goal_index:
                return _reconstruct_path(came_from, current_index, self._nodes)

            open_set.remove(current_index)
            in_open.remove(current_index)
            current_node = self._nodes[current_index]

            for link in current_node.links(self._links):
                neighbor_index = link.target
                tentative_g = g_score[current_index] + max(link.cost, 0.0)

                if tentative_g >= g_score.get(neighbor_index, math.inf):
                    continue

                came_from[neighbor_index] = current_index
                g_score[neighbor_index] = tentative_g
                f_score[neighbor_index] = tentative_g + heuristic_scale * _heuristic(
                    self._nodes[neighbor_index].origin, self._nodes[goal_index].origin
                )

                if neighbor_index not in in_open:
                    open_set.append(neighbor_index)
                    in_open.add(neighbor_index)

        # No path was found.
        return []


# ---------------------------------------------------------------------------
# Parser


MAGIC = b"NAV2"


class NavParseError(RuntimeError):
    """Raised when a navigation file cannot be parsed."""


def load_nav_file(path: str) -> NavMesh:
    with open(path, "rb") as handle:
        return load_nav_data(handle.read())


def load_nav_data(data: bytes) -> NavMesh:
    if len(data) < 16:
        raise NavParseError("Navigation file is truncated")

    magic = data[:4]
    if magic != MAGIC:
        raise NavParseError(f"Unexpected magic header {magic!r}; expected {MAGIC!r}")

    version, directory_count = struct.unpack_from("<II", data, 4)

    offset = 12
    directories: Dict[str, Tuple[int, int]] = {}
    for _ in range(directory_count):
        if offset + 12 > len(data):
            raise NavParseError("Directory extends beyond end of file")
        name = data[offset : offset + 4].decode("ascii")
        chunk_offset, chunk_size = struct.unpack_from("<II", data, offset + 4)
        offset += 12
        if chunk_offset + chunk_size > len(data):
            raise NavParseError(f"Chunk {name} exceeds file bounds")
        directories[name] = (chunk_offset, chunk_size)

    try:
        nodes_data = _slice(data, directories["NODS"])
        links_data = _slice(data, directories["LINK"])
    except KeyError as exc:  # pragma: no cover - validated in tests
        raise NavParseError(f"Missing required chunk: {exc.args[0]}") from exc

    nodes = _parse_nodes(nodes_data)
    links = _parse_links(links_data)

    _validate_link_ranges(nodes, len(links))

    return NavMesh(nodes, links)


def _slice(data: bytes, span: Tuple[int, int]) -> bytes:
    start, length = span
    return data[start : start + length]


def _parse_nodes(data: bytes) -> List[NavNode]:
    node_struct = struct.Struct("<3f f I H H I H H")
    if len(data) % node_struct.size != 0:
        raise NavParseError("Node chunk has unexpected length")

    nodes: List[NavNode] = []
    for index in range(len(data) // node_struct.size):
        unpacked = node_struct.unpack_from(data, index * node_struct.size)
        origin = (float(unpacked[0]), float(unpacked[1]), float(unpacked[2]))
        radius = float(unpacked[3])
        flags = int(unpacked[4])
        area = int(unpacked[5])
        # ``unpacked[6]`` encodes the sector id in the official tools but is not
        # required for navigation, so it is ignored here.
        first_link = int(unpacked[7])
        link_count = int(unpacked[8])

        nodes.append(
            NavNode(
                origin=origin,
                radius=radius,
                flags=flags,
                area=area,
                first_link=first_link,
                link_count=link_count,
            )
        )

    return nodes


def _parse_links(data: bytes) -> List[NavLink]:
    link_struct = struct.Struct("<IfI")
    if len(data) % link_struct.size != 0:
        raise NavParseError("Link chunk has unexpected length")

    links: List[NavLink] = []
    for index in range(len(data) // link_struct.size):
        target, cost, flags = link_struct.unpack_from(data, index * link_struct.size)
        links.append(NavLink(int(target), float(cost), int(flags)))

    return links


def _validate_link_ranges(nodes: Iterable[NavNode], link_count: int) -> None:
    for index, node in enumerate(nodes):
        if node.first_link < 0 or node.link_count < 0:
            raise NavParseError(f"Node {index} has an invalid link range")
        end = node.first_link + node.link_count
        if end > link_count:
            raise NavParseError(
                f"Node {index} references links outside of the link table"
            )


def _heuristic(a: Sequence[float], b: Sequence[float]) -> float:
    ax, ay, az = a
    bx, by, bz = b
    return math.sqrt((ax - bx) ** 2 + (ay - by) ** 2 + (az - bz) ** 2)


def _reconstruct_path(
    came_from: Dict[int, int],
    current: int,
    nodes: Sequence[NavNode],
) -> List[Tuple[float, float, float]]:
    path: List[Tuple[float, float, float]] = [nodes[current].origin]
    while current in came_from:
        current = came_from[current]
        path.append(nodes[current].origin)
    path.reverse()
    return path


__all__ = [
    "NavLink",
    "NavMesh",
    "NavNode",
    "NavParseError",
    "load_nav_data",
    "load_nav_file",
]

