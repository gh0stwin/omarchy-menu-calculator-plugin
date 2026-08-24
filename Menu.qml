import QtQuick
import qs.Commons
import "file:///usr/share/omarchy/shell/plugins/menu" as Upstream
import "Calculator.js" as Calculator

// The Omarchy menu, plus one row it does not ship with: type an expression
// into the search field and the answer appears above the results, with the
// expression under it. Enter copies the answer.
//
// This is the stock menu, not a fork of it — `Upstream.Menu` is the menu that
// ships with Omarchy, and everything below is the calculator bolted onto it.
// The row is a real menu item, injected into the item tree the way the apps
// provider injects applications, so search, keyboard, pointer, and theming
// all treat it like any other row.
Upstream.Menu {
  id: root

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
      description: String(result.expression).toLowerCase(),
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
    var result = root.dmenuActive ? null : Calculator.evaluate(root.filterText)
    var items = root.items || ({})
    var order = Array.isArray(root.itemOrder) ? root.itemOrder : []
    var present = !!items[root.calcRowId]

    if (!result) {
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
