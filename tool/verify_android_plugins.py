#!/usr/bin/env python3
"""Check the packaged Flutter Android registrant using only Python's stdlib.

Usage: python tool/verify_android_plugins.py --apk path/to/app-release.apk
Exit codes: 0 = entry point present, 1 = entry point missing, 2 = unreadable APK.
This checks DEX definitions, not reflection strings or device runtime behavior.
"""

import argparse
from functools import lru_cache
from pathlib import Path
import re
import struct
import sys
import zipfile


REGISTRANT = "Lio/flutter/plugins/GeneratedPluginRegistrant;"
PUBLIC_STATIC = 0x0001 | 0x0008


class DexError(ValueError):
    """A DEX structure cannot be safely read."""


class Dex:
    def __init__(self, data):
        self.data = data
        self.require(0, 112)
        if not re.fullmatch(rb"dex\n0(?:35|37|38|39|40)\x00", data[:8]):
            raise DexError("unsupported or invalid DEX magic/version")
        if self.u32(32) != len(data) or self.u32(36) != 112:
            raise DexError("DEX header size does not match its data")
        if self.u32(40) != 0x12345678:
            raise DexError("unsupported DEX byte order")
        self.strings = self.table(56, 4)
        self.types = self.table(64, 4)
        self.protos = self.table(72, 12)
        self.methods = self.table(88, 8)
        self.classes = self.table(96, 32)

    def require(self, offset, size):
        if offset < 0 or size < 0 or offset + size > len(self.data):
            raise DexError("truncated or out-of-bounds DEX structure")

    def u32(self, offset):
        self.require(offset, 4)
        return struct.unpack_from("<I", self.data, offset)[0]

    def table(self, header_offset, item_size):
        count, offset = self.u32(header_offset), self.u32(header_offset + 4)
        self.require(offset, count * item_size)
        return count, offset, item_size

    def item(self, table, index):
        count, offset, size = table
        if not 0 <= index < count:
            raise DexError("invalid DEX table index")
        return offset + index * size

    def uleb(self, offset):
        value = 0
        for shift in range(0, 35, 7):
            self.require(offset, 1)
            byte = self.data[offset]
            offset += 1
            value |= (byte & 0x7F) << shift
            if byte < 0x80:
                if value > 0xFFFFFFFF:
                    raise DexError("invalid DEX ULEB128 value")
                return value, offset
        raise DexError("unterminated DEX ULEB128 value")

    @lru_cache(maxsize=None)
    def string(self, index):
        offset = self.u32(self.item(self.strings, index))
        _, offset = self.uleb(offset)  # UTF-16 length precedes MUTF-8 data.
        end = self.data.find(b"\x00", offset)
        if end < 0:
            raise DexError("unterminated DEX string")
        # Class descriptors/method names used here are ASCII. Other MUTF-8
        # strings need not be decoded exactly to locate this entry point.
        return self.data[offset:end].decode("utf-8", errors="replace")

    def type_name(self, index):
        return self.string(self.u32(self.item(self.types, index)))

    def is_registration_signature(self, proto_index):
        offset = self.item(self.protos, proto_index)
        if self.type_name(self.u32(offset + 4)) != "V":
            return False
        parameters = self.u32(offset + 8)
        if not parameters or self.u32(parameters) != 1:
            return False
        self.require(parameters + 4, 2)
        parameter = struct.unpack_from("<H", self.data, parameters + 4)[0]
        # R8 can rename FlutterEngine; require its single object parameter
        # without requiring the engine's unobfuscated descriptor.
        return self.type_name(parameter).startswith("L")

    def has_registration_method(self, class_index, class_data):
        if not class_data:
            return False
        counts = []
        offset = class_data
        for _ in range(4):
            count, offset = self.uleb(offset)
            counts.append(count)
        for _ in range(counts[0] + counts[1]):
            _, offset = self.uleb(offset)  # field index difference
            _, offset = self.uleb(offset)  # access flags
        for method_count in counts[2:]:
            method_index = 0  # Direct and virtual methods have separate deltas.
            for _ in range(method_count):
                delta, offset = self.uleb(offset)
                access, offset = self.uleb(offset)
                code, offset = self.uleb(offset)
                method_index += delta
                method = self.item(self.methods, method_index)
                owner, proto, name = struct.unpack_from("<HHI", self.data, method)
                if owner != class_index:
                    raise DexError("encoded method belongs to another DEX class")
                if self.string(name) != "registerWith":
                    continue
                if access & PUBLIC_STATIC != PUBLIC_STATIC or not code:
                    continue
                if not self.is_registration_signature(proto):
                    continue
                self.require(code, 16)
                instructions = self.u32(code + 12)
                self.require(code + 16, instructions * 2)
                if instructions:
                    return True
        return False

    def registrant_status(self):
        for index in range(self.classes[0]):
            offset = self.item(self.classes, index)
            class_index = self.u32(offset)
            if self.type_name(class_index) == REGISTRANT:
                valid = self.has_registration_method(class_index, self.u32(offset + 24))
                return True, valid
        return False, False


def verify(apk):
    found_class = False
    with zipfile.ZipFile(apk) as archive:
        dex_names = sorted(
            name for name in archive.namelist()
            if re.fullmatch(r"classes(?:[2-9][0-9]*|1[0-9]+)?\.dex", name)
        )
        for name in dex_names:
            try:
                present, valid = Dex(archive.read(name)).registrant_status()
            except DexError as error:
                raise DexError(f"{name}: {error}") from error
            found_class |= present
            if valid:
                return name
    reason = (
        "has no implemented public static registerWith(object) -> void method"
        if found_class else "is not defined in any classes*.dex"
    )
    print(
        f"FAIL: {apk.name}: io.flutter.plugins.GeneratedPluginRegistrant {reason}.\n"
        "Regenerate Android plugin tooling with a successful Flutter pub get "
        "(use --offline if dependencies are cached), then rebuild the APK. "
        "--no-pub alone will not generate a missing registrant.",
        file=sys.stderr,
    )
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", required=True, type=Path, help="APK to inspect")
    args = parser.parse_args()
    try:
        dex_name = verify(args.apk)
    except (OSError, zipfile.BadZipFile, DexError, RuntimeError) as error:
        print(f"Cannot inspect {args.apk}: {error}", file=sys.stderr)
        return 2
    if dex_name is None:
        return 1
    print(
        f"PASS: {args.apk.name}: GeneratedPluginRegistrant and implemented "
        f"public static registerWith found in {dex_name}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
