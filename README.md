# Simple Image Viewer

**Simple Image Viewer** is a small macOS media viewer for quickly moving through a folder of images and videos with the keyboard.

The acronym is **SIV**, pronounced like “sieve.”

## Features

- Open an image or video and browse the other media files in the same folder.
- Open a folder directly.
- Optionally include media from subfolders, with configurable folder-depth and total-photo limits.
- Shows folder scan counts by level before loading a folder.
- Sort loaded media by name, folder, modified date, or file type.
- Filter loaded media by kind, file type, or filename text.
- Move through media with left and right arrow keys.
- Shows a horizontal thumbnail rail.
- Plays videos with native AVKit controls, cached playback positions, duration badges, and Space for play/pause.
- Plays animated GIFs.
- Uses natural filename order, so `image-10.png` comes after `image-09.png`.
- Supports common image formats including PNG, JPEG, GIF, WebP, TIFF, BMP, HEIC, and HEIF.
- Supports common video formats including MP4, MOV, M4V, AVI, MKV, and WebM when macOS can decode them.

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

Open a specific image, video, or folder:

```sh
./script/build_and_run.sh run /path/to/image.png
./script/build_and_run.sh run /path/to/video.mp4
./script/build_and_run.sh run /path/to/folder
```

When opening a folder from the app UI, Simple Image Viewer shows recursive scan
options inside the native folder picker. Select a folder to preview media counts,
then enable subfolders, choose the maximum depth, and cap the total number of
media files loaded before opening it.

Verify that the app builds and launches:

```sh
./script/build_and_run.sh --verify
```

Verification builds the app bundle, creates a temporary fixture image folder
under `dist/`, compiles and runs a small Swift smoke test for image discovery
opening plans, list projection, recursive folder handling, and `NSImage`
decoding. It then launches the app against a non-first fixture image, checks
that the viewer selects it, relaunches against the fixture folder, and checks
that the viewer opens the natural first image.

Install the app so it appears in Spotlight:

```sh
./script/install_app.sh
```

By default this copies the built app to `/Applications/Simple Image Viewer.app`.

## Use As Default Image Viewer

After building once:

1. Right-click a `.png`, `.jpg`, or other image file in Finder.
2. Choose **Get Info**.
3. Under **Open with**, choose `dist/Simple Image Viewer.app`.
4. Click **Change All...** if you want that file type to open with Simple Image Viewer by default.

Repeat per file type if needed. Video file types can be assigned the same way.

## Project Structure

```text
Sources/SimpleImageViewer/
  SimpleImageViewerApp.swift        App entry point and keyboard commands
  AppDelegate.swift     macOS launch and open-file handling
  ImageStore.swift      Viewer state and open/navigation actions
  ImageDiscovery.swift  Folder scanning and natural filename order
  ImageOpeningService.swift
                        Open-file and open-folder planning
  ImageListPresentation.swift
                        Sorting and filtering projection for the visible list
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
