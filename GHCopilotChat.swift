import AppKit
import WebKit

class Tab {
    let webView: WKWebView
    var title: String = "New Tab"

    init(configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var progressBar: NSProgressIndicator!
    var tabBar: NSSegmentedControl!
    var webViewContainer: NSView!

    var tabs: [Tab] = []
    var activeTabIndex: Int = 0

    var activeTab: Tab { tabs[activeTabIndex] }
    var activeWebView: WKWebView { activeTab.webView }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        setupWindow()
        newTab(url: URL(string: "https://github.com/copilot")!)
    }

    // MARK: - Menu

    func setupMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About GH Copilot Chat", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide GH Copilot Chat", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit GH Copilot Chat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        // File menu
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New Window", action: #selector(showWindow), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem(title: "New Tab", action: #selector(newTabAction), keyEquivalent: "t"))
        let newChatItem = NSMenuItem(title: "New Chat", action: #selector(newChatAction), keyEquivalent: "n")
        newChatItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(newChatItem)
        fileMenu.addItem(NSMenuItem(title: "Close Tab", action: #selector(closeTabAction), keyEquivalent: "w"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Print...", action: #selector(printPage), keyEquivalent: "p"))
        fileItem.submenu = fileMenu
        mainMenu.insertItem(fileItem, at: 1)

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
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(.separator())
        let prevTab = NSMenuItem(title: "Show Previous Tab", action: #selector(selectPreviousTab), keyEquivalent: "{")
        prevTab.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(prevTab)
        let nextTab = NSMenuItem(title: "Show Next Tab", action: #selector(selectNextTab), keyEquivalent: "}")
        nextTab.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(nextTab)
        windowMenu.addItem(.separator())
        for i in 1...9 {
            let item = NSMenuItem(title: "Tab \(i)", action: #selector(selectTabByNumber(_:)), keyEquivalent: "\(i)")
            item.tag = i - 1
            windowMenu.addItem(item)
        }
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Window

    func setupWindow() {
        tabBar = NSSegmentedControl()
        tabBar.trackingMode = .selectOne
        tabBar.segmentStyle = .texturedSquare
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.target = self
        tabBar.action = #selector(tabSelected)

        progressBar = NSProgressIndicator()
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 1
        progressBar.doubleValue = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true

        webViewContainer = NSView()
        webViewContainer.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(tabBar)
        container.addSubview(progressBar)
        container.addSubview(webViewContainer)

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
        window.isReleasedWhenClosed = false
        window.contentView = container
        window.setFrameAutosaveName("GHCopilotChatWindow")

        let guide = window.contentLayoutGuide as! NSLayoutGuide
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: guide.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            progressBar.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 3),

            webViewContainer.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            webViewContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webViewContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webViewContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Tab Management

    private func makeWebViewConfig() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        return config
    }

    @discardableResult
    func newTab(url: URL = URL(string: "https://github.com/copilot")!) -> Tab {
        let tab = Tab(configuration: makeWebViewConfig())
        tab.webView.navigationDelegate = self
        tab.webView.uiDelegate = self
        tab.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        tab.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        tabs.append(tab)
        activeTabIndex = tabs.count - 1

        updateTabBar()
        showActiveTab()
        tab.webView.load(URLRequest(url: url))

        return tab
    }

    func closeTab(at index: Int) {
        guard tabs.count > 1 else {
            window.performClose(nil)
            return
        }

        let tab = tabs[index]
        tab.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        tab.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))

        tabs.remove(at: index)

        if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        } else if activeTabIndex > index {
            activeTabIndex -= 1
        }

        updateTabBar()
        showActiveTab()
    }

    func switchTab(to index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTabIndex = index
        updateTabBar()
        showActiveTab()

        let progress = activeWebView.estimatedProgress
        progressBar.doubleValue = progress
        progressBar.isHidden = progress >= 1.0
    }

    private func showActiveTab() {
        for subview in webViewContainer.subviews {
            subview.removeFromSuperview()
        }

        let wv = activeWebView
        webViewContainer.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
            wv.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor),
        ])

        window.title = activeTab.title
    }

    private func updateTabBar() {
        tabBar.segmentCount = tabs.count
        for (i, tab) in tabs.enumerated() {
            tabBar.setLabel(tab.title, forSegment: i)
            tabBar.setWidth(0, forSegment: i)
        }
        tabBar.selectedSegment = activeTabIndex
    }

    // MARK: - Tab Actions

    @objc func newTabAction() { newTab() }

    @objc func newChatAction() {
        activeWebView.load(URLRequest(url: URL(string: "https://github.com/copilot")!))
    }

    @objc func closeTabAction() { closeTab(at: activeTabIndex) }

    @objc func tabSelected() { switchTab(to: tabBar.selectedSegment) }

    @objc func selectPreviousTab() {
        switchTab(to: (activeTabIndex - 1 + tabs.count) % tabs.count)
    }

    @objc func selectNextTab() {
        switchTab(to: (activeTabIndex + 1) % tabs.count)
    }

    @objc func selectTabByNumber(_ sender: NSMenuItem) {
        switchTab(to: sender.tag)
    }

    // MARK: - Actions

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func reload() { activeWebView.reload() }

    @objc func goBack() {
        if activeWebView.canGoBack { activeWebView.goBack() }
    }

    @objc func goForward() {
        if activeWebView.canGoForward { activeWebView.goForward() }
    }

    @objc func zoomIn() {
        activeWebView.pageZoom = min(activeWebView.pageZoom + 0.1, 3.0)
    }

    @objc func zoomOut() {
        activeWebView.pageZoom = max(activeWebView.pageZoom - 0.1, 0.5)
    }

    @objc func zoomReset() {
        activeWebView.pageZoom = 1.0
    }

    @objc func openInBrowser() {
        if let url = activeWebView.url {
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
        let printOp = activeWebView.printOperation(with: NSPrintInfo.shared)
        printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    @objc func findInPage() {
        window.makeFirstResponder(activeWebView)
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
        if let event { activeWebView.keyDown(with: event) }
    }

    // MARK: - KVO

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let webView = object as? WKWebView,
              let tabIndex = tabs.firstIndex(where: { $0.webView === webView }) else { return }

        switch keyPath {
        case #keyPath(WKWebView.title):
            let title = webView.title?.isEmpty == false ? webView.title! : "New Tab"
            tabs[tabIndex].title = title
            updateTabBar()
            if tabIndex == activeTabIndex {
                window.title = title
            }
        case #keyPath(WKWebView.estimatedProgress):
            if tabIndex == activeTabIndex {
                let progress = webView.estimatedProgress
                progressBar.doubleValue = progress
                progressBar.isHidden = progress >= 1.0
            }
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
            newTab(url: url)
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
