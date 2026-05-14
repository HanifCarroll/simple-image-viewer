# Contributing

Simple Image Viewer is intentionally small. Contributions should keep the app fast, native, and dependency-free.

## Local Development

```sh
./script/build_and_run.sh --verify
```

The verification script builds the app bundle, runs the fixture-based Swift
checks, and launches the app twice to smoke-test opening a selected image and
opening a folder.

## Guidelines

- Keep SwiftUI views focused and split by responsibility.
- Keep file discovery and sorting behavior in `ImageDiscovery.swift`.
- Avoid adding package managers or generated project files unless there is a clear maintenance benefit.
- Test changes with a real folder of images before opening a pull request.
