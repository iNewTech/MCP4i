"""Contract checks for generated wrappers; IBM i compilation is separate."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tools" / "generate_handler.py"
spec = importlib.util.spec_from_file_location("generate_handler", GENERATOR)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def manifest(mode="G"):
    data = {
        "mode": mode,
        "handler": {"library": "MCPLIB", "program": "CUSTLOOK"},
        "target": {"library": "APPLIB", "program": "GETCUST"},
        "parameters": [
            {"name": "CUSTNO", "jsonName": "customer_no", "type": "char",
             "length": 10, "direction": "in", "required": True},
            {"name": "CUSTNAME", "jsonName": "customer_name", "type": "char",
             "length": 50, "direction": "out"},
        ],
    }
    if mode == "G":
        data["signatureConfirmed"] = True
        data["callingConvention"] = "by_reference"
    return data


class GeneratorContractTests(unittest.TestCase):
    def test_generated_wrapper_uses_fixed_abi_and_exact_native_call(self):
        data = module.validate_manifest(manifest())
        source = module.render_generated(data)
        self.assertIn("dcl-pr nativeCall extpgm('APPLIB/GETCUST');", source)
        self.assertIn("nativeCall(p001 : p002);", source)
        self.assertIn("argsJson char(8192);", source)
        self.assertIn("resultJson char(8192);", source)
        self.assertIn("resultLen int(10);", source)
        self.assertIn("statusCode int(10);", source)
        self.assertIn("if %len(raw001) > 10;", source)
        self.assertIn("'customer_name' value rtrim(:p002)", source)
        self.assertLess(source.index("if sqlcode <> 0 or validArgs <> 1;"),
                        source.index("nativeCall(p001 : p002);"))
        self.assertIn("from json_table(:inputJson, '$.*'", source)
        self.assertIn("knownKeys += has001;", source)
        self.assertIn("memberCount <> knownKeys", source)
        self.assertLess(source.index("memberCount <> knownKeys"),
                        source.index("nativeCall(p001 : p002);"))
        self.assertEqual(module.make_schema(data), {
            "type": "object",
            "properties": {"customer_no": {"type": "string"}},
            "required": ["customer_no"],
            "additionalProperties": False,
        })

    def test_template_has_no_executable_target_call(self):
        data = module.validate_manifest(manifest("T"))
        source = module.render_template(data)
        self.assertIn("// dcl-pr nativeCall extpgm('APPLIB/GETCUST');", source)
        self.assertIn("// nativeCall(p001 : p002);", source)
        self.assertNotIn("  nativeCall(", source)
        self.assertIn("statusCode = 1;", source)
        no_signature = manifest("T")
        del no_signature["parameters"]
        self.assertEqual(module.make_schema(module.validate_manifest(no_signature))
                         ["properties"], {})

    def test_rejects_unconfirmed_or_unsupported_layout(self):
        for change in (
            {"signatureConfirmed": False},
            {"callingConvention": "by_value"},
            {"target": {"library": "APPLIB", "program": "GETCUST');DELETE"}},
        ):
            data = manifest()
            data.update(change)
            with self.subTest(change=change), self.assertRaises(module.ManifestError):
                module.validate_manifest(data)

    def test_rejects_more_than_three_advertised_inputs(self):
        data = manifest()
        data["parameters"] = [
            {"name": f"P{i}", "type": "int", "length": 10,
             "direction": "in"} for i in range(4)
        ]
        with self.assertRaisesRegex(module.ManifestError, "ARG1..ARG3"):
            module.validate_manifest(data)

    def test_allows_many_output_only_native_parameters(self):
        data = manifest()
        data["parameters"] += [
            {"name": f"OUT{i}", "type": "packed", "length": 9,
             "decimals": 2, "direction": "out"} for i in range(8)
        ]
        result = module.validate_manifest(data)
        source = module.render_generated(result)
        self.assertIn("dcl-s p010 packed(9:2);", source)
        self.assertNotIn("out7", module.make_schema(result)["properties"])

    def test_no_input_program_still_rejects_extra_keys(self):
        data = manifest()
        data["parameters"] = []
        source = module.render_generated(module.validate_manifest(data))
        self.assertIn("knownKeys int(10) inz(0);", source)
        self.assertIn("memberCount <> knownKeys", source)
        self.assertIn("nativeCall();", source)

    def test_optional_absent_input_has_explicit_native_default(self):
        data = manifest()
        data["parameters"][0]["required"] = False
        source = module.render_generated(module.validate_manifest(data))
        self.assertIn("p001 = *blanks;", source)
        self.assertIn("null001 < 0", source)
        self.assertEqual(module.make_schema(data)["required"], [])

    def test_cli_writes_source_and_schema_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            temp = Path(tmp)
            manifest_path = temp / "tool.json"
            source_path = temp / "CUSTLOOK.sqlrpgle"
            manifest_path.write_text(json.dumps(manifest()), encoding="utf-8")
            command = [sys.executable, str(GENERATOR), "--manifest",
                       str(manifest_path), "--output", str(source_path)]
            first = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertTrue(source_path.exists())
            self.assertEqual(json.loads((temp / "CUSTLOOK.schema.json")
                                        .read_text(encoding="utf-8"))["required"],
                             ["customer_no"])
            second = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(second.returncode, 2)
            self.assertIn("--force", second.stderr)


if __name__ == "__main__":
    unittest.main()
