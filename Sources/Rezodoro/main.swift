import AppKit

// A plain AppKit entry point: the whole UI is one NSStatusItem plus its
// dropdown (see MenuBarController), so there's no SwiftUI scene to host.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
