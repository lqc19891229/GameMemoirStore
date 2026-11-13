"""Hardware replacement window for FurniturePublisher (Tkinter, no extra dependencies)."""
from __future__ import annotations

from pathlib import Path
import queue
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from hardware_core import HardwareItem, HARDWARE, LABELS, preview_hardware, publish_hardware
from publisher_core import PublishError


DEFAULTS = {
    "monitor": ("0.36", "0.35", "0.32", "0.29", "0.22", "0", "0.22", "0.155"),
    "computer": ("0.19", "0.42", "0.40", "0", "0", "0", "0", "0"),
    "keyboard": ("0.43", "0.045", "0.16", "0", "0", "0", "0", "0"),
    "mouse": ("0.065", "0.035", "0.11", "0", "0", "0", "0", "0"),
}
FIELDS = [
    ("width", "宽 X (m)"), ("height", "高 Y (m)"),
    ("depth", "深 Z (m)"), ("screen_width", "屏幕宽 (m)"),
    ("screen_height", "屏幕高 (m)"), ("screen_x", "屏幕中心 X"),
    ("screen_y", "屏幕中心 Y"), ("screen_z", "屏幕中心 Z"),
]


class HardwarePanel(ttk.Frame):
    def __init__(self, parent, values: dict[str, str]):
        super().__init__(parent)
        self.project = tk.StringVar(value=values.get("project", ""))
        self.godot = tk.StringVar(value=values.get("godot", "godot"))
        self.source = tk.StringVar(value=values.get("source", ""))
        self.role = tk.StringVar(value="monitor")
        self.item_id = tk.StringVar(value="starter_monitor")
        self.dims = {key: tk.StringVar(value=value) for (key, _), value in zip(FIELDS, DEFAULTS["monitor"])}
        self.confirm = tk.BooleanVar(value=False)
        self.preview_ok = False
        self.running = False
        self.events: queue.Queue = queue.Queue()
        self._build()
        self.after(120, self._poll)

    def _build(self):
        main = ttk.Frame(self, padding=16)
        main.pack(fill="both", expand=True)
        ttk.Label(main, text="单个电脑设备 · 替换已有型号", font=("Microsoft YaHei UI", 16, "bold")).pack(anchor="w")
        ttk.Label(main, text="保留商品 ID 和库存；自动备份旧模型、场景与 .tres。请先关闭 Godot 和游戏。").pack(anchor="w", pady=(3, 12))
        fields = ttk.Frame(main)
        fields.pack(fill="x")
        fields.columnconfigure(1, weight=1)
        for i, (label, variable) in enumerate([
            ("Godot 项目目录", self.project), ("Godot 4.6 程序路径", self.godot),
            ("成品 GLB 文件", self.source),
        ]):
            ttk.Label(fields, text=label, width=20).grid(row=i, column=0, sticky="w", pady=5)
            ttk.Entry(fields, textvariable=variable).grid(row=i, column=1, sticky="ew", padx=8)
            ttk.Button(fields, text="浏览…", command=lambda n=i: self._browse(n)).grid(row=i, column=2)
        picker = ttk.Frame(main)
        picker.pack(fill="x", pady=(12, 6))
        ttk.Label(picker, text="设备类型").pack(side="left")
        self.role_box = ttk.Combobox(picker, values=list(LABELS), state="readonly", textvariable=self.role, width=15)
        self.role_box.pack(side="left", padx=(8, 18))
        self.role_box.bind("<<ComboboxSelected>>", lambda _event: self._role_changed())
        ttk.Label(picker, text="现有商品 ID").pack(side="left")
        self.id_box = ttk.Combobox(picker, state="readonly", textvariable=self.item_id, width=25)
        self.id_box.pack(side="left", padx=8)
        sizes = ttk.LabelFrame(main, text="新模型尺寸（Godot 1 单位 = 1 米）", padding=8)
        sizes.pack(fill="x", pady=(4, 10))
        for i, (key, label) in enumerate(FIELDS):
            col, row = i % 4, i // 4
            ttk.Label(sizes, text=label).grid(row=row * 2, column=col, padx=5, sticky="w")
            ttk.Entry(sizes, textvariable=self.dims[key], width=16).grid(row=row * 2 + 1, column=col, padx=5, pady=(0, 8), sticky="w")
        ttk.Label(main, text="模型：底面中心原点，Y 朝上，+Z 朝正面。屏幕字段只供显示器填写。", foreground="#666666").pack(anchor="w")
        row = ttk.Frame(main)
        row.pack(fill="x", pady=12)
        self.preview_button = ttk.Button(row, text="1. 检查 / 预览替换", command=self._preview)
        self.preview_button.pack(side="left", padx=(0, 10))
        self.publish_button = ttk.Button(row, text="2. 确认并替换设备", command=self._publish, state="disabled")
        self.publish_button.pack(side="left")
        ttk.Checkbutton(row, text="确认已经备份项目并关闭 Godot", variable=self.confirm, command=self._controls).pack(side="left", padx=12)
        self.log = tk.Text(main, height=15, font=("Consolas", 10), wrap="word")
        self.log.pack(fill="both", expand=True)
        for variable in [self.project, self.godot, self.source, self.role, self.item_id, *self.dims.values()]:
            variable.trace_add("write", lambda *_: self._invalidate())
        self._role_changed()

    def _browse(self, index: int) -> None:
        if index == 0:
            value = filedialog.askdirectory(title="选择 Godot 项目目录", parent=self)
            if value: self.project.set(value)
        elif index == 1:
            value = filedialog.askopenfilename(title="选择 Godot 4.6 程序", filetypes=[("Windows 可执行文件", "*.exe"), ("所有文件", "*")], parent=self)
            if value: self.godot.set(value)
        else:
            value = filedialog.askopenfilename(title="选择已经完成的 GLB", filetypes=[("GLB 模型", "*.glb")], parent=self)
            if value: self.source.set(value)

    def _role_changed(self):
        choices = [item_id for kind, item_id in HARDWARE if kind == self.role.get()]
        self.id_box["values"] = choices
        if self.item_id.get() not in choices:
            self.item_id.set(choices[0])
        for (key, _), value in zip(FIELDS, DEFAULTS[self.role.get()]):
            self.dims[key].set(value)

    def _item(self) -> HardwareItem:
        try:
            sizes = {key: float(value.get()) for key, value in self.dims.items()}
        except ValueError as exc:
            raise PublishError("设备尺寸需要填写数字，单位为米") from exc
        return HardwareItem(project=self.project.get().strip(), godot=self.godot.get().strip(),
                            source=self.source.get().strip(), role=self.role.get(),
                            item_id=self.item_id.get(), **sizes)

    def _write(self, message):
        self.log.insert("end", message + "\n")
        self.log.see("end")

    def _invalidate(self):
        self.preview_ok = False
        self._controls()

    def _controls(self):
        self.publish_button["state"] = "normal" if self.preview_ok and self.confirm.get() and not self.running else "disabled"
        self.preview_button["state"] = "disabled" if self.running else "normal"

    def _preview(self):
        try:
            self._write("\n========== 设备替换预检 ==========")
            self._write(preview_hardware(self._item()))
            self.preview_ok = True
            self._controls()
        except (PublishError, OSError, ValueError) as exc:
            self.preview_ok = False
            self._controls()
            self._write("预检失败：" + str(exc))
            messagebox.showerror("预检失败", str(exc), parent=self)

    def _publish(self):
        if not self.preview_ok or not self.confirm.get():
            return
        item = self._item()
        if not messagebox.askyesno("最后确认", f"确认替换 {LABELS[item.role]} / {item.item_id}？\n旧 GLB、配置和场景将先备份。", parent=self):
            return
        self.running = True
        self._controls()

        def worker():
            try:
                result = publish_hardware(item, log=lambda line: self.events.put(("log", line)))
                self.events.put(("ok", result))
            except Exception as exc:
                self.events.put(("error", str(exc)))
        threading.Thread(target=worker, daemon=True).start()

    def _poll(self):
        if not self.winfo_exists():
            return
        try:
            while True:
                key, value = self.events.get_nowait()
                if key == "log":
                    self._write(value)
                elif key == "ok":
                    self.running = False
                    self.preview_ok = False
                    self._controls()
                    self._write("成功。备份：" + value["backup"])
                    messagebox.showinfo("设备发布完成", "已替换现有设备模型。请在 Godot 中检查真实尺寸、碰撞及屏幕映射。", parent=self)
                else:
                    self.running = False
                    self.preview_ok = False
                    self._controls()
                    self._write("失败：" + value)
                    messagebox.showerror("设备发布失败", value, parent=self)
        except queue.Empty:
            pass
        self.after(120, self._poll)
