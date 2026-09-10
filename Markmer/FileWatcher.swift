import Foundation

/// Watches a single file for writes, renames and deletes (editors commonly save
/// atomically via rename) and calls `onChange` on the main queue, debounced.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var debounce: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.markmer.filewatcher")

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        start()
    }

    deinit { stop() }

    private func start() {
        fd = Foundation.open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .revoke, .attrib],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = src.data
            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                // File was replaced; re-arm on the new inode after the editor finishes.
                self.stop()
                self.queue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.start()
                    self?.scheduleChange()
                }
            } else {
                self.scheduleChange()
            }
        }
        src.setCancelHandler { [fd] in
            if fd >= 0 { Foundation.close(fd) }
        }
        src.resume()
        source = src
    }

    private func stop() {
        source?.cancel()
        source = nil
        fd = -1
    }

    private func scheduleChange() {
        debounce?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, FileManager.default.fileExists(atPath: self.url.path) else { return }
            DispatchQueue.main.async { self.onChange() }
        }
        debounce = item
        queue.asyncAfter(deadline: .now() + 0.15, execute: item)
    }
}
