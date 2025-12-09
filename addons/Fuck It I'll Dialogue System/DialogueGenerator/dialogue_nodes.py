import sys
from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QMenu, QGraphicsView,
    QGraphicsScene, QGraphicsItem, QGraphicsRectItem, QPushButton
)
from PySide6.QtCore import Qt, QPointF


class NodeItem(QGraphicsRectItem):
    def __init__(self, x, y):
        super().__init__(0, 0, 150, 70)
        self.setPos(x, y)
        self.setFlag(QGraphicsItem.ItemIsMovable)
        self.setFlag(QGraphicsItem.ItemIsSelectable)
        self.setBrush(Qt.yellow)


class NodeGraphWidget(QGraphicsView):
    def __init__(self):
        super().__init__()
        self.scene = QGraphicsScene()
        self.setScene(self.scene)
        self.setRenderHints(self.renderHints())
        self.setContextMenuPolicy(Qt.CustomContextMenu)
        self.customContextMenuRequested.connect(self._open_context_menu)

        # Some sample nodes
        self.scene.addItem(NodeItem(0, 0))
        self.scene.addItem(NodeItem(200, 120))

    def _open_context_menu(self, pos):
        # Fix: convert viewport click → scene coordinates
        scene_pos = self.mapToScene(pos)

        menu = QMenu()

        add_node_action = menu.addAction("Add Node")
        selected = menu.exec(self.viewport().mapToGlobal(pos))

        if selected == add_node_action:
            self._add_node(scene_pos)

    def _add_node(self, scene_pos):
        node = NodeItem(scene_pos.x(), scene_pos.y())
        self.scene.addItem(node)

    # Optional: clean right-click behavior
    def mousePressEvent(self, event):
        if event.button() == Qt.RightButton:
            # Trigger normal context menu
            self.customContextMenuRequested.emit(event.pos())
            return
        super().mousePressEvent(event)


class DialogueEditor(QWidget):
    def __init__(self):
        super().__init__()
        layout = QVBoxLayout()

        self.graph_widget = NodeGraphWidget()
        layout.addWidget(self.graph_widget)

        self.setLayout(layout)
        self.setWindowTitle("Dialogue Node Editor")
        self.resize(900, 600)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    editor = DialogueEditor()
    editor.show()
    sys.exit(app.exec())
