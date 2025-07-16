import sys
sys.path.append("/home/yuri/global-ruby/sources/python")

from global_python import Global

def collect_info():
    with open("/proc/cpuinfo") as f:
        return sum(1 for line in f if "processor" in line)

hosts = ["127.0.0.1"]
#hosts = ["130.162.50.40", "127.0.0.1"]

total_cores = sum(Global.run_now(collect_info, host) for host in hosts)
print(f"Total cores on all hosts: {total_cores}")

