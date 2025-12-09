import sys
import json
from PySide6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QPushButton, QLabel,
    QLineEdit, QTextEdit, QComboBox, QGraphicsView, QGraphicsScene,
    QGraphicsItem, QGraphicsRectItem, QGraphicsTextItem, QGraphicsPathItem,
    QFormLayout, QGroupBox, QMessageBox
)
from PySide6.QtCore import Qt, QRectF, QPointF
from PySide6.QtGui import QPen, QColor, QBrush, QFont, QPainterPath
from PySide6.QtGui import QPen, QColor, QBrush, QFont, QPainterPath, QPainter

# Predefined characters
CHARACTERS = {
    "stan": "res://characters/Stan/portrait.png",
    "dipper": "res://characters/Dipper/portrait.png",
    "mabel": "res://characters/Mabel/portrait.png"
}

class DialogueLine:
    """Data model for a dialogue line"""
    def __init__(self, title="Line"):
        self.id = ""
        self.speaker = ""
        self.text = ""
        self.optionA = None
        self.optionB = None
        self.optionC = None
        self.set_var = {}
        self.jump = ""
        self.jump_if = {}
        self.title = title
        self.node_item = None  # reference to graphics node

    def to_dict(self):
        data = {"text": self.text}
        if self.id: data["id"] = self.id
        if self.speaker: data["speaker"] = self.speaker
        if self.optionA: data["optionA"] = self.optionA
        if self.optionB: data["optionB"] = self.optionB
        if self.optionC: data["optionC"] = self.optionC
        if self.set_var: data["set_var"] = self.set_var
        if self.jump: data["jump"] = self.jump
        if self.jump_if: data["jump_if"] = self.jump_if
        return data

class EdgeItem(QGraphicsPathItem):
    """Connection line between nodes"""
    def __init__(self, source_node, target_node):
        super().__init__()
        self.source = source_node
        self.target = target_node
        pen = QPen(QColor("#00ff00"), 2)
        self.setPen(pen)
        self.update_position()

    def update_position(self):
        source_center = self.source.scenePos() + QPointF(self.source.rect().width()/2, self.source.rect().height())
        target_center = self.target.scenePos() + QPointF(self.target.rect().width()/2, 0)
        path = QPainterPath()
        path.moveTo(source_center)
        # simple cubic curve for nicer edges
        ctrl1 = source_center + QPointF(0, 50)
        ctrl2 = target_center + QPointF(0, -50)
        path.cubicTo(ctrl1, ctrl2, target_center)
        self.setPath(path)

class DialogueNodeItem(QGraphicsRectItem):
    """Visual node representing a dialogue line"""
    def __init__(self, line: DialogueLine):
        super().__init__(0,0,220,180)
        self.line = line
        line.node_item = self
        self.setBrush(QBrush(QColor("#2e2e2e")))
        self.setPen(QPen(QColor("#888888"), 2))
        self.setFlag(QGraphicsItem.ItemIsMovable)
        self.setFlag(QGraphicsItem.ItemIsSelectable)
        self.text_items = {}
        self.draw_contents()

    def draw_contents(self):
        """Draw all text labels inside the node"""
        for item in self.text_items.values():
            self.scene().removeItem(item)
        self.text_items.clear()
        font = QFont("Arial", 10)
        y = 5
        for key in ["ID", "Speaker", "Text", "Jump", "OptionA", "OptionB", "OptionC", "Set Vars"]:
            val = ""
            if key=="ID": val=self.line.id
            elif key=="Speaker": val=self.line.speaker
            elif key=="Text": val=self.line.text
            elif key=="Jump": val=self.line.jump
            elif key=="OptionA": val=str(self.line.optionA)
            elif key=="OptionB": val=str(self.line.optionB)
            elif key=="OptionC": val=str(self.line.optionC)
            elif key=="Set Vars": val=str(self.line.set_var)
            label = QGraphicsTextItem(f"{key}: {val}", self)
            label.setDefaultTextColor(Qt.white)
            label.setFont(font)
            label.setPos(5, y)
            y += 20
            self.text_items[key] = label

class NodeGraphEditor(QGraphicsView):
    """Graphics view with zoom/pan support"""
    def __init__(self, scene):
        super().__init__(scene)
        self.setRenderHints(self.renderHints() | QPainter.Antialiasing)
        self.zoom_factor = 1.15

    def wheelEvent(self, event):
        if event.angleDelta().y() > 0:
            self.scale(self.zoom_factor, self.zoom_factor)
        else:
            self.scale(1/self.zoom_factor, 1/self.zoom_factor)

    def mousePressEvent(self, event):
        if event.button() == Qt.MiddleButton:
            self.setDragMode(QGraphicsView.ScrollHandDrag)
            fake_event = type(event)(event.type(), event.localPos(), event.screenPos(),
                                     Qt.LeftButton, event.buttons() | Qt.LeftButton,
                                     event.modifiers())
            super().mousePressEvent(fake_event)
        else:
            super().mousePressEvent(event)

    def mouseReleaseEvent(self, event):
        self.setDragMode(QGraphicsView.NoDrag)
        super().mouseReleaseEvent(event)

class DialogueEditor(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Godot Dialogue Node Editor")
        self.setMinimumSize(1400, 800)
        self.setStyleSheet("background-color: #1e1e1e; color: #ffffff; font-size: 14px;")

        self.dialogue_lines = []
        self.edges = []

        self.main_layout = QHBoxLayout()
        self.setLayout(self.main_layout)

        # Graphics scene + view
        self.scene = QGraphicsScene()
        self.view = NodeGraphEditor(self.scene)
        self.main_layout.addWidget(self.view, 3)

        # Right inspector
        self.editor_layout = QVBoxLayout()
        self.main_layout.addLayout(self.editor_layout, 2)

        form_layout = QFormLayout()
        self.speaker_dropdown = QComboBox()
        self.speaker_dropdown.addItems(CHARACTERS.keys())
        self.id_input = QLineEdit()
        form_layout.addRow("Speaker:", self.speaker_dropdown)
        form_layout.addRow("ID:", self.id_input)
        self.editor_layout.addLayout(form_layout)

        self.text_edit = QTextEdit()
        self.text_edit.setPlaceholderText("Dialogue Text")
        self.editor_layout.addWidget(QLabel("Dialogue Text:"))
        self.editor_layout.addWidget(self.text_edit)

        self.option_edits = {}
        for opt in ["A","B","C"]:
            group = QGroupBox(f"Option {opt}")
            group_layout = QFormLayout()
            text_input = QLineEdit()
            jump_input = QLineEdit()
            group_layout.addRow("Text:", text_input)
            group_layout.addRow("Jump:", jump_input)
            group.setLayout(group_layout)
            self.editor_layout.addWidget(group)
            self.option_edits[opt] = (text_input, jump_input)

        self.set_var_input = QTextEdit()
        self.set_var_input.setPlaceholderText('{"met_stan": true}')
        self.editor_layout.addWidget(QLabel("Set Vars:"))
        self.editor_layout.addWidget(self.set_var_input)

        self.jump_input = QLineEdit()
        self.jump_if_input = QTextEdit()
        self.jump_if_input.setPlaceholderText('{"met_stan":"after_choice"}')
        self.editor_layout.addWidget(QLabel("Jump:"))
        self.editor_layout.addWidget(self.jump_input)
        self.editor_layout.addWidget(QLabel("Jump If:"))
        self.editor_layout.addWidget(self.jump_if_input)

        btn_layout = QHBoxLayout()
        self.add_btn = QPushButton("Add Node")
        self.add_btn.clicked.connect(self.add_node)
        self.remove_btn = QPushButton("Remove Node")
        self.remove_btn.clicked.connect(self.remove_node)
        self.save_btn = QPushButton("Export JSON")
        self.save_btn.clicked.connect(self.export_json)
        btn_layout.addWidget(self.add_btn)
        btn_layout.addWidget(self.remove_btn)
        btn_layout.addWidget(self.save_btn)
        self.editor_layout.addLayout(btn_layout)

        # Current selected node
        self.current_line = None
        self.scene.selectionChanged.connect(self.node_selected)

    def add_node(self):
        line = DialogueLine(f"Line {len(self.dialogue_lines)+1}")
        self.dialogue_lines.append(line)
        node = DialogueNodeItem(line)
        node.setPos(len(self.dialogue_lines)*30, len(self.dialogue_lines)*30)
        self.scene.addItem(node)
        self.update_edges()

    def remove_node(self):
        for node in self.scene.selectedItems():
            line = node.line
            if line in self.dialogue_lines:
                self.dialogue_lines.remove(line)
            self.scene.removeItem(node)
        self.current_line = None
        self.update_edges()

    def node_selected(self):
        selected = self.scene.selectedItems()
        if not selected: return
        node = selected[0]
        self.current_line = node.line
        self.load_node(node.line)

    def load_node(self, line: DialogueLine):
        self.speaker_dropdown.setCurrentText(line.speaker)
        self.id_input.setText(line.id)
        self.text_edit.setPlainText(line.text)
        for opt, (text_input, jump_input) in self.option_edits.items():
            data = getattr(line, f"option{opt}")
            if data:
                text_input.setText(data.get("text",""))
                jump_input.setText(data.get("jump",""))
            else:
                text_input.setText("")
                jump_input.setText("")
        self.set_var_input.setPlainText(json.dumps(line.set_var))
        self.jump_input.setText(line.jump)
        self.jump_if_input.setPlainText(json.dumps(line.jump_if))

    def save_current_node(self):
        if not self.current_line: return
        line = self.current_line
        line.speaker = self.speaker_dropdown.currentText()
        line.id = self.id_input.text()
        line.text = self.text_edit.toPlainText()
        for opt, (text_input, jump_input) in self.option_edits.items():
            text = text_input.text().strip()
            jump = jump_input.text().strip()
            if text:
                setattr(line, f"option{opt}", {"text": text, "jump": jump} if jump else {"text": text})
            else:
                setattr(line, f"option{opt}", None)
        try:
            line.set_var = json.loads(self.set_var_input.toPlainText()) if self.set_var_input.toPlainText().strip() else {}
        except:
            QMessageBox.warning(self,"JSON Error","Invalid JSON in Set Vars")
            line.set_var = {}
        line.jump = self.jump_input.text().strip()
        try:
            line.jump_if = json.loads(self.jump_if_input.toPlainText()) if self.jump_if_input.toPlainText().strip() else {}
        except:
            QMessageBox.warning(self,"JSON Error","Invalid JSON in Jump If")
            line.jump_if = {}
        line.node_item.draw_contents()
        self.update_edges()

    def update_edges(self):
        # Remove old edges
        for e in self.edges:
            self.scene.removeItem(e)
        self.edges.clear()
        # Build id map
        id_map = {line.id: line.node_item for line in self.dialogue_lines if line.id}
        for line in self.dialogue_lines:
            from_node = line.node_item
            targets = []
            # main jump
            if line.jump and line.jump in id_map:
                targets.append(id_map[line.jump])
            # options
            for opt in ["A","B","C"]:
                data = getattr(line, f"option{opt}")
                if data and "jump" in data and data["jump"] in id_map:
                    targets.append(id_map[data["jump"]])
            for tgt in targets:
                edge = EdgeItem(from_node, tgt)
                self.scene.addItem(edge)
                self.edges.append(edge)

    def export_json(self):
        self.save_current_node()
        data = [line.to_dict() for line in self.dialogue_lines]
        try:
            with open("dialogue_export.json","w",encoding="utf-8") as f:
                json.dump(data,f,ensure_ascii=False,indent=2)
            QMessageBox.information(self,"Exported","Dialogue saved to dialogue_export.json")
        except Exception as e:
            QMessageBox.critical(self,"Error",f"Failed to export: {e}")

    def closeEvent(self,event):
        self.save_current_node()
        super().closeEvent(event)

if __name__=="__main__":
    app = QApplication(sys.argv)
    editor = DialogueEditor()
    editor.show()
    sys.exit(app.exec())
