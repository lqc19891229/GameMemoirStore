"""Batch hardware import UI: discover model_specs.json and import the whole starter set."""
from __future__ import annotations

from pathlib import Path
import json
import queue
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from batch_hardware import preview_batch, publish_batch
from publisher_core import PublishError


class BatchHardwarePanel(ttk.Frame):
    def __init__(self, parent, values: dict[str, str]):
        super().__init__(parent)
        self.project = tk.StringVar(value=values.get("project", ""))
        self.godot = tk.StringVar(value=values.get("godot", "godot"))
        source = Path(values.get("source", "")).expanduser()
        candidate = source.parent / "model_specs.json" if source.is_file() else None
        self.folder = tk.StringVar(value=str(source.parent) if candidate and candidate.is_file() else "")
        self.confirm = tk.BooleanVar(value=False)
        self.validated = False
        self.validated_roles = []
        self.available_roles = []
        self.loaded_folder = ""
        self.busy = False
        self.events: queue.Queue = queue.Queue()
        self._build()
        self.after(120, self._poll)

    def _build(self):
        main = ttk.Frame(self, padding=16)
        main.pack(fill="both", expand=True)
        ttk.Label(main, text="自动读取 model_specs.json → 按需导入电脑设备",
                  font=("Microsoft YaHei UI", 15, "bold")).pack(anchor="w")
        ttk.Label(main, text="清单支持 1～4 件基础设备，可以选择本次需要替换的设备；失败时整批恢复。",
                  foreground="#666666").pack(anchor="w", pady=(4, 12))
        fields = ttk.Frame(main)
        fields.pack(fill="x")
        fields.columnconfigure(1, weight=1)
        for i, (name, value, kind) in enumerate([
            ("Godot 项目根目录", self.project, "folder"),
            ("Godot 4.6 可执行文件", self.godot, "exe"),
            ("模型文件夹", self.folder, "folder"),
        ]):
            ttk.Label(fields, text=name, width=21).grid(row=i, column=0, sticky="w", pady=5)
            ttk.Entry(fields, textvariable=value).grid(row=i, column=1, sticky="ew", padx=8)
            ttk.Button(fields, text="浏览…", command=lambda v=value, k=kind: self._browse(v, k)).grid(row=i, column=2)
        ttk.Label(main, text="自动查找：模型文件夹 / model_specs.json（无需逐项输入尺寸）").pack(anchor="w", pady=(10, 7))
        row = ttk.Frame(main)
        row.pack(fill="x", pady=8)
        self.preview_button = ttk.Button(row, text="1. 检查所选设备", command=self._preview)
        self.preview_button.pack(side="left", padx=(0, 12))
        self.publish_button = ttk.Button(row, text="2. 导入所选设备", command=self._publish, state="disabled")
        self.publish_button.pack(side="left")
        ttk.Checkbutton(row, text="确认已关闭 Godot、游戏并备份项目", variable=self.confirm,
                        command=self._controls).pack(side="left", padx=(14, 0))
        ttk.Label(main, text="预览及执行日志", font=("Microsoft YaHei UI", 10, "bold")).pack(anchor="w", pady=(12, 4))
        self.log = tk.Text(main, wrap="word", font=("Consolas", 10))
        self.log.pack(fill="both", expand=True)
        for value in (self.project, self.godot):
            value.trace_add("write", lambda *_: self._invalidate())
        self.folder.trace_add("write", lambda *_: self._folder_changed())
        if self.folder.get():
            self._refresh_models()

    def _browse(self, target, kind):
        if kind == "folder":
            value = filedialog.askdirectory(parent=self)
        else:
            value = filedialog.askopenfilename(parent=self, title="选择 Godot 程序",
                                               filetypes=[("程序", "*.exe"), ("所有文件", "*")])
        if value:
            target.set(value)

    def _spec(self):
        return str(Path(self.folder.get().strip()).expanduser() / "model_specs.json")

    def _write(self, message):
        self.log.insert("end", message + "\n")
        self.log.see("end")

    def _invalidate(self):
        self.validated = False
        self.validated_roles = []
        self._controls()

    def _controls(self):
        self.publish_button["state"] = "normal" if self.validated and self.confirm.get() and not self.busy else "disabled"
        self.preview_button["state"] = "disabled" if self.busy else "normal"

    def _preview(self):
        try:
            self._write("\n======== 批量导入预览 ========")
            roles = self._selected_roles()
            self._write(preview_batch(self.project.get().strip(), self.godot.get().strip(), self._spec(), selected_roles=roles))
            self.validated_roles = roles
            self.validated = True
            self._controls()
        except (PublishError, OSError, ValueError) as exc:
            self.validated = False
            self._controls()
            self._write("预检失败：" + str(exc))
            messagebox.showerror("批量预检失败", str(exc), parent=self)

    def _publish(self):
        if not self.validated or not self.confirm.get():
            return
        roles = self._selected_roles()
        if roles != self.validated_roles:
            self._invalidate()
            messagebox.showerror("需重新预检", "所选设备已发生变化，请重新检查", parent=self)
            return
        if not messagebox.askyesno("最终确认", f"确认替换所选 {len(roles)} 件电脑设备吗？\n将备份并覆盖模型和设备参数；任一失败整批恢复。",
                                   parent=self):
            return
        project, godot, spec = self.project.get().strip(), self.godot.get().strip(), self._spec()
        self.busy = True
        self._controls()

        def worker():
            try:
                result = publish_batch(project, godot, spec, log=lambda s: self.events.put(("log", s)), selected_roles=roles)
                self.events.put(("success", result))
            except Exception as exc:
                self.events.put(("error", str(exc)))
        threading.Thread(target=worker, daemon=True).start()

    def _poll(self):
        if not self.winfo_exists():
            return
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "log":
                    self._write(payload)
                else:
                    self.busy = False
                    self.validated = False
                    self._controls()
                    if kind == "success":
                        self._write("成功：已导入 " + str(payload["count"]) + " 件；备份：" + payload["backup"])
                        messagebox.showinfo("完成", f"已导入 {payload['count\']} 件设备。请在 Godot 检查屏幕和场景位置。", parent=self)
                    else:
                        self._write("批量发布失败：" + payload)
                        messagebox.showerror("导入中断", payload, parent=self)
        except queue.Empty:
            pass
        self.after(120, self._poll)
