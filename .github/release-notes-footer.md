## Install

1. Download `Markmer-<version>.zip` below and unzip it.
2. Drag **Markmer.app** into your Applications folder.
3. First launch only: macOS will refuse to open the app because it is not notarized. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**, then confirm. Alternatively, run this once in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Markmer.app
   ```

Markmer is open source and built by GitHub Actions from the tagged commit. Verify the download with the `.sha256` file if you like.
