# Simple Image Viewer Instructions

This is a small SwiftUI macOS app for fast folder-based image viewing.

## Build And Run

After every code or config change, always run the project build/run script before reporting back:

```sh
./script/build_and_run.sh --verify
```

Use the same script for normal local launches:

```sh
./script/build_and_run.sh
```

The runnable app is the SwiftUI target under `Sources/SimpleImageViewer`, built and bundled by `script/build_and_run.sh`.

## Design

- Keep folder discovery, viewer state, image display, and thumbnail UI in separate files.
- Avoid adding external dependencies unless they are clearly needed.
