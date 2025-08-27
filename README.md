# About Global Ruby

Global Ruby is a project implementing the GELP paradigm of software design:
Globally Extensible Local Programming.

This paradigm envisions a Ruby program as a flexible, global, continuously running entity capable of:

* **EXTENSIBILITY.** Ruby methods can be sent for execution to any machine in the world, as if they were executed locally.

* **HOTSWAP.** Dynamically patching a Ruby application at runtime.

* **VERSIONING.** Maintaining a global history of program state: variables, methods, and more.

* **DATAFLOW-BASED PROCESSING.** Ruby methods are triggered implicitly by data conditions, rather than explicit calls.

Global Ruby rethinks traditional boundaries in software development and removes outdated limitations like:

* *Where should this application run?*

* *When should it be started or stopped?*

* *How should remote parts of the system be orchestrated?*

With Global Ruby, you embrace the paradigm of **global computing** — an evolutionary step beyond distributed computing. Your program doesn’t just run somewhere — it lives everywhere, persistently.

# Use Cases

* Zero-effort head/worker or client/server architecture.

* Moving code to where the data is (next-gen Big Data).

* Automatic parallelization of bulk operations across multiple hosts.

* Automatic extension of an application to the most suitable compute resource (by RAM, cores, etc.).

# Unique Features

GELP keeps a Ruby program local and holistic from the developer's point of view — a single namespace, as if it were a conventional script. Behind the scenes, however, the program can extend its methods to remote hosts, including all their dependencies.

The “extensibility” paradigm is defined by two principles:

1. Zero modification: The code doesn't need to be written in a special way to become extensible.

2. Stateless extension: When a method is sent and executed on a remote URL, it leaves no trace — it disappears entirely from the remote host until the next time it is invoked.

