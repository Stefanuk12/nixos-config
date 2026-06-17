#!/usr/bin/env python3
"""Render a config.plist by parsing a base plist and applying overrides.

Inputs (positional argv):
  1. base_plist         — plist file (XML or binary); default Sample.plist.
  2. structured_json    — high-level overrides handled by `apply_*` below.
  3. plist_overrides    — arbitrary nested overrides deep-merged onto the
                          parsed plist *after* structured ops. Tagged dicts
                          encode plist scalars JSON can't:
                            {"_type": "data", "value": "<base64>"}
                            {"_type": "date", "value": "<iso8601>"}
  4. output             — destination path for the rendered XML plist.

Both JSON files may be empty (`{}`); structured ops and the deep merge are
independent. Override keys left absent leave the base plist's defaults intact.
"""

import base64
import json
import plistlib
import sys
from datetime import datetime


def encode_mac_to_bytes(mac: str) -> bytes:
    return bytes(int(b, 16) for b in mac.split(":"))


def apply_smbios(plist: dict, smbios: dict) -> None:
    """Write into PlatformInfo.Generic. Keys: productName, serial, mlb,
    uuid, romMac (XX:XX:XX:XX:XX:XX → 6 bytes for ROM)."""
    generic = plist.setdefault("PlatformInfo", {}).setdefault("Generic", {})
    if "productName" in smbios:
        generic["SystemProductName"] = smbios["productName"]
    if "serial" in smbios:
        generic["SystemSerialNumber"] = smbios["serial"]
    if "mlb" in smbios:
        generic["MLB"] = smbios["mlb"]
    if "uuid" in smbios:
        generic["SystemUUID"] = smbios["uuid"]
    if "romMac" in smbios:
        generic["ROM"] = encode_mac_to_bytes(smbios["romMac"])


def apply_drivers(plist: dict, drivers: list) -> None:
    """Replace UEFI.Drivers wholesale (one entry per filename, upstream
    defaults) so it matches what we ship in EFI/OC/Drivers/ and avoids
    OpenCore missing/extra-driver warnings.

    Side effect: if OpenCanopy.efi is present, force Misc.Boot.PickerMode =
    "External" — OC only routes to OpenCanopy's graphical picker in that mode,
    and ocvalidate (≥ 1.0.7) errors on the Builtin default. Override via
    plistOverrides (deep-merge runs after and wins)."""
    uefi = plist.setdefault("UEFI", {})
    uefi["Drivers"] = [
        {
            "Arguments": "",
            "Comment":   "",
            "Enabled":   True,
            "LoadEarly": False,
            "Path":      d,
        }
        for d in drivers
    ]
    if any(d.lower() == "opencanopy.efi" for d in drivers):
        plist.setdefault("Misc", {}).setdefault("Boot", {})["PickerMode"] = "External"


def apply_acpi(plist: dict, entries: list) -> None:
    """Replace ACPI.Add wholesale (entry: name relative to EFI/OC/ACPI/,
    comment?). Sample.plist's demo .aml entries don't exist in our tree, so a
    wholesale replace avoids OpenCore missing-file warnings on boot."""
    acpi = plist.setdefault("ACPI", {})
    acpi["Add"] = [
        {
            "Comment": e.get("comment", e["name"]),
            "Enabled": True,
            "Path": e["name"],
        }
        for e in entries
    ]


def apply_kexts(plist: dict, kexts: list) -> None:
    """Replace Kernel.Add wholesale. Each entry: bundlePath (required),
    executablePath?, minKernel?, maxKernel?, arch?, plistPath?, comment?."""
    kernel = plist.setdefault("Kernel", {})
    kernel["Add"] = [
        {
            "Arch": k.get("arch", "Any"),
            "BundlePath": k["bundlePath"],
            "Comment": k.get("comment", k["bundlePath"]),
            "Enabled": True,
            "ExecutablePath": k.get("executablePath", ""),
            "MaxKernel": k.get("maxKernel", ""),
            "MinKernel": k.get("minKernel", ""),
            "PlistPath": k.get("plistPath", "Contents/Info.plist"),
        }
        for k in kexts
    ]


def apply_kext_blocks(plist: dict, blocks: list) -> None:
    """Merge into Kernel.Block by Identifier — same id replaces, new ones
    append, untouched entries from the base plist survive."""
    kernel = plist.setdefault("Kernel", {})
    existing = kernel.get("Block", [])
    by_id = {b.get("Identifier"): b for b in existing}
    for blk in blocks:
        identifier = blk["identifier"]
        merged = by_id.get(identifier, {
            "Arch": "Any",
            "Comment": "",
            "Enabled": False,
            "Identifier": identifier,
            "MaxKernel": "",
            "MinKernel": "",
            "Strategy": "Disable",
        })
        if "enabled" in blk:
            merged["Enabled"] = blk["enabled"]
        for src, dst in [
            ("comment",   "Comment"),
            ("strategy",  "Strategy"),
            ("minKernel", "MinKernel"),
            ("maxKernel", "MaxKernel"),
            ("arch",      "Arch"),
        ]:
            if src in blk:
                merged[dst] = blk[src]
        merged["Identifier"] = identifier
        by_id[identifier] = merged
    kernel["Block"] = list(by_id.values())


def apply_nvram_add(plist: dict, *, boot_args: str | None, csr: str | None) -> None:
    """Set boot-args and csr-active-config under the Apple boot-args GUID.
    `csr` is a hex string (e.g. "00000000") so the user can paste a
    canonical SIP value. Both are written in-place — other entries under
    the GUID survive."""
    if boot_args is None and csr is None:
        return
    add = plist.setdefault("NVRAM", {}).setdefault("Add", {})
    apple_guid = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
    bucket = add.setdefault(apple_guid, {})
    if boot_args is not None:
        bucket["boot-args"] = boot_args
    if csr is not None:
        bucket["csr-active-config"] = bytes.fromhex(csr)


def decode_value(v):
    """Recursively turn JSON-encoded plistOverride values into plist-native
    types. Tagged dicts ({"_type": "data"|"date", "value": ...}) become
    bytes / datetime; everything else round-trips."""
    if isinstance(v, dict):
        if "_type" in v:
            tag = v["_type"]
            val = v.get("value")
            if tag == "data":
                return base64.b64decode(val)
            if tag == "date":
                return datetime.fromisoformat(val)
            raise ValueError(f"unknown _type tag in plistOverrides: {tag!r}")
        return {k: decode_value(val) for k, val in v.items()}
    if isinstance(v, list):
        return [decode_value(x) for x in v]
    return v


def deep_merge(base, override):
    """Recursively merge override into base. Only dicts merge by key —
    lists, scalars, and type mismatches replace wholesale (the override
    wins). Returns a new structure; `base` is not mutated."""
    if not isinstance(base, dict) or not isinstance(override, dict):
        return override
    out = dict(base)
    for k, v in override.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def main() -> None:
    base_path, structured_path, overrides_path, out_path = sys.argv[1:5]
    with open(base_path, "rb") as f:
        plist = plistlib.load(f)
    with open(structured_path) as f:
        structured = json.load(f)
    with open(overrides_path) as f:
        overrides = json.load(f)

    if "smbios" in structured:
        apply_smbios(plist, structured["smbios"])
    if "kexts" in structured:
        apply_kexts(plist, structured["kexts"])
    if "kextBlocks" in structured:
        apply_kext_blocks(plist, structured["kextBlocks"])
    if "acpi" in structured:
        apply_acpi(plist, structured["acpi"])
    if "drivers" in structured:
        apply_drivers(plist, structured["drivers"])
    apply_nvram_add(
        plist,
        boot_args=structured.get("bootArgs"),
        csr=structured.get("csrActiveConfig"),
    )

    if overrides:
        plist = deep_merge(plist, decode_value(overrides))

    with open(out_path, "wb") as f:
        plistlib.dump(plist, f, sort_keys=False)


if __name__ == "__main__":
    main()
