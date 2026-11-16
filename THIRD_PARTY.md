# Third-party components

| Component | Pinned version | Source / license location |
| --- | --- | --- |
| Godot Engine | 4.4.1 stable | https://github.com/godotengine/godot ; MIT |
| Godot OpenXR Vendors | 4.3.1-stable | https://github.com/GodotVR/godot_openxr_vendors/releases/tag/4.3.1-stable |
| gdtoolkit | 4.3.4 | https://github.com/Scony/godot-gdscript-toolkit ; see package license |
| Gradle wrapper distribution | 8.2 | https://github.com/gradle/gradle-distributions ; Apache-2.0 |

OpenXR Vendors is restored by `tools/bootstrap.py` and is not vendored into Git. The verified upstream archive retains its PICO, Khronos, Meta, Android XR and Magic Leap license files under the installed addon. Vendor SDK licenses apply independently; preserve them in distributions as required. Godot Android export templates and JDK / Android SDK are installed toolchain dependencies, not project source.

The repository does not include debug signing keys, build caches or platform SDK downloads. See `dependencies.lock.json` and `requirements-dev.txt` for the reproducible dependency definitions.
