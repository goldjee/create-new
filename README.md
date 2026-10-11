# Create New

Adds a **Create New…** menu to Finder's right-click menu, like **New** in Windows. If a file with that name already exists, the new one gets a number: `Text document (2).txt`.

You can change the list of file types in the app. Works on Apple Silicon Macs with macOS 13 or later.

## Install

1. Download `CreateNew.dmg` from [Releases](../../releases) and drag **Create New** to **Applications**.
2. The app isn't notarized, so macOS blocks it the first time. To allow it, run:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Create New.app"
   ```
3. Open the app and click **Enable Finder Extension**.

## Templates

New Word, Excel and PowerPoint files start from a blank template. Other files start empty.

To use your own template, click **Templates Folder…** and add a file named `template.<extension>`, for example `template.docx`.

## Build

```bash
./build.sh --test --dmg
```

This builds the app and the DMG into `build/`. You only need the Xcode command line tools.

GitHub Actions builds the DMG on every push. To publish a release, push a tag starting with `v`, for example `v1.0.0`.
