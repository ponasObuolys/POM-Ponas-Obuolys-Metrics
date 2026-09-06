#!/usr/bin/env python3
"""Validate release metadata and signatures with the pinned Sparkle tooling."""
import base64
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET


def verify(feed, archive, version):
    root = Path(__file__).resolve().parent.parent
    ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    channel = ET.parse(feed).getroot().find("channel")
    if channel is None:
        raise ValueError("Missing appcast channel")
    items = channel.findall("item")
    if len(items) != 1:
        raise ValueError("Expected exactly one release in this feed")
    item = items[0]
    if item.findtext(f"{{{ns}}}version") != version:
        raise ValueError("Appcast version does not match VERSION")
    enclosure = item.find("enclosure")
    expected = f"https://github.com/ponasObuolys/POM-Ponas-Obuolys-Metrics/releases/download/v{version}/{Path(archive).name}"
    if enclosure is None or enclosure.get("url") != expected:
        raise ValueError("Unexpected update download URL")
    if int(enclosure.get("length", "-1")) != Path(archive).stat().st_size:
        raise ValueError("Update length mismatch")
    signature = enclosure.get(f"{{{ns}}}edSignature", "")
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError("Missing or malformed archive signature")
    subprocess.run(["swift", str(root / "scripts/verify-update.swift"),
                    str(root / "config/sparkle-public-key.txt"), str(archive), signature], check=True)
    tool = root / ".build/artifacts/sparkle/Sparkle/bin/sign_update"
    secret = os.environ.get("POM_SPARKLE_PRIVATE_KEY")
    args = [str(tool), "--verify"]
    args += ["--ed-key-file", "-"] if secret else ["--account", "lt.ponasobuolys.pom"]
    for target, suffix in [(feed, []), (archive, [signature])]:
        subprocess.run(args + [str(target)] + suffix, input=secret, text=True, check=True)
    print("Appcast metadata, signed feed and update archive verified.")


if __name__ == "__main__":
    verify(*sys.argv[1:])
