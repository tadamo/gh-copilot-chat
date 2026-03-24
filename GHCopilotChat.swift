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

class WindowController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var progressBar: NSProgressIndicator!
    var tabBar: NSSegmentedControl!
    var webViewContainer: NSView!

    var tabs: [Tab] = []
    var activeTabIndex: Int = 0

    var activeTab: Tab { tabs[activeTabIndex] }
    var activeWebView: WKWebView { activeTab.webView }

    func setup() {
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
        window.delegate = self

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

        if isPrivate {
            window.title = "GH Copilot Chat — Private"
        }
        window.makeKeyAndOrderFront(nil)
        newTab(url: URL(string: "https://github.com/copilot")!)
    }

    // MARK: - Tab Management

    var isPrivate = false

    private func makeWebViewConfig() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        if isPrivate {
            config.websiteDataStore = .nonPersistent()
        }
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

    @objc func tabSelected() { switchTab(to: tabBar.selectedSegment) }

    func selectPreviousTab() {
        switchTab(to: (activeTabIndex - 1 + tabs.count) % tabs.count)
    }

    func selectNextTab() {
        switchTab(to: (activeTabIndex + 1) % tabs.count)
    }

    // MARK: - Window Actions

    func reload() { activeWebView.reload() }

    func goBack() {
        if activeWebView.canGoBack { activeWebView.goBack() }
    }

    func goForward() {
        if activeWebView.canGoForward { activeWebView.goForward() }
    }

    func zoomIn() {
        activeWebView.pageZoom = min(activeWebView.pageZoom + 0.1, 3.0)
    }

    func zoomOut() {
        activeWebView.pageZoom = max(activeWebView.pageZoom - 0.1, 0.5)
    }

    func zoomReset() {
        activeWebView.pageZoom = 1.0
    }

    func openInBrowser() {
        if let url = activeWebView.url {
            NSWorkspace.shared.open(url)
        }
    }

    func printPage() {
        let printOp = activeWebView.printOperation(with: NSPrintInfo.shared)
        printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    func findInPage() {
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

    func newChatAction() {
        activeWebView.load(URLRequest(url: URL(string: "https://github.com/copilot")!))
    }

    func closeTabAction() { closeTab(at: activeTabIndex) }

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

    private func isCopilotURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString
        let ssoPattern = #"^https://github\.com/(enterprises|orgs)/[^/]+/(sso|saml)"#
        return urlString.hasPrefix("https://github.com/copilot")
            || urlString.hasPrefix("https://github.com/login")
            || urlString.hasPrefix("https://github.com/session")
            || urlString.range(of: ssoPattern, options: .regularExpression) != nil
            || urlString.hasPrefix("https://login.microsoftonline.com/")
            || urlString.hasPrefix("https://autologon.microsoftazuread-sso.com/")
            || urlString.range(of: #"^https://[^/]+\.duosecurity\.com/"#, options: .regularExpression) != nil
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           !isCopilotURL(url) {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if isCopilotURL(url) {
                let tab = newTab(url: url)
                return tab.webView
            }
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    // MARK: - Window Delegate

    func windowWillClose(_ notification: Notification) {
        (NSApp.delegate as? AppDelegate)?.removeWindowController(self)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var windowControllers: [WindowController] = []

    var windowMenu: NSMenu!
    var tabSectionSeparator: NSMenuItem!
    var prevTabMenuItem: NSMenuItem!
    var nextTabMenuItem: NSMenuItem!
    var tabListSeparator: NSMenuItem!
    var tabNumberItems: [NSMenuItem] = []

    var activeWindowController: WindowController? {
        let keyWindow = NSApp.keyWindow ?? NSApp.mainWindow
        return windowControllers.first { $0.window === keyWindow }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        createNewWindow()
    }

    @discardableResult
    func createNewWindow() -> WindowController {
        let wc = WindowController()
        wc.setup()
        windowControllers.append(wc)
        return wc
    }

    @discardableResult
    func createNewPrivateWindow() -> WindowController {
        let wc = WindowController()
        wc.isPrivate = true
        wc.setup()
        windowControllers.append(wc)
        return wc
    }

    func removeWindowController(_ wc: WindowController) {
        windowControllers.removeAll { $0 === wc }
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
        fileMenu.addItem(NSMenuItem(title: "New Window", action: #selector(newWindowAction), keyEquivalent: "n"))
        let newPrivateWindowItem = NSMenuItem(title: "New Private Window", action: #selector(newPrivateWindowAction), keyEquivalent: "p")
        newPrivateWindowItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(newPrivateWindowItem)
        fileMenu.addItem(NSMenuItem(title: "New Tab", action: #selector(newTabAction), keyEquivalent: "t"))
        let newChatItem = NSMenuItem(title: "New Chat", action: #selector(newChatAction), keyEquivalent: "n")
        newChatItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(newChatItem)
        fileMenu.addItem(NSMenuItem(title: "Close Tab", action: #selector(closeTabAction), keyEquivalent: "w"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Print...", action: #selector(printPage), keyEquivalent: "p"))
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

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
        tabSectionSeparator = NSMenuItem.separator()
        windowMenu.addItem(tabSectionSeparator)
        prevTabMenuItem = NSMenuItem(title: "Show Previous Tab", action: #selector(selectPreviousTab), keyEquivalent: "{")
        prevTabMenuItem.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(prevTabMenuItem)
        nextTabMenuItem = NSMenuItem(title: "Show Next Tab", action: #selector(selectNextTab), keyEquivalent: "}")
        nextTabMenuItem.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(nextTabMenuItem)
        tabListSeparator = NSMenuItem.separator()
        windowMenu.addItem(tabListSeparator)
        for i in 1...9 {
            let item = NSMenuItem(title: "Tab \(i)", action: #selector(selectTabByNumber(_:)), keyEquivalent: "\(i)")
            item.tag = i - 1
            windowMenu.addItem(item)
            tabNumberItems.append(item)
        }
        self.windowMenu = windowMenu
        windowMenu.delegate = self
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Delegate

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === windowMenu else { return }
        let tabCount = activeWindowController?.tabs.count ?? 0
        let hasWindow = tabCount > 0
        tabSectionSeparator.isHidden = !hasWindow
        prevTabMenuItem.isHidden = !hasWindow
        nextTabMenuItem.isHidden = !hasWindow
        tabListSeparator.isHidden = !hasWindow
        for (i, item) in tabNumberItems.enumerated() {
            item.isHidden = i >= tabCount
        }
    }

    // MARK: - Actions

    @objc func newWindowAction() {
        createNewWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func newPrivateWindowAction() {
        createNewPrivateWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func newTabAction() { activeWindowController?.newTab() }

    @objc func newChatAction() { activeWindowController?.newChatAction() }

    @objc func closeTabAction() { activeWindowController?.closeTabAction() }

    @objc func reload() { activeWindowController?.reload() }

    @objc func goBack() { activeWindowController?.goBack() }

    @objc func goForward() { activeWindowController?.goForward() }

    @objc func zoomIn() { activeWindowController?.zoomIn() }

    @objc func zoomOut() { activeWindowController?.zoomOut() }

    @objc func zoomReset() { activeWindowController?.zoomReset() }

    @objc func openInBrowser() { activeWindowController?.openInBrowser() }

    @objc func printPage() { activeWindowController?.printPage() }

    @objc func findInPage() { activeWindowController?.findInPage() }

    @objc func selectPreviousTab() { activeWindowController?.selectPreviousTab() }

    @objc func selectNextTab() { activeWindowController?.selectNextTab() }

    @objc func selectTabByNumber(_ sender: NSMenuItem) {
        activeWindowController?.switchTab(to: sender.tag)
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "GH Copilot Chat",
            .version: "1.0",
            .credits: NSAttributedString(string: "A native Mac wrapper for GitHub Copilot chat.")
        ])
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            createNewWindow()
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
