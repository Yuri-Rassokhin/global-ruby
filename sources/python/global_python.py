import json
import inspect
import ast
import paramiko
import os
import uuid
import textwrap

class GlobalPython:
    _instance = None

    def __init__(self):
        self.method_hosts = {}          # func_name -> current_host
        self.original_methods = {}      # func_name -> { func: function, globals: dict }
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

        if func_name not in self.original_methods:
            self.original_methods[func_name] = {
                "func": func,
                "globals": inspect.getclosurevars(func).globals
            }

        def remote_wrapper(*args, **kwargs):
            current_host = self.method_hosts[func_name]
            return self.run(func_name, current_host, *args)

        globals()[func_name] = remote_wrapper
        self.landed_methods.add(func_name)

    def run_now(self, func, host, *args):
        self.land(func, host)
        return globals()[func.__name__](*args)

    # ===============================
    # ==== INTERNAL =================
    # ===============================

    def _collect_dependencies(self, func_name):
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
                deps[call] = textwrap.dedent(
                    inspect.getsource(self.original_methods[call]["func"])
                )
        return deps

    def _serialize_context(self, func_name):
        context = self.original_methods[func_name]["globals"]
        serialized = {}
        for k, v in context.items():
            try:
                json.dumps(v)
                serialized[k] = v
            except TypeError:
                continue
        return serialized

    def _execute_remotely(self, func_name, host, *args):
        func = self.original_methods[func_name]["func"]
        func_source = textwrap.dedent(inspect.getsource(func))  # ✅ правильные отступы
        deps = self._collect_dependencies(func_name)
        context = self._serialize_context(func_name)

        context_lines = "\n".join(f"{k} = {json.dumps(v)}" for k, v in context.items())
        deps_code = "\n".join(deps.values())
        args_str = ", ".join(json.dumps(a) for a in args)

        # ✅ функции определяем на верхнем уровне, try только для вызова
        remote_script = f"""
import json
import sys
from io import StringIO
import traceback

output_stream = StringIO()
original_stdout = sys.stdout
original_stderr = sys.stderr
sys.stdout = output_stream
sys.stderr = output_stream

{context_lines}

{deps_code}

{func_source}

result = None
try:
    result = {func_name}({args_str})
except Exception:
    output_stream.write("\\n[EXCEPTION]\\n" + traceback.format_exc())

sys.stdout = original_stdout
sys.stderr = original_stderr

print(json.dumps({{
    "output": output_stream.getvalue(),
    "result": result
}}))
"""

        # ✅ SSH-конфиг (как в Ruby)
        ssh_config = paramiko.SSHConfig()
        with open(os.path.expanduser("~/.ssh/config")) as f:
            ssh_config.parse(f)

        host_config = ssh_config.lookup(host)
        ssh_host = host_config.get("hostname", host)
        ssh_user = host_config.get("user", None)
        ssh_key = host_config.get("identityfile", [None])[0]

        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ssh_host, username=ssh_user, key_filename=ssh_key)

        tmp_file = f"/tmp/global_python_{uuid.uuid4().hex}.py"
        sftp = ssh.open_sftp()
        with sftp.file(tmp_file, "w") as f:
            f.write(remote_script)
        sftp.close()

        stdin, stdout, stderr = ssh.exec_command(f"python3 {tmp_file} && rm -f {tmp_file}")
        output = stdout.read().decode().strip()
        error_output = stderr.read().decode().strip()
        ssh.close()

        print(f"\n=== DEBUG on {host} ===")
        print(f"REMOTE SCRIPT:\n{remote_script}")
        print(f"STDOUT:\n{output}")
        print(f"STDERR:\n{error_output}")
        print("========================\n")

        if not output:
            return None

        data = json.loads(output)
        if data["output"]:
            print(data["output"].strip())
        return data["result"]


# ===============================
# ==== ДЕЛЕГАЦИЯ ===============
# ===============================

Global = GlobalPython.instance()

