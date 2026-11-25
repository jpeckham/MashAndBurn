# Mash & Burn — playable prototype

Godot 4.4.1 Mono is installed at `C:\Program Files\Godot\Godot_v4.4.1-stable_mono_win64_console.exe` (reported `4.4.1.stable.mono.official.49a5bc7b6`). GDScript requires no .NET SDK. Python 3.11.9 is available at `C:\Users\james\AppData\Local\Programs\Python\Python311\python.exe`; it is optional and not the simulation runtime. No packages or setup install is required.

PowerShell commands (replace the executable path if installed elsewhere):

```powershell
& 'C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe' --path .
& 'C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe' --headless --path . --script tests/run_all.gd -- --suite chemistry
& 'C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe' --headless --path . --script tests/run_all.gd -- --suite contracts
```

See [architecture and approximation limits](docs/architecture.md) and [protocol](src/contracts/README.md). The engine normally writes logs to its local application-data folder; restricted environments must allow that folder or supply `--log-file` pointing to a writable file.
