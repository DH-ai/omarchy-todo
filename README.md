# Omarchy To-do

A small, persistent to-do list for the Omarchy (Quickshell) top bar. The
widget sits next to the centre clock and stores its tasks in
`~/.local/state/omarchy/todo.json`.

Click the bar icon to open the list. Type a task and press Enter (or `+`) to
add it, click a task to mark it complete, and click `×` to delete it. Click a
priority label to cycle **P1** (red), **P2** (yellow), and **P3** (green).
Drag the `⠿` handle to reorder tasks. The bar shows the count of unfinished
tasks.

## Install

```bash
./install.sh
omarchy restart shell
```

The installer backs up `~/.config/omarchy/shell.json`, copies the user-owned
plugin to `~/.config/omarchy/plugins/dhruv.todo/`, and adds it just before the
centre clock. It requires `jq`, which is normally installed with Omarchy.

## Customize placement

The installed layout entry is:

```json
{ "id": "dhruv.todo" }
```

It is placed in the `bar.layout.center` array before `omarchy.clock`. See
[examples/shell.center.json](examples/shell.center.json) for the surrounding
layout. Move that entry to `left` or `right` if you prefer a different spot.

## Development

All plugin code is in `plugin/dhruv.todo/`. Omarchy watches that directory, so
saving changes while the shell is running reloads the widget. Check syntax with:

```bash
qmllint plugin/dhruv.todo/Todo.qml
```

To remove it, delete the `dhruv.todo` layout entry from
`~/.config/omarchy/shell.json`, remove `~/.config/omarchy/plugins/dhruv.todo/`,
then restart the shell.
