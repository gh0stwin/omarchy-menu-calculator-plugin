import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "file:///usr/share/omarchy/shell/services/AppSearch.js" as AppSearch

// Stand-in for the shell's own AppLibrary, for when the host does not hand one
// over. Omarchy 4.0.0–4.0.2 (everything before v4.0.3) build a scoped `shell`
// object for third-party plugins and leave `appLibrary` null on it, so
// `Upstream.Menu.mergeAppRows()` returns before it adds a single row: no
// applications in the Apps submenu and none in search, with nothing logged to
// say why. A menu without its applications is not the menu, so this rebuilds
// that capability out of the pieces a plugin *can* reach. From v4.0.3 the host
// hands third-party menu plugins a working app library, so there the swap
// stands aside and this shim sits dormant.
//
// DesktopEntries is a Quickshell singleton and is readable from here directly.
// Everything else is deliberately the shell's own: AppSearch.js for identical
// ranking, hidden-entries.sh for the same NoDisplay/OnlyShowIn/NotShowIn
// filtering, and launcher.hides for the same user hides. The one thing not
// reproduced is the "Launching…" OSD, which needs host-only state — a caveat
// only where this shim runs (before v4.0.3): there no OSD appears on launch,
// while from v4.0.3 the launch goes through the host facade and the OSD
// appears. Either way the launch itself is the same gtk-launch call the shell
// makes.
Item {
    id: shim

    width: 0
    height: 0
    visible: false

    property string omarchyPath: Quickshell.env("OMARCHY_PATH")

    property var configuredHiddenEntryIds: ({})
    property var desktopHiddenEntryIds: ({})

    // Maps an icon name to a file on disk. Qt's themed lookup misses icons
    // installed after this process started, because its icon cache never
    // re-scans, so the menu would show a blank square for anything installed
    // since login without this.
    property var iconIndex: ({})
    property var pendingIconIndex: ({})

    signal appsChanged()

    function entryName(entry) {
        return AppSearch.entryName(entry)
    }

    function entrySubtext(entry) {
        return AppSearch.entrySubtext(entry)
    }

    function isHiddenEntry(entry) {
        var id = String((entry && entry.id) || "")
        return shim.configuredHiddenEntryIds[id] === true || shim.desktopHiddenEntryIds[id] === true
    }

    function sortedEntries(query) {
        var values = DesktopEntries.applications.values || []
        return AppSearch.sortedEntries(values, query, function (entry) {
            return shim.isHiddenEntry(entry)
        })
    }

    function iconSource(icon) {
        var value = String(icon || "")
        if (value.length === 0)
            return Quickshell.iconPath("application-x-executable", true)
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0)
            return value
        if (value.charAt(0) === "/")
            return Util.fileUrl(value)
        // Prefer the context-limited app/device index. An unconstrained themed
        // lookup can resolve an app name such as "zoom" to an action icon.
        var found = shim.iconIndex[value]
        if (found)
            return Util.fileUrl(found)
        var themed = Quickshell.iconPath(value, true)
        if (themed.length > 0)
            return themed
        return Quickshell.iconPath("application-x-executable", true)
    }

    function refreshIcons() {
        if (!iconIndexScan.running)
            iconIndexScan.running = true
    }

    function launch(desktopId, name) {
        var id = String(desktopId || "")
        if (!id)
            return
        // Start gtk-launch inside a scope under app-graphical.slice so apps do
        // not inherit wayland-wm@.service. Keep the .desktop suffix or ids like
        // org.telegram.desktop will not resolve.
        Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(id + ".desktop"))
    }

    function remove(desktopId, name) {
        var id = String(desktopId || "")
        if (!id)
            return
        Util.execDetached(Util.shellQuote(shim.omarchyPath + "/bin/omarchy-remove-launcher-entry")
            + " " + Util.shellQuote(id) + " " + Util.shellQuote(String(name || id)))
    }

    function normalizeDesktopId(id) {
        var value = String(id || "").trim()
        if (value.slice(-8) === ".desktop")
            value = value.slice(0, -8)
        return value
    }

    function idSetFromLines(rawText) {
        var next = ({})
        var lines = String(rawText || "").split(/\n/)
        for (var i = 0; i < lines.length; i++) {
            var id = shim.normalizeDesktopId(lines[i])
            if (id.length > 0)
                next[id] = true
        }
        return next
    }

    function loadConfiguredHides(rawText) {
        shim.configuredHiddenEntryIds = shim.idSetFromLines(rawText)
        shim.appsChanged()
    }

    function loadDesktopHiddenEntries(rawText) {
        shim.desktopHiddenEntryIds = shim.idSetFromLines(rawText)
        shim.appsChanged()
    }

    function iconIndexScanCommand() {
        // List app/device icons across the XDG icon dirs and /usr/share/pixmaps
        // as "<path>" lines. Some desktop entries, such as Print Settings, use
        // device icons like "printer" instead of app icons. SVGs are emitted
        // before PNGs so the parser, which keeps the first hit per name,
        // prefers scalable icons.
        return [
            'dirs="$HOME/.icons $HOME/.local/share/icons";',
            'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
            'for ext in svg png; do',
            '  for base in $dirs; do',
            '    [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) -name "*.$ext" 2>/dev/null;',
            '  done;',
            '  find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null;',
            'done'
        ].join(' ')
    }

    function indexIconLine(path) {
        var value = String(path || "").trim()
        if (value.length === 0)
            return
        var slash = value.lastIndexOf("/")
        var file = slash >= 0 ? value.slice(slash + 1) : value
        var dot = file.lastIndexOf(".")
        var name = dot > 0 ? file.slice(0, dot) : file
        if (name.length > 0 && shim.pendingIconIndex[name] === undefined)
            shim.pendingIconIndex[name] = value
    }

    function hiddenEntryScanCommand() {
        var desktop = [Quickshell.env("XDG_CURRENT_DESKTOP"), Quickshell.env("XDG_SESSION_DESKTOP"), Quickshell.env("DESKTOP_SESSION")].filter(function (v) {
            return String(v || "").length > 0
        }).join(":")
        var script = shim.omarchyPath + "/shell/services/hidden-entries.sh"
        return Util.shellQuote(script) + " " + Util.shellQuote(desktop)
    }

    QtObject {
        id: hiddenEntryOutput
        property string text: ""
    }

    // Both scans must run in non-login shells. A login shell sources the user's
    // profile, and tools like mise touch ~/.local/share on activation — a
    // directory the desktop-entry watcher monitors — so every scan would
    // trigger the next one, pinning a core at idle.
    Process {
        id: hiddenEntryScan
        command: ["bash", "-c", shim.hiddenEntryScanCommand()]
        stdout: SplitParser {
            onRead: function (line) {
                hiddenEntryOutput.text += line + "\n"
            }
        }
        onStarted: hiddenEntryOutput.text = ""
        onExited: shim.loadDesktopHiddenEntries(hiddenEntryOutput.text)
    }

    Process {
        id: iconIndexScan
        command: ["bash", "-c", shim.iconIndexScanCommand()]
        stdout: SplitParser {
            onRead: function (line) {
                shim.indexIconLine(line)
            }
        }
        onStarted: shim.pendingIconIndex = ({})
        // Swapping the property re-evaluates every iconSource() binding, so
        // newly found icons appear without rebuilding the list.
        onExited: shim.iconIndex = shim.pendingIconIndex
    }

    // Coalesces bursts of app-list changes (a package install touches many
    // entries) into a single rescan.
    Timer {
        id: iconIndexDebounce
        interval: 750
        onTriggered: if (!iconIndexScan.running)
            iconIndexScan.running = true
    }

    FileView {
        path: shim.omarchyPath + "/default/omarchy/launcher.hides"
        watchChanges: true
        printErrors: false
        onLoaded: shim.loadConfiguredHides(text())
        onFileChanged: shim.loadConfiguredHides(text())
        onLoadFailed: shim.loadConfiguredHides("")
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            hiddenEntryScan.running = true
            iconIndexDebounce.restart()
            shim.appsChanged()
        }
    }

    Component.onCompleted: {
        hiddenEntryScan.running = true
        iconIndexScan.running = true
    }
}
