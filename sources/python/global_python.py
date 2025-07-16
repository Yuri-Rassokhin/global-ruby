import json
import inspect
import ast
import paramiko
import types

class GlobalPython:
    _instance = None

    def __init__(self):
        self.method_hosts = {}          # method_name -> current_host
        self.original_methods = {}      # method_name -> { func: function, globals: dict }
        self.landed_methods = set()

    @classmethod
    def instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def run(self, func_name, host, *args):
        return self._execute_remotely(func_name, host, *args)

    def land(self, func, host):
        func_name = func.__name__
        self.method_hosts[func_name] = host

        # ✅ сохраняем оригинал только один раз
        if func_name not in self.original_methods:
            self.original_methods[func_name] = {
                "func": func,
                "globals": inspect.getclosurevars(func).globals
            }

        # ✅ заменяем локальную функцию на "приземлённую"
        def remote_wrapper(*args, **kwargs):
            current_host = self.method_hosts[func_name]
            return self.run(func_name, current_host, *args)

        globals()[func_name] = remote_wrapper
        self.landed_methods.add(func_name)

    def run_now(self, func, host, *args):
        self.land(func, host)
        return globals()[func.__name__](*args)

    # ===============================
    # ==== INTERNAL ================
    # ===============================

    def _collect_dependencies(self, func_name):
        """Рекурсивно собираем зависимости функций (упрощённый аналог full_dependency_chain)."""
        func = self.original_methods[func_name]["func"]
        source = inspect.getsource(func)
        tree = ast.parse(source)
        calls = set()

        class CallVisitor(ast.NodeVisitor):
            def visit_Call(self, node):
                if isinstance(node.func, ast.Name):
                    calls.add(node.func.id)
                self.generic_visit(node)

        CallVisitor().visit(tree)

        deps = {}
        for call in calls:
            if call in self.original_methods:
                deps[call] = inspect.getsource(self.original_methods[call]["func"])
        return deps

    def _serialize_context(self, func_name):
        """Сериализация глобальных переменных."""
        context = self.original_methods[func_name]["globals"]
        serialized = {}
        for k, v in context.items():
            try:
                json.dumps(v)  # проверка сериализуемости
                serialized[k] = v
            except TypeError:
                continue
        return serialized

    def _execute_remotely(self, func_name, host, *args):
        func = self.original_methods[func_name]["func"]
        func_source = inspect.getsource(func)
        deps = self._collect_dependencies(func_name)
        context = self._serialize_context(func_name)

        # генерируем удалённый скрипт
        context_lines = "\n".join(f"{k} = {json.dumps(v)}" for k, v in context.items())
        deps_code = "\n".join(deps.values())
        args_str = ", ".join(json.dumps(a) for a in args)

        remote_script = f"""
import json
import sys
from io import StringIO
import builtins

output_stream = StringIO()
sys.stdout = output_stream
sys.stderr = output_stream

{context_lines}

{deps_code}

{func_source}

result = {func_name}({args_str})

print(json.dumps({{
    "output": output_stream.getvalue(),
    "result": result
}}))
"""
        # SSH-запуск Python-скрипта
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(host)
        stdin, stdout, stderr = ssh.exec_command(f"python3 -c {json.dumps(remote_script)}")
        output = stdout.read().decode().strip()
        ssh.close()

        data = json.loads(output)
        if data["output"]:
            print(data["output"].strip())
        return data["result"]


# ===============================
# ==== ДЕЛЕГАЦИЯ ===============
# ===============================

Global = GlobalPython.instance()

