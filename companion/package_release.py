"""Package tracked companion source and public dependency notices on hosted CI."""
import hashlib
import importlib.metadata
import json
import os
import pathlib
import re
import subprocess
import time
import zipfile

from mash_burn_bridge.models import HardwareFrame


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted":
        raise RuntimeError("Packaging requires a disposable GitHub-hosted runner")
    project = pathlib.Path(__file__).resolve().parent.parent
    source = project / "companion"
    version = os.environ["GITHUB_REF_NAME"][1:] if os.environ.get("GITHUB_REF_TYPE") == "tag" else "0.0." + os.environ["GITHUB_RUN_NUMBER"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a numeric three-part version")
    output = project / "build/companion-release"
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"mash-and-burn-companion-{version}.zip"
    tracked = subprocess.check_output(["git", "ls-files", "-z", "--", "companion"], cwd=project).decode().split("\0")
    committed_at = int(subprocess.check_output(["git", "show", "-s", "--format=%ct", "HEAD"], cwd=project))
    stamp = time.gmtime(committed_at)[:6]
    inventory = []
    packages = []
    prefix = "mash-and-burn-companion/"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        def add(name, data):
            if pathlib.PurePosixPath(name).is_absolute() or ".." in pathlib.PurePosixPath(name).parts:
                raise ValueError("Unsafe archive path")
            info = zipfile.ZipInfo(prefix + name, date_time=stamp)
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(info, data)

        for entry in sorted(filter(None, tracked)):
            file = project / entry
            relative = file.relative_to(source)
            if any(part.startswith(".env") or part in (".tools", "__pycache__", ".pytest_cache", ".venv") for part in relative.parts) or file.suffix == ".pyc" or file.is_symlink():
                continue
            if not file.resolve().is_relative_to(source.resolve()) or not file.is_file():
                raise ValueError("Tracked source escaped companion directory")
            data = file.read_bytes()
            add(relative.as_posix(), data)
            inventory.append(dict(file=relative.as_posix(), sha256=hashlib.sha256(data).hexdigest()))
        for distribution in sorted(importlib.metadata.distributions(), key=lambda item: item.metadata.get("Name", "").lower()):
            name = distribution.metadata.get("Name", "unknown")
            safe_name = re.sub(r"[^A-Za-z0-9_.-]", "_", name)
            notices = []
            for record in distribution.files or []:
                parts = pathlib.PurePosixPath(str(record)).parts
                # Only distribution metadata contains notices. A package such as
                # packaging/licenses is Python implementation code, not a license.
                if ".." in parts or not any(part.endswith(".dist-info") for part in parts) or not ("licenses" in [part.lower() for part in parts] or pathlib.PurePosixPath(str(record)).name.lower() in ("license", "license.txt", "license.md", "copying", "notice", "notice.txt")):
                    continue
                file = pathlib.Path(distribution.locate_file(record))
                if file.is_file() and not file.is_symlink():
                    target = "third-party/" + safe_name + "/" + "/".join(parts)
                    add(target, file.read_bytes())
                    notices.append(target)
            packages.append(dict(name=name, version=distribution.version, license=distribution.metadata.get("License-Expression") or distribution.metadata.get("License"), notices=notices))
        metadata = dict(version=version, source_commit=os.environ["GITHUB_SHA"], run_id=os.environ["GITHUB_RUN_ID"], python="3.12", physical_operation=False, files=inventory, validated_environment_packages=packages, distribution="Source only; Python interpreter and dependency implementations are not vendored.")
        add("BUILD-INFO.json", json.dumps(metadata, indent=2).encode())
        add("schema/hardware-frame-v1.json", json.dumps(HardwareFrame.model_json_schema(), indent=2).encode())
    with zipfile.ZipFile(archive) as bundle:
        assert prefix + "mash_burn_bridge/app.py" in bundle.namelist()
        forbidden = [name for name in bundle.namelist() if any(part.startswith(".env") or part in ("__pycache__", ".tools") for part in pathlib.PurePosixPath(name).parts)]
        assert not forbidden, f"Archive contains forbidden paths: {forbidden}"
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "COMPANION-SHA256SUMS.txt").write_text(f"{digest}  {archive.name}\n")
    print(f"COMPANION_PACKAGE version={version} source_files={len(inventory)} environment_packages={len(packages)} sha256={digest}")


if __name__ == "__main__":
    main()
