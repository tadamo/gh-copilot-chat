import AppKit
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var progressBar: NSProgressIndicator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        setupWindow()
        loadCopilot()
    }

    // MARK: - Menu

    func setupMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About GH Copilot Chat", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit GH Copilot Chat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        // Edit menu
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Find...", action: #selector(findInPage), keyEquivalent: "f"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        // View menu
        let viewItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Reload", action: #selector(reload), keyEquivalent: "r"))
        viewMenu.addItem(.separator())
        viewMenu.addItem(NSMenuItem(title: "Zoom In", action: #selector(zoomIn), keyEquivalent: "+"))
        viewMenu.addItem(NSMenuItem(title: "Zoom Out", action: #selector(zoomOut), keyEquivalent: "-"))
        viewMenu.addItem(NSMenuItem(title: "Actual Size", action: #selector(zoomReset), keyEquivalent: "0"))
        viewMenu.addItem(.separator())
        viewMenu.addItem(NSMenuItem(title: "Open in Browser", action: #selector(openInBrowser), keyEquivalent: "o"))
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        // History menu
        let historyItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        let historyMenu = NSMenu(title: "History")
        historyMenu.addItem(NSMenuItem(title: "Back", action: #selector(goBack), keyEquivalent: "["))
        historyMenu.addItem(NSMenuItem(title: "Forward", action: #selector(goForward), keyEquivalent: "]"))
        historyItem.submenu = historyMenu
        mainMenu.addItem(historyItem)

        // Window menu
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        // File menu (for Print)
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Print...", action: #selector(printPage), keyEquivalent: "p"))
        fileItem.submenu = fileMenu
        mainMenu.insertItem(fileItem, at: 1)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Window

    func setupWindow() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        // Progress bar
        progressBar = NSProgressIndicator()
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true

        // Container view so we can overlay the progress bar at the top
        let container = NSView()
        container.addSubview(webView)
        container.addSubview(progressBar)

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            progressBar.topAnchor.constraint(equalTo: container.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 3),
        ])

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let windowRect = NSRect(
            x: screen.midX - 525,
            y: screen.midY - 400,
            width: 1050,
            height: 800
        )

        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "GH Copilot Chat"
        window.contentView = container
        window.setFrameAutosaveName("GHCopilotChatWindow")
        window.makeKeyAndOrderFront(nil)
    }

    func loadCopilot() {
        let url = URL(string: "https://github.com/copilot")!
        webView.load(URLRequest(url: url))
    }

    // MARK: - Actions

    @objc func reload() {
        webView.reload()
    }

    @objc func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    @objc func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    @objc func zoomIn() {
        webView.pageZoom = min(webView.pageZoom + 0.1, 3.0)
    }

    @objc func zoomOut() {
        webView.pageZoom = max(webView.pageZoom - 0.1, 0.5)
    }

    @objc func zoomReset() {
        webView.pageZoom = 1.0
    }

    @objc func openInBrowser() {
        if let url = webView.url {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "GH Copilot Chat",
            .version: "1.0",
            .credits: NSAttributedString(string: "A native Mac wrapper for GitHub Copilot chat.")
        ])
    }

    @objc func printPage() {
        let printOp = webView.printOperation(with: NSPrintInfo.shared)
        printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    @objc func findInPage() {
        // Forward Cmd+F into the webview via the responder chain
        window.makeFirstResponder(webView)
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "f",
            charactersIgnoringModifiers: "f",
            isARepeat: false,
            keyCode: 3
        )
        if let event { webView.keyDown(with: event) }
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case #keyPath(WKWebView.title):
            if let title = webView.title, !title.isEmpty {
                window.title = title
            }
        case #keyPath(WKWebView.estimatedProgress):
            let progress = webView.estimatedProgress
            progressBar.doubleValue = progress
            progressBar.isHidden = progress >= 1.0
        default:
            break
        }
    }

    // MARK: - Navigation delegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           navigationAction.navigationType == .linkActivated {
            let host = url.host ?? ""
            if !host.contains("github.com") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
