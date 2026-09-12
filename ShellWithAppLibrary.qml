import QtQuick

// The plugin `shell` object, with an appLibrary on it.
//
// `Upstream.Menu` reads its application list through
// `readonly property var appLibrary: root.shell ? root.shell.appLibrary : null`,
// and readonly is readonly: a subclass cannot rebind it. What a subclass *can*
// do is change what `shell` points at, which is what this is for — everything
// the host put on the real object is forwarded straight through, and only
// `appLibrary` is answered locally.
//
// Forwarding is by hand because the host object is a QObject: its members
// cannot be enumerated and copied, so each one is named here. This is the whole
// surface of Omarchy 4.0.3's PluginShellApi. A member added upstream later is
// simply absent here, which is why `realShell` stays reachable.
QtObject {
    id: proxy

    // The object the host handed the plugin. Kept public so anything reaching
    // past this proxy has somewhere to go.
    property var realShell: null
    property var appLibrary: null

    readonly property string pluginId: proxy.realShell ? String(proxy.realShell.pluginId || "") : ""
    readonly property var bar: proxy.realShell ? proxy.realShell.bar : null
    readonly property var barConfig: proxy.realShell ? proxy.realShell.barConfig : ({})
    readonly property var idleConfig: proxy.realShell ? proxy.realShell.idleConfig : ({})

    function serviceFor(id) {
        return proxy.realShell ? proxy.realShell.serviceFor(id) : null
    }

    function firstPartyServiceFor(id) {
        return proxy.realShell ? proxy.realShell.firstPartyServiceFor(id) : null
    }

    function pluginShellForBarEntry(ownerId, moduleName) {
        return proxy.realShell ? proxy.realShell.pluginShellForBarEntry(ownerId, moduleName) : null
    }

    function summon(id, payloadJson) {
        return proxy.realShell ? proxy.realShell.summon(id, payloadJson) : false
    }

    function hide(id) {
        return proxy.realShell ? proxy.realShell.hide(id) : false
    }

    function toggle(id, payloadJson) {
        return proxy.realShell ? proxy.realShell.toggle(id, payloadJson) : false
    }

    function isPluginOpen(id) {
        return proxy.realShell ? proxy.realShell.isPluginOpen(id) : false
    }

    function updateEntryInline(id, settings) {
        return proxy.realShell ? proxy.realShell.updateEntryInline(id, settings) : false
    }

    function mutateShellConfig(mutator) {
        return proxy.realShell ? proxy.realShell.mutateShellConfig(mutator) : false
    }
}
