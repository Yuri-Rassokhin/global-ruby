# About Global Ruby

This project aims for implementation of GELP paradigm of software design: "Globally Extensible Local Programming".

The paradigm envisions Ruby program as a flexible, global, continously running entity capable of
* **EXTENSIBILITY.** The program sends its methods for execution to any machine in the world, as if the method executed locally.
* **HOTSWAP.** Dynamic patching of a Ruby application at runtime.
* **VERSIONING.** Global history of the status of program objects (variables, method, etc).
* **DATAFLOW-BASED PROCESSING.** Activation of Ruby methods implicitly triggered by data conditions rather than explicit calling.

Global Ruby is on a mission to rethink the approach for software development and remove old-fashined restrictions:
* What machine to run the application on?..
* When to stop and start the application?..
* How to orchestrate remote parts of the application?..

With Global Ruby, you adopt the paradigm of **global computing**, as the next evolutionary step after distributed computing. Your program will not just run in any individual location - rather, it will endlessly live in the entire world.

# Use Cases

1. Zero effort for Head/Worker or Client/Server design.
2. Moving code close to data (next-gen BigData).
3. Automated parallelization of bulk operations by involving multiple hosts (next-gen BigData).
4. Automated extension of an application to the most relevant machine (by RAM, by number of cores, etc).

# Unique Features

GELP keep Ruby program local and holistic for the developer - one namespace, as if it was conventional local script. Transparently for the developer, the program can "extend" its methods - that is, assign individual methods (along with their execution dependencies) on any remote compute resource.

The paradigm of "extension" or "extensible code" assumes
* No modifications for the code to be extensible.
* Stateless extensibility: when a method extends to remote URL and executes, it completely disappears from the URL (till its next invokation on the same URL).

