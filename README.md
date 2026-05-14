# Simple Image Viewer

**Simple Image Viewer** is a small macOS image viewer for quickly moving through a folder of images with the keyboard.

The acronym is **SIV**, pronounced like “sieve.”

## Features

- Open an image and browse the other images in the same folder.
- Open a folder directly.
- Optionally include images from subfolders, with configurable folder-depth and total-photo limits.
- Shows folder scan counts by level before loading a folder.
- Sort loaded images by name, folder, modified date, or file type.
- Filter loaded images by file type or filename text.
- Move through images with left and right arrow keys.
- Shows a horizontal thumbnail rail.
- Plays animated GIFs.
- Uses natural filename order, so `image-10.png` comes after `image-09.png`.
- Supports common image formats including PNG, JPEG, GIF, WebP, TIFF, BMP, HEIC, and HEIF.

## Requirements

- macOS 13 or newer
- Xcode command line tools

## Build And Run

```sh
./script/build_and_run.sh
```

This builds:

```text
dist/Simple Image Viewer.app
```

Open a specific image or folder:

```sh
./script/build_and_run.sh run /path/to/image.png
./script/build_and_run.sh run /path/to/folder
```

When opening a folder from the app UI, Simple Image Viewer shows recursive scan
options inside the native folder picker. Select a folder to preview image counts,
then enable subfolders, choose the maximum depth, and cap the total number of
photos loaded before opening it.

Verify that the app builds and launches:

```sh
./script/build_and_run.sh --verify
```

Verification builds the app bundle, creates a temporary fixture image folder
under `dist/`, compiles and runs a small Swift smoke test for image discovery
and `NSImage` decoding, then launches the app against a real fixture image and
checks that the viewer window opens that image.

## Use As Default Image Viewer

After building once:

1. Right-click a `.png`, `.jpg`, or other image file in Finder.
2. Choose **Get Info**.
3. Under **Open with**, choose `dist/Simple Image Viewer.app`.
4. Click **Change All...** if you want that file type to open with Simple Image Viewer by default.

Repeat per file type if needed.

## Project Structure

```text
Sources/SimpleImageViewer/
  SimpleImageViewerApp.swift        App entry point and keyboard commands
  AppDelegate.swift     macOS launch and open-file handling
  ImageStore.swift      Viewer state and open/navigation actions
  ImageDiscovery.swift  Folder scanning and natural filename order
  ContentView.swift     Main SwiftUI layout
  ThumbnailButton.swift Thumbnail rail item
script/
  build_and_run.sh      Build, bundle, launch, and verify
  verify_image_discovery.swift
                        Lightweight fixture-based verification helper
```

## Development Notes

Simple Image Viewer intentionally uses a small SwiftUI/AppKit surface instead of a generated Xcode project. The build script compiles the Swift sources, creates a `.app` bundle, and writes a minimal `Info.plist`.

No external dependencies are required.

## License

MIT
