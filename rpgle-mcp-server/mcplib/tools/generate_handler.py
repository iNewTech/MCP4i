#!/usr/bin/env python3
"""Generate a reviewed IBM i MCP wrapper or an editable RPG template.

The JSON manifest is a declaration supplied by the IBM i developer. This
program does not infer a native *PGM interface from its object name. A G-mode
manifest must explicitly confirm the exact by-reference parameter layout.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


OBJECT_NAME = re.compile(r"[A-Z][A-Z0-9_]{0,9}\Z")
JSON_NAME = re.compile(r"[a-z][a-z0-9_]{0,63}\Z")
MAX_PARAMETERS = 32
MAX_INPUTS = 3  # The current ADDMCPTOOL display exposes ARG1..ARG3.
MAX_SCHEMA_BYTES = 2048  # MCPTOOLTPL.SCHEMAJSON is VARCHAR(2048).


class ManifestError(ValueError):
    """The supplied program contract cannot be generated safely."""


def _unique_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ManifestError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"),
                          object_pairs_hook=_unique_keys)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ManifestError(f"cannot read manifest {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ManifestError("manifest must be a JSON object")
    return validate_manifest(data)


def _object(value: Any, label: str) -> dict[str, str]:
    if not isinstance(value, dict):
        raise ManifestError(f"{label} must be an object")
    if set(value) != {"library", "program"}:
        raise ManifestError(f"{label} needs only library and program")
    for field in ("library", "program"):
        name = value[field]
        if not isinstance(name, str) or not OBJECT_NAME.fullmatch(name):
            raise ManifestError(
                f"{label}.{field} must be an uppercase IBM i object name"
            )
    return value


def _positive_int(value: Any, label: str, maximum: int) -> int:
    if type(value) is not int or not 1 <= value <= maximum:
        raise ManifestError(f"{label} must be an integer from 1 to {maximum}")
    return value


def validate_manifest(data: dict[str, Any]) -> dict[str, Any]:
    allowed = {"mode", "handler", "target", "signatureConfirmed",
               "callingConvention", "parameters"}
    unknown = set(data) - allowed
    if unknown:
        raise ManifestError(f"unknown manifest fields: {', '.join(sorted(unknown))}")
    mode = data.get("mode")
    if mode not in ("G", "T"):
        raise ManifestError("mode must be G (generated call) or T (template)")
    _object(data.get("handler"), "handler")
    _object(data.get("target"), "target")
    if data["handler"] == data["target"]:
        raise ManifestError("handler and target must be different *PGM objects")
    if mode == "G":
        if data.get("signatureConfirmed") is not True:
            raise ManifestError("G mode requires signatureConfirmed: true")
        if data.get("callingConvention") != "by_reference":
            raise ManifestError("G mode only supports by_reference native calls")
        if "parameters" not in data:
            raise ManifestError("G mode requires a parameters array, even if empty")
    elif "callingConvention" in data and data["callingConvention"] != "by_reference":
        raise ManifestError("only by_reference calls can be shown in a template")

    params = data.get("parameters", [])
    if not isinstance(params, list) or len(params) > MAX_PARAMETERS:
        raise ManifestError(f"parameters must be an array of at most {MAX_PARAMETERS}")
    seen_native: set[str] = set()
    seen_json: set[str] = set()
    input_count = 0
    for index, param in enumerate(params, 1):
        label = f"parameters[{index}]"
        if not isinstance(param, dict):
            raise ManifestError(f"{label} must be an object")
        extra = set(param) - {"name", "jsonName", "type", "length", "decimals",
                              "direction", "required"}
        if extra:
            raise ManifestError(f"{label} has unknown fields: {', '.join(sorted(extra))}")
        name = param.get("name")
        if not isinstance(name, str) or not OBJECT_NAME.fullmatch(name):
            raise ManifestError(f"{label}.name must be an uppercase IBM i name")
        if name in seen_native:
            raise ManifestError(f"duplicate native parameter name: {name}")
        seen_native.add(name)
        json_name = param.get("jsonName", name.lower())
        if not isinstance(json_name, str) or not JSON_NAME.fullmatch(json_name):
            raise ManifestError(f"{label}.jsonName needs lowercase letters, digits, underscores")
        if json_name in seen_json:
            raise ManifestError(f"duplicate JSON field name: {json_name}")
        seen_json.add(json_name)
        param["jsonName"] = json_name
        kind = param.get("type")
        if kind not in ("char", "int", "packed"):
            raise ManifestError(f"{label}.type must be char, int, or packed")
        direction = param.get("direction")
        if direction not in ("in", "out", "inout"):
            raise ManifestError(f"{label}.direction must be in, out, or inout")
        if kind == "char":
            _positive_int(param.get("length"), f"{label}.length", 1024)
            if "decimals" in param:
                raise ManifestError(f"{label}.decimals applies only to packed")
        elif kind == "int":
            if param.get("length") not in (10, 20) or type(param.get("length")) is not int:
                raise ManifestError(f"{label}.length for int must be 10 or 20")
            if "decimals" in param:
                raise ManifestError(f"{label}.decimals applies only to packed")
        else:
            digits = _positive_int(param.get("length"), f"{label}.length", 31)
            scale = param.get("decimals")
            if type(scale) is not int or not 0 <= scale <= digits:
                raise ManifestError(f"{label}.decimals must be 0..length")
        required = param.get("required", direction != "out")
        if type(required) is not bool:
            raise ManifestError(f"{label}.required must be true or false")
        if direction == "out" and required:
            raise ManifestError(f"{label}.required cannot be true for output-only")
        param["required"] = required
        if direction != "out":
            input_count += 1
    if mode == "G" and input_count > MAX_INPUTS:
        raise ManifestError(
            f"G mode supports at most {MAX_INPUTS} JSON inputs until ADDMCPTOOL "
            "supports more than ARG1..ARG3"
        )
    schema = make_schema(data)
    if len(json.dumps(schema, separators=(",", ":"), ensure_ascii=True).encode()) > MAX_SCHEMA_BYTES:
        raise ManifestError("advertised JSON schema exceeds SCHEMAJSON 2048-byte limit")
    return data


def make_schema(data: dict[str, Any]) -> dict[str, Any]:
    params = data.get("parameters", [])
    types = {"char": "string", "int": "integer", "packed": "number"}
    inputs = [p for p in params if p["direction"] != "out"]
    return {
        "type": "object",
        "properties": {p["jsonName"]: {"type": types[p["type"]]} for p in inputs},
        "required": [p["jsonName"] for p in inputs if p["required"]],
        "additionalProperties": False,
    }


def _native_type(param: dict[str, Any]) -> str:
    kind = param["type"]
    if kind == "char":
        return f"char({param['length']})"
    if kind == "int":
        return f"int({param['length']})"
    return f"packed({param['length']}:{param['decimals']})"


def _sql_type(param: dict[str, Any]) -> str:
    kind = param["type"]
    if kind == "char":
        return "varchar(8192)"
    if kind == "int":
        return "integer" if param["length"] == 10 else "bigint"
    return f"decimal({param['length']},{param['decimals']})"


def _header(data: dict[str, Any]) -> list[str]:
    handler = data["handler"]
    target = data["target"]
    return [
        "**free",
        f"// MCP handler {handler['library']}/{handler['program']}.",
        f"// Native target: {target['library']}/{target['program']}.",
        "// Review the native PI and program authority before publishing.",
        "ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt:*nodebugio);",
        "exec sql set option commit = *none, naming = *sql;",
        "/copy 'MCPABI.rpgleinc'",
        "",
        "dcl-pi *n;",
        "  argsJson char(8192);",
        "  resultJson char(8192);",
        "  resultLen int(10);",
        "  statusCode int(10);",
        "end-pi;",
    ]


def render_generated(data: dict[str, Any]) -> str:
    """Render a G-mode wrapper; every native parameter is passed by reference."""
    params = data["parameters"]
    target = data["target"]
    lines = _header(data)
    lines += [
        "",
        f"dcl-pr nativeCall extpgm('{target['library']}/{target['program']}');",
    ]
    for n, param in enumerate(params, 1):
        lines.append(f"  n{n:03d} {_native_type(param)};")
    lines += ["end-pr;", "", "dcl-s inputJson varchar(8192);",
              "dcl-s payloadJson varchar(4096);", "dcl-s validArgs int(10);",
              "dcl-s knownKeys int(10) inz(0);",
              "dcl-s memberCount int(10);"]
    for n, param in enumerate(params, 1):
        lines.append(f"dcl-s p{n:03d} {_native_type(param)};")
        if param["direction"] != "out":
            lines.append(f"dcl-s has{n:03d} int(10);")
            lines.append(f"dcl-s null{n:03d} int(5);")
            if param["type"] == "char":
                lines.append(f"dcl-s raw{n:03d} varchar(8192);")
    lines += [
        "",
        "clear resultJson;",
        "resultLen = 0;",
        "statusCode = 1;",
        "inputJson = %trim(argsJson);",
        "// A bad JSON envelope must never reach the native program.",
        "exec sql values case",
        "  when :inputJson is json object with unique keys then 1 else 0 end",
        "  into :validArgs;",
        "if sqlcode <> 0 or validArgs <> 1;",
        "  *inlr = *on;",
        "  return;",
        "endif;",
    ]
    for n, param in enumerate(params, 1):
        if param["direction"] == "out":
            continue
        field = param["jsonName"]
        lines += [
            "",
            f"// JSON field {field} maps to native parameter {n}: {param['name']}.",
            "exec sql values case",
            f"  when json_exists(:inputJson, '$.{field}') then 1 else 0 end",
            f"  into :has{n:03d};",
            "if sqlcode <> 0;",
            "  *inlr = *on;",
            "  return;",
            "endif;",
            f"knownKeys += has{n:03d};",
            f"if has{n:03d} = 0;",
        ]
        if param["required"]:
            lines += ["  *inlr = *on;", "  return;"]
        elif param["type"] == "char":
            lines += [
                "  // Optional input is absent: pass a blank native field.",
                f"  p{n:03d} = *blanks;",
            ]
        else:
            lines += [
                "  // Optional input is absent: pass a zero native field.",
                f"  p{n:03d} = 0;",
            ]
        lines += ["else;"]
        destination = f"raw{n:03d}" if param["type"] == "char" else f"p{n:03d}"
        lines += [
            "  exec sql values json_value(",
            f"    :inputJson, 'strict $.{field}'",
            f"    returning {_sql_type(param)} error on empty error on error)",
            f"    into :{destination} :null{n:03d};",
            f"  if sqlcode <> 0 or null{n:03d} < 0;",
            "    *inlr = *on;",
            "    return;",
            "  endif;",
        ]
        if param["type"] == "char":
            lines += [
                f"  if %len(raw{n:03d}) > {param['length']};",
                "    *inlr = *on;",
                "    return;",
                "  endif;",
                f"  p{n:03d} = raw{n:03d};",
            ]
        lines += ["endif;"]
    lines += [
        "",
        "// Reject extra top-level keys before calling the native program.",
        "// The wildcard selects every object member; unique keys were checked.",
        "exec sql select count(*) into :memberCount",
        "  from json_table(:inputJson, '$.*'",
        "    columns (seq for ordinality)) as jt;",
        "if sqlcode <> 0 or memberCount <> knownKeys;",
        "  *inlr = *on;",
        "  return;",
        "endif;",
    ]
    call_args = " : ".join(f"p{n:03d}" for n in range(1, len(params) + 1))
    lines += [
        "",
        "// The native target is invoked only after all inputs were checked.",
        "monitor;",
        f"  nativeCall({call_args});",
        "on-error;",
        "  *inlr = *on;",
        "  return;",
        "endmon;",
        "",
    ]
    outputs = [(n, p) for n, p in enumerate(params, 1)
               if p["direction"] != "in"]
    if outputs:
        lines += ["exec sql values json_object("]
        for i, (n, param) in enumerate(outputs):
            value = (f"rtrim(:p{n:03d})" if param["type"] == "char"
                     else f":p{n:03d}")
            suffix = "," if i < len(outputs) - 1 else ""
            lines.append(f"  '{param['jsonName']}' value {value}{suffix}")
        lines += ["  returning varchar(4096)) into :payloadJson;"]
    else:
        lines += [
            "exec sql values json_object('status' value 'ok'",
            "  returning varchar(4096)) into :payloadJson;",
        ]
    lines += [
        "if sqlcode <> 0 or payloadJson = '';",
        "  *inlr = *on;",
        "  return;",
        "endif;",
        "resultJson = payloadJson;",
        "resultLen = %len(payloadJson);",
        "statusCode = 0;",
        "*inlr = *on;",
        "return;",
    ]
    return "\n".join(lines) + "\n"


def render_template(data: dict[str, Any]) -> str:
    """Render a compilable but intentionally failing handler skeleton."""
    params = data.get("parameters", [])
    target = data["target"]
    lines = _header(data)
    lines += [
        "",
        "// TODO: Confirm the target program's exact by-reference PI.",
        "// TODO: Move the reviewed prototype into live declarations.",
        f"// dcl-pr nativeCall extpgm('{target['library']}/{target['program']}');",
    ]
    for n, param in enumerate(params, 1):
        lines.append(f"//   n{n:03d} {_native_type(param)}; // {param['name']}")
    call_args = " : ".join(f"p{n:03d}" for n in range(1, len(params) + 1))
    lines += [
        "// end-pr;",
        "",
        "// TODO: Validate argsJson and map each JSON input to native storage.",
        "// TODO: Declare p001, p002, ... with the confirmed native types.",
        "// TODO: Add a monitored call with the exact parameter order:",
        f"// nativeCall({call_args});",
        "// TODO: Serialize outputs as JSON and set statusCode = 0 only",
        "//       after the call and response mapping succeed.",
        "clear resultJson;",
        "resultLen = 0;",
        "statusCode = 1; // This template never calls the native program.",
        "*inlr = *on;",
        "return;",
    ]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path,
                        help="IFS .sqlrpgle source file for the MCP handler")
    parser.add_argument("--schema-out", type=Path,
                        help="JSON schema sidecar (default: output stem + .schema.json)")
    parser.add_argument("--force", action="store_true",
                        help="replace existing generated files")
    args = parser.parse_args(argv)
    try:
        data = load_manifest(args.manifest)
        if args.output.suffix.lower() != ".sqlrpgle":
            raise ManifestError("--output must end in .sqlrpgle")
        if args.output.stem.upper() != data["handler"]["program"]:
            raise ManifestError("output basename must match handler.program")
        schema_out = args.schema_out or args.output.with_suffix(".schema.json")
        if len({args.manifest.resolve(), args.output.resolve(), schema_out.resolve()}) != 3:
            raise ManifestError("manifest, source, and schema paths must differ")
        if not args.force and (args.output.exists() or schema_out.exists()):
            raise ManifestError("output exists; use --force to replace generated files")
        source = (render_generated(data) if data["mode"] == "G"
                  else render_template(data))
        schema = json.dumps(make_schema(data), indent=2, ensure_ascii=True) + "\n"
        args.output.parent.mkdir(parents=True, exist_ok=True)
        schema_out.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(source, encoding="utf-8")
        schema_out.write_text(schema, encoding="utf-8")
        print(f"RPG source: {args.output}")
        print(f"Tool input schema: {schema_out}")
        if data["mode"] == "T":
            print("Template has no live target call; finish and review it before publishing.")
        else:
            print("Match ADDMCPTOOL arguments to the schema, compile, test, then publish.")
        return 0
    except (ManifestError, OSError) as exc:
        print(f"generate_handler: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
