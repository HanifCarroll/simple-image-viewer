# Contributing

Simple Image Viewer is intentionally small. Contributions should keep the app fast, native, and dependency-free.

## Local Development

```sh
./script/build_and_run.sh --verify
```

## Guidelines

- Keep SwiftUI views focused and split by responsibility.
- Keep file discovery and sorting behavior in `ImageDiscovery.swift`.
- Avoid adding package managers or generated project files unless there is a clear maintenance benefit.
- Test changes with a real folder of images before opening a pull request.
