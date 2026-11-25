# Distribution inventory

The release workflow installs `licenses/PROJECT_NOTICES.txt`, the exact stable
Godot engine `LICENSE.txt` and its complete `COPYRIGHT.txt` dependency notices.
They accompany the embedded Windows executable in the MSI. This follows the
[Godot 4.4 distribution guidance](https://docs.godotengine.org/en/4.4/about/complying_with_licenses.html).

| Component | Source | Distribution |
| --- | --- | --- |
| Game scripts, shaders and procedural assets | This repository | Embedded in the executable |
| Godot 4.4.1 Windows x64 release template | Official checksum-verified export templates | Engine embedded in executable; MIT and dependency notices installed |
| Default font and engine libraries | Godot release template | Covered by complete upstream copyright/dependency file |
| WiX 4.0.6 and .NET SDK | Hosted build tools | Used to generate MSI; tools are not installed with the game |
| Tests, evidence, docs and fixture launchers | This repository | Excluded from exported game resources |
| Project and upstream notices | Project `licenses/` and matching Godot stable tag | Plain files in installed `licenses/` directory |

There are no downloaded models, music, photographs, textures or separately
bundled fonts. No license is assigned here to the project's original work.
The hosted build publishes `PAYLOAD-SHA256SUMS.txt` for the exact input files
packaged into the MSI, alongside the MSI's `SHA256SUMS.txt`. Installer validation
checks installed file hashes, major upgrade, obsolete-file removal, downgrade
rejection and uninstall. Updates that add assets/plugins must update this inventory.

The optional companion source ZIP includes a locked Python3.12 dependency set,
generated hardware schema, source hashes and public installed-dependency license
notices/metadata in `BUILD-INFO.json` and `third-party/`. It does not vendor Python
or dependency implementations and is separate from the MSI. No physical drivers,
credentials or private configuration are shipped. Packaging excludes `.env`
files, caches, symlinks and runtime evidence.
