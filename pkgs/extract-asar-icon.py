"""从 Electron app.asar 中取出 icon.png，写入指定路径。"""
import json
import struct
import sys

asar, out = sys.argv[1], sys.argv[2]
data = open(asar, "rb").read()

header_size = struct.unpack("<I", data[4:8])[0]
json_len = struct.unpack("<I", data[12:16])[0]
base = 8 + header_size
header = json.loads(data[16 : 16 + json_len])


def find_icon(node):
    for name, item in node.get("files", {}).items():
        if "files" in item:
            found = find_icon(item)
            if found:
                return found
        elif name == "icon.png":
            return item
    return None


item = find_icon(header)
if not item:
    raise SystemExit("icon.png not found in app.asar")

offset, size = int(item["offset"]), int(item["size"])
blob = data[base + offset : base + offset + size]
if not blob.startswith(b"\x89PNG\r\n\x1a\n"):
    raise SystemExit("extracted payload is not a PNG")

with open(out, "wb") as handle:
    handle.write(blob)
