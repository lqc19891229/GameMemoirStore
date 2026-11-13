"""Furniture Publisher desktop GUI. Run with Python 3.10+ (Tkinter)."""
from __future__ import annotations
import json
import queue
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from pathlib import Path
from publisher_core import GROUPS, TYPES, GROUP_TYPES, Item, PublishError, preview, publish
from hardware_ui import HardwareWindow

GROUP_LABELS = {f"{v} ({k})": k for k, v in GROUPS.items()}


class PublisherApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("游戏回忆录 · 资产发布器 v2.0")
        self.geometry("1000x840")
        self.minsize(790, 680)
        self.vars = {key: tk.StringVar() for key in ("project", "godot", "source", "item_id", "name", "price", "description")}
        self.vars["godot"].set("godot")
        self.vars["price"].set("100")
        self.group = tk.StringVar(value="座椅 (seating)")
        self.kind = tk.StringVar(value="电脑椅 (office_chair)")
        self.mount = tk.BooleanVar(value=False)
        self.support = tk.StringVar(value="[]")
        self.confirm = tk.BooleanVar(value=False)
        self.events: queue.Queue = queue.Queue()
        self.is_running = False
        self._build()
        self.after(120, self._poll)

    def _build(self) -> None:
        main = ttk.Frame(self, padding=16)
        main.pack(fill="both", expand=True)
        ttk.Label(main, text="GLB → 家具 / 电脑设备发布", font=("Microsoft YaHei UI", 16, "bold")).pack(anchor="w")
        ttk.Label(main, text="下方保留原有新增家具功能；电脑设备可通过独立窗口替换现有 GLB 和真实尺寸。", foreground="#666666").pack(anchor="w", pady=(2, 8))
        ttk.Button(main, text="电脑设备模型发布 / 替换现有型号…", command=self._open_hardware).pack(anchor="w", pady=(0, 12))
        form = ttk.Frame(main)
        form.pack(fill="x")
        form.columnconfigure(1, weight=1)
        for row, (key, label, browse) in enumerate([
            ("project", "Godot 项目目录", "dir"), ("godot", "Godot 4.6 可执行文件", "exe"),
            ("source", "成品 GLB 文件", "glb"), ("item_id", "商品 ID / 场景名", ""),
            ("name", "商店显示名称", ""), ("price", "售价（点）", ""),
            ("description", "商品说明", "")
        ]):
            ttk.Label(form, text=label, width=19).grid(row=row, column=0, sticky="w", pady=5)
            ttk.Entry(form, textvariable=self.vars[key]).grid(row=row, column=1, sticky="ew", padx=(8, 6), pady=5)
            if browse:
                ttk.Button(form, text="浏览…", width=11, command=lambda k=key, b=browse: self._browse(k, b)).grid(row=row, column=2, pady=5)
        select = ttk.Frame(main)
        select.pack(fill="x", pady=(8, 4))
        ttk.Label(select, text="一级分类", width=17).grid(row=0, column=0, sticky="w")
        self.groups = ttk.Combobox(select, values=list(GROUP_LABELS), textvariable=self.group, state="readonly", width=24)
        self.groups.grid(row=0, column=1, sticky="w", padx=(0, 20))
        self.groups.bind("<<ComboboxSelected>>", lambda _e: self._update_types())
        ttk.Label(select, text="二级类型").grid(row=0, column=2, sticky="w")
        self.types = ttk.Combobox(select, textvariable=self.kind, state="readonly", width=28)
        self.types.grid(row=0, column=3, sticky="w", padx=8)
        self._update_types()
        ttk.Checkbutton(main, text="此家具可放到其他家具的承载面上（杯子、书本、小摆件）", variable=self.mount).pack(anchor="w", pady=5)
        ttk.Label(main, text="可承载其他物品的表面（书桌/书架，可选 JSON；与上面的勾选含义不同）").pack(anchor="w", pady=(9, 3))
        ttk.Entry(main, textvariable=self.support).pack(fill="x")
        ttk.Label(main, text='示例：[ {"id":"top", "x":0, "y":0.75, "z":0, "width":1.0, "depth":0.5} ]', foreground="#666666").pack(anchor="w", pady=(2, 6))
        controls = ttk.Frame(main)
        controls.pack(fill="x", pady=8)
        self.preview_btn = ttk.Button(controls, text="1. 检查 / 预览改动", command=self._preview)
        self.preview_btn.pack(side="left", padx=(0, 10))
        self.publish_btn = ttk.Button(controls, text="2. 确认并自动导入上架", command=self._publish, state="disabled")
        self.publish_btn.pack(side="left", padx=(0, 10))
        ttk.Checkbutton(controls, text="已确认信息、备份项目且已关闭 Godot", variable=self.confirm, command=self._update_controls).pack(side="left")
        ttk.Label(main, text="执行预览 / 日志", font=("Microsoft YaHei UI", 11, "bold")).pack(anchor="w", pady=(8, 3))
        logframe = ttk.Frame(main)
        logframe.pack(fill="both", expand=True)
        self.log_text = tk.Text(logframe, wrap="word", font=("Consolas", 10), padx=10, pady=8)
        scroll = ttk.Scrollbar(logframe, orient="vertical", command=self.log_text.yview)
        self.log_text.configure(yscrollcommand=scroll.set)
        self.log_text.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        ttk.Label(main, text="注意：这是开发者工具，注册后仍需进入游戏验证购买、摆放、碰撞与读档。", foreground="#777777").pack(anchor="w", pady=(8, 0))
        for v in list(self.vars.values()) + [self.group, self.kind, self.support, self.mount]:
            v.trace_add("write", lambda *_: self._invalidate())
        self._preview_ok = False

    def _open_hardware(self) -> None:
        HardwareWindow(self, {key: self.vars[key].get() for key in ("project", "godot", "source")})

    def _browse(self, key: str, browse: str) -> None:
        if browse == "dir": path = filedialog.askdirectory(title="选择 GameMemoirStore 项目根目录")
        elif browse == "glb": path = filedialog.askopenfilename(filetypes=[("glTF Binary", "*.glb")])
        else: path = filedialog.askopenfilename(title="选择 Godot 4.6 可执行文件", filetypes=[("程序", "*.exe"), ("所有文件", "*")])
        if path:
            self.vars[key].set(path)
            if key == "source" and not self.vars["item_id"].get():
                self.vars["item_id"].set(Path(path).stem)

    def _update_types(self) -> None:
        group = GROUP_LABELS.get(self.group.get(), "seating")
        options = [f"{TYPES[k]} ({k})" for k in GROUP_TYPES[group]]
        self.types["values"] = options
        if self.kind.get() not in options:
            self.kind.set(options[0])

    def _invalidate(self) -> None:
        self._preview_ok = False
        if hasattr(self, "publish_btn"):
            self._update_controls()

    def _update_controls(self) -> None:
        self.publish_btn["state"] = "normal" if self._preview_ok and self.confirm.get() and not self.is_running else "disabled"
        self.preview_btn["state"] = "disabled" if self.is_running else "normal"

    def _item(self) -> Item:
        try: price = int(self.vars["price"].get().strip())
        except ValueError as exc: raise PublishError("价格必须为整数") from exc
        return Item(
            project=self.vars["project"].get().strip(), godot=self.vars["godot"].get().strip(),
            source=self.vars["source"].get().strip(), item_id=self.vars["item_id"].get().strip(),
            name=self.vars["name"].get().strip(), price=price,
            group=GROUP_LABELS.get(self.group.get(), ""),
            type=self.kind.get().split("(")[-1].rstrip(")"),
            description=self.vars["description"].get(),
            allow_surface_mount=self.mount.get(), support_surfaces=self.support.get(),
        )

    def _write(self, message: str) -> None:
        self.log_text.insert("end", message + "\n")
        self.log_text.see("end")

    def _preview(self) -> None:
        try:
            self._write("\n========== 发布预检 ==========")
            self._write(preview(self._item()))
            self._preview_ok = True
            self._update_controls()
        except (PublishError, OSError, ValueError) as exc:
            self._preview_ok = False
            self._update_controls()
            self._write("预检失败：" + str(exc))
            messagebox.showerror("预检失败", str(exc))

    def _publish(self) -> None:
        if not self._preview_ok or not self.confirm.get(): return
        item = self._item()
        if not messagebox.askyesno("最后确认", f"确认新增家具「{item.name}」并写入项目商品目录？\n\n现有商品和场景不会被覆盖。"): return
        self.is_running = True
        self._update_controls()
        def worker() -> None:
            try:
                result = publish(item, log=lambda line: self.events.put(("log", line)))
                self.events.put(("ok", result))
            except Exception as exc:
                self.events.put(("error", str(exc)))
        threading.Thread(target=worker, daemon=True).start()

    def _poll(self) -> None:
        try:
            while True:
                key, value = self.events.get_nowait()
                if key == "log": self._write(value)
                elif key == "ok":
                    self.is_running = False
                    self._preview_ok = False
                    self._update_controls()
                    self._write("\n已完成！下一个步骤：打开 Godot 检查场景，再在游戏商店进行购买/摆放测试。")
                    messagebox.showinfo("发布成功", "家具已添加到 GameMemoirStore 商品目录。\n请打开 Godot 和游戏进行人工验收。")
                elif key == "error":
                    self.is_running = False
                    self._preview_ok = False
                    self._update_controls()
                    self._write("\n发布未完成：" + value + "\n检查项目是否留有新增 GLB/场景，修复后再试；已存在文件不会覆盖。")
                    messagebox.showerror("发布中断", value)
        except queue.Empty:
            pass
        self.after(120, self._poll)


if __name__ == "__main__":
    PublisherApp().mainloop()
