import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Persistent, deliberately small to-do list for Omarchy's Quickshell bar.
BarWidget {
  id: root
  moduleName: "dhruv.todo"

  property bool stateLoaded: false
  property var taskRows: []
  property string lastSavedState: ""
  property int editingIndex: -1
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/todo.json"
  readonly property int openCount: {
    var count = 0
    for (var i = 0; i < tasks.count; i++) if (!tasks.get(i).done) count++
    return count
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function loadTasks(raw) {
    if (stateLoaded) return
    var entries = []
    try {
      var parsed = JSON.parse(raw)
      entries = parsed && Array.isArray(parsed.tasks) ? parsed.tasks : []
    } catch (error) {
      reloadRetry.restart()
      return
    }
    var loaded = []
    for (var i = 0; i < entries.length; i++) {
      var title = String(entries[i].text || "").trim()
      var priority = ["P1", "P2", "P3"].indexOf(entries[i].priority) >= 0 ? entries[i].priority : "P3"
      if (title !== "") loaded.push({ text: title, done: entries[i].done === true, priority: priority })
    }
    tasks.clear()
    for (var j = 0; j < loaded.length; j++) tasks.append(loaded[j])
    lastSavedState = raw
    normalizeTaskOrder()
    stateLoaded = true
  }

  function initializeEmptyTasks() {
    if (stateLoaded) return
    tasks.clear()
    lastSavedState = ""
    stateLoaded = true
  }

  function saveTasks() {
    if (!stateLoaded) return
    var saved = []
    for (var i = 0; i < tasks.count; i++) saved.push(tasks.get(i))
    var nextState = JSON.stringify({ version: 1, tasks: saved }, null, 2) + "\n"
    if (lastSavedState !== "") backupFile.setText(lastSavedState)
    stateFile.setText(nextState)
    lastSavedState = nextState
  }

  Timer { id: reloadRetry; interval: 120; repeat: false; onTriggered: stateFile.reload() }

  function addTask() {
    var title = entry.text.trim()
    if (title === "") return
    tasks.append({ text: title, done: false, priority: "P3" })
    entry.text = ""
    saveTasks()
    entry.forceActiveFocus()
  }

  function toggleTask(index) {
    tasks.setProperty(index, "done", !tasks.get(index).done)
    saveTasks()
  }

  function removeTask(index) {
    tasks.remove(index)
    if (editingIndex === index) editingIndex = -1
    saveTasks()
  }

  function startEditing(index) {
    editingIndex = index
  }

  function commitEdit(index, value) {
    var title = String(value).trim()
    if (title !== "") tasks.setProperty(index, "text", title)
    editingIndex = -1
    saveTasks()
  }

  function cancelEdit() {
    editingIndex = -1
  }

  function cyclePriority(index) {
    var current = tasks.get(index).priority
    var next = current === "P1" ? "P2" : (current === "P2" ? "P3" : "P1")
    tasks.setProperty(index, "priority", next)
    normalizeTaskOrder()
    saveTasks()
  }

  function priorityColor(priority) {
    return priority === "P1" ? "#ef5350" : (priority === "P2" ? "#fbc02d" : "#66bb6a")
  }

  function priorityRank(priority) {
    return priority === "P1" ? 1 : (priority === "P2" ? 2 : 3)
  }

  function normalizeTaskOrder() {
    // Move rows in place. Clearing a ListModel invalidates objects returned
    // by get(), which can erase their roles during a live plugin reload.
    for (var target = 0; target < tasks.count; target++) {
      var best = target
      for (var candidate = target + 1; candidate < tasks.count; candidate++) {
        if (priorityRank(tasks.get(candidate).priority) < priorityRank(tasks.get(best).priority))
          best = candidate
      }
      if (best !== target) tasks.move(best, target, 1)
    }
  }

  function priorityBounds(priority) {
    var first = -1
    var last = -1
    for (var i = 0; i < tasks.count; i++) {
      if (tasks.get(i).priority !== priority) continue
      if (first < 0) first = i
      last = i
    }
    return { first: first, last: last }
  }

  function moveTask(from, to) {
    var bounds = priorityBounds(tasks.get(from).priority)
    var destination = Math.max(bounds.first, Math.min(bounds.last, to))
    if (from === destination) return
    tasks.move(from, destination, 1)
    saveTasks()
  }

  function registerTaskRow(row) {
    var next = taskRows.slice()
    next.push(row)
    taskRows = next
  }

  function unregisterTaskRow(row) {
    taskRows = taskRows.filter(function(candidate) { return candidate !== row })
  }

  function taskIndexAt(y) {
    var last = 0
    for (var i = 0; i < taskRows.length; i++) {
      var row = taskRows[i]
      if (!row || row.index === undefined) continue
      if (y <= row.y + row.height / 2) return row.index
      last = Math.max(last, row.index)
    }
    return last
  }

  readonly property bool opened: panel.opened
  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing
  function open() { panel.open() }
  function close() { panel.close() }
  function togglePanel() { panel.toggle() }
  function closeForPopoutSwitch() { panel.closeForPopoutSwitch() }

  ListModel { id: tasks }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadTasks(text())
    onFileChanged: {
      root.stateLoaded = false
      reload()
    }
    onLoadFailed: root.initializeEmptyTasks()
  }

  FileView { id: backupFile; path: root.statePath + ".previous"; atomicWrites: true; printErrors: false }

  Component.onCompleted: stateFile.reload()

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.openCount === 0 ? "󰄬" : "󰄱 " + root.openCount
    tooltipText: root.openCount === 1 ? "1 task left" : root.openCount + " tasks left"
    horizontalMargin: 8
    onPressed: function() { root.togglePanel() }
  }

  Panel {
    id: panel
    moduleName: root.moduleName
    manageIpc: false
    bar: root.bar

    function open() {
      controller.show()
      Qt.callLater(function() { entry.forceActiveFocus() })
    }

    function close() { controller.hide() }
    function toggle() { opened ? close() : open() }

    KeyboardPanel {
      anchorItem: button
      owner: root
      bar: root.bar
      open: panel.opened
      centerOnBar: true
      contentWidth: fittedContentWidth(Style.space(360))
      contentHeight: fittedContentHeight(Style.space(330))

      Item {
        anchors.fill: parent

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(16)
          spacing: Style.space(12)

          Row {
            Text {
              text: "TO-DO"
              color: root.bar ? root.bar.barForeground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              font.letterSpacing: 1
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              leftPadding: Style.space(8)
              text: root.openCount === 0 ? "All clear" : root.openCount + " left"
              color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.space(6) : 0
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)
            border.width: entry.activeFocus ? 1 : 0
            border.color: Color.accent

            TextInput {
              id: entry
              anchors.left: parent.left
              anchors.right: addButton.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              color: root.bar ? root.bar.barForeground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              clip: true
              onAccepted: root.addTask()
            }
            Text {
              anchors.left: entry.left
              anchors.verticalCenter: parent.verticalCenter
              visible: entry.text === ""
              text: "Add a task…"
              color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
              font.family: entry.font.family
              font.pixelSize: entry.font.pixelSize
            }
            Text {
              id: addButton
              anchors.right: parent.right
              anchors.rightMargin: Style.space(11)
              anchors.verticalCenter: parent.verticalCenter
              text: "＋"
              color: Color.accent
              font.pixelSize: Style.font.title
              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(8)
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addTask()
              }
            }
          }

          Flickable {
            width: parent.width
            height: parent.height - y
            contentWidth: width
            contentHeight: taskColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: taskColumn
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: tasks
                delegate: Rectangle {
                  id: taskRow
                  required property int index
                  required property string text
                  required property bool done
                  required property string priority
                  readonly property bool editing: root.editingIndex === index
                  width: taskColumn.width
                  height: Math.max(Style.space(34), (editing ? taskEditor.contentHeight : taskLabel.implicitHeight) + Style.space(12))
                  radius: Style.cornerRadius > 0 ? Style.space(5) : 0
                  color: taskHover.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent"

                  Text {
                    id: check
                    anchors.left: dragHandle.right
                    anchors.leftMargin: Style.space(5)
                    anchors.verticalCenter: parent.verticalCenter
                    text: done ? "󰄬" : "󰄱"
                    color: done ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    id: taskLabel
                    anchors.left: check.right
                    anchors.right: priorityButton.left
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: taskRow.text
                    visible: !taskRow.editing
                    color: root.bar ? root.bar.barForeground : Color.foreground
                    opacity: done ? 0.45 : 1
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    wrapMode: Text.Wrap
                  }
                  TextEdit {
                    id: taskEditor
                    anchors.left: check.right
                    anchors.right: editButton.left
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    height: contentHeight
                    visible: taskRow.editing
                    text: taskRow.text
                    color: root.bar ? root.bar.barForeground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    Keys.onPressed: function(event) {
                      if (event.key === Qt.Key_Escape) {
                        root.cancelEdit()
                        event.accepted = true
                      } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                        root.commitEdit(index, taskEditor.text)
                        event.accepted = true
                      }
                    }
                  }
                  Text {
                    id: editButton
                    anchors.right: priorityButton.left
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰏫"
                    color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.25)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    MouseArea {
                      anchors.fill: parent
                      anchors.margins: -Style.space(6)
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.startEditing(index)
                    }
                  }
                  Text {
                    id: priorityButton
                    anchors.right: removeButton.left
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: priority
                    color: root.priorityColor(priority)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    MouseArea {
                      anchors.fill: parent
                      anchors.margins: -Style.space(5)
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.cyclePriority(index)
                    }
                  }
                  Text {
                    id: removeButton
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.25)
                    font.pixelSize: Style.font.title
                    MouseArea {
                      anchors.fill: parent
                      anchors.margins: -Style.space(6)
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.removeTask(index)
                    }
                  }
                  MouseArea {
                    id: taskHover
                    anchors.left: check.left
                    anchors.right: editButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    enabled: !taskRow.editing
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleTask(index)
                  }
                  Text {
                    id: dragHandle
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⠿"
                    color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.45)
                    font.pixelSize: Style.font.body
                    MouseArea {
                      id: dragArea
                      anchors.fill: parent
                      anchors.margins: -Style.space(6)
                      cursorShape: Qt.SizeVerCursor
                      drag.target: taskRow
                      drag.axis: Drag.YAxis
                      onPressed: taskRow.z = 1
                      onReleased: function(mouse) {
                        var point = dragArea.mapToItem(taskColumn, mouse.x, mouse.y)
                        root.moveTask(index, root.taskIndexAt(point.y))
                        taskRow.x = 0
                        taskRow.y = 0
                        taskRow.z = 0
                      }
                    }
                  }

                  Component.onCompleted: root.registerTaskRow(taskRow)
                  Component.onDestruction: root.unregisterTaskRow(taskRow)
                  onEditingChanged: if (editing) Qt.callLater(function() { taskEditor.forceActiveFocus() })
                }
              }

              Text {
                visible: tasks.count === 0
                width: taskColumn.width
                topPadding: Style.space(18)
                text: "Nothing on your list."
                horizontalAlignment: Text.AlignHCenter
                color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.45)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }
        }
      }
    }
  }
}
