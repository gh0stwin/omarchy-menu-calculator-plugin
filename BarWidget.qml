import "file:///usr/share/omarchy/shell/plugins/menu" as Upstream

// The stock menu button, unchanged. It is here because a plugin that stands in
// for omarchy.menu has to answer for both of its kinds, or enabling this one
// takes the Omarchy button off the bar with it.
Upstream.BarWidget {
}
