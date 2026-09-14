import QtQuick
import qs.Commons
import "file:///usr/share/omarchy/shell/plugins/menu" as Upstream
import "Calculator.js" as Calculator

// The Omarchy menu, plus one row it does not ship with: open the search with
// '=' and everything after that first character is evaluated as an expression,
// with the answer appearing above the results and the expression under it.
// Enter copies the answer. Without the leading '=' the calculator sleeps and
// the menu is the stock one.
//
// This is the stock menu, not a fork of it — `Upstream.Menu` is the menu that
// ships with Omarchy, and everything below is the calculator bolted onto it.
// The row is a real menu item, injected into the item tree the way the apps
// provider injects applications, so search, keyboard, pointer, and theming
// all treat it like any other row.
Upstream.Menu {
  id: root

  // Omarchy 4.0.3 hands a third-party menu a capability-scoped `shell` whose
  // `appLibrary` is null, and `mergeAppRows()` opens with `if (!root.appLibrary)
  // return` — so a cloned menu silently has no applications at all: nothing in
  // the Apps submenu, nothing in search, and nothing in the journal to say so.
  // The stock menu is unaffected because a first-party plugin is handed the
  // shell itself. Swapping `shell` for a proxy that carries an appLibrary is
  // the only way in from here: `appLibrary` is readonly on the base, but the
  // property it is bound to is not.
  //
  // The swap is conditional, so the day the host starts providing one this
  // stands aside and the plugin goes back to using it.
  onShellChanged: root.adoptAppLibrary()

  function adoptAppLibrary() {
    var incoming = root.shell
    if (!incoming || incoming === shellWithAppLibrary) return
    if (incoming.appLibrary) return

    shellWithAppLibrary.realShell = incoming
    shellWithAppLibrary.appLibrary = appLibraryShim
    // Re-enters onShellChanged, which returns at the identity check above.
    root.shell = shellWithAppLibrary
  }

  AppLibraryShim {
    id: appLibraryShim
  }

  ShellWithAppLibrary {
    id: shellWithAppLibrary
  }

  readonly property string calcRowId: "calc.result"
  // nf-md-calculator, from the same Material glyph range the shipped rows use.
  readonly property string calcIcon: "󰃬"
  // Rows are sorted by score, and score has the item's order added to it.
  // Parking this row far below every real one keeps the answer on top no
  // matter what else the query happens to match.
  readonly property int calcRowOrder: -1000000000

  // Every keystroke lands here before the menu rebuilds its rows, so the row
  // is in the tree by the time the search runs over it.
  onFilterTextChanged: root.syncCalcRow()

  // Drilling into a submenu and back out re-runs the same sync: the row is
  // taken out the moment the menu leaves the root, and can only reappear
  // once the menu is back at the top.
  onActiveMenuChanged: root.syncCalcRow()

  // A search row takes its second line from the path of the menu it lives in.
  // A row conjured out of the search field has no such path, so it gets the
  // expression instead — "=3+2" under the answer.
  function parentPathFor(id) {
    var entry = root.item(id)
    if (!entry) return ""
    if (id === root.calcRowId) return "=" + entry.calcExpression
    if (!entry.parent || entry.parent === "root") return ""
    return root.pathFor(entry.parent)
  }

  function calcAction(result) {
    return "omarchy-clipboard-paste-text --copy-only " + Util.shellQuote(result.display)
      + " && omarchy-notification-send --app-name calculator -g " + Util.shellQuote(root.calcIcon)
      + " " + Util.shellQuote("Copied " + result.display)
      + " " + Util.shellQuote("= " + result.expression)
  }

  function calcRow(result) {
    return {
      id: root.calcRowId,
      parent: "root",
      kind: "action",
      icon: root.calcIcon,
      iconFont: "",
      label: result.display,
      title: "",
      target: "",
      // Search keeps a row when every word of the query is a word of its
      // description, and the words of the query are always words of the query
      // itself — so the row survives whatever the user types, including
      // expressions with no letters in them for the name match to catch.
      description: ("=" + result.expression).toLowerCase(),
      action: root.calcAction(result),
      provider: "",
      aliases: [],
      when: "",
      checked: "",
      order: root.calcRowOrder,
      calcExpression: result.expression
    }
  }

  // Mirrors what the apps provider does: rebuild the item map around the row
  // rather than mutating it, because the menu watches the property for change
  // and a mutation in place is not one.
  function syncCalcRow() {
    // A dmenu (`omarchy-menu-select`) is someone else's list of options being
    // filtered, not the Omarchy menu being searched. Answer nothing into it,
    // and take the row back out if one was standing when it opened.
    //
    // The calculator stays dormant until the search opens with '=': that first
    // character is the switch, and everything after it is the expression. Any
    // other first character — a digit, a letter, another operator, a leading
    // space — leaves the menu exactly as Omarchy built it, so "4+4" stays a
    // search and only "=4+4" gets an answer. A lone '=' activates nothing by
    // itself: evaluate() finds no expression after it and answers null.
    var activated = !root.dmenuActive && root.filterText.charAt(0) === "="
    var result = activated ? Calculator.evaluate(root.filterText.substring(1)) : null
    var items = root.items || ({})
    var order = Array.isArray(root.itemOrder) ? root.itemOrder : []
    var present = !!items[root.calcRowId]

    // Top-menu-only is the accepted design: the row is parented at "root" and
    // the stock menu surfaces only rows descended from the active menu, so the
    // calculator answers at the top of the menu and nowhere else. The plugin
    // enforces that itself instead of leaning on the host's descendant filter:
    // away from the root the row is never injected, and one already standing
    // is taken back out — whatever the query says.
    if (!result || root.activeMenu !== "root") {
      if (!present) return
      var pruned = ({})
      for (var id in items) {
        if (id !== root.calcRowId) pruned[id] = items[id]
      }
      root.items = pruned
      root.itemOrder = order.filter(function(entryId) { return entryId !== root.calcRowId })
      return
    }

    var next = ({})
    for (var key in items) next[key] = items[key]
    next[root.calcRowId] = root.calcRow(result)
    root.items = next
    if (!present) root.itemOrder = order.concat([root.calcRowId])
  }
}
