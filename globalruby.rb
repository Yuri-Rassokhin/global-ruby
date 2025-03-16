module Global

require 'json'
require 'net/ssh'
require 'method_source'
require 'shellwords'
require 'ripper'
require 'set'
require 'singleton'

class Landscape
  include Singleton

  # by default, the world landscape equals to localhost
  def initialize
    # The one and only set of all nodes in the world
    @@world = Set.new('127.0.0.1')
    # Those world nodes that are assigned names, for convenience
    @@nodes = {
      'localhost': '127.0.0.1'
    }
    # Methods that are landed onto a node, 1:N relation
    # Every method is associated with a group of nodes where it is landed on
    # When the method is invoked, it runs on all such nodes
    # Global Ruby assesses if it is safe to run the method on its nodes in parallel
    # If it safe, it marks the method's group as "parallelizable"
    # Otherwise, TODO
    # NOTE: it is unique opportunity of Global Ruby's approach to detect potential race conditions
    # ... and therefore decide where instances of a method can run in parallel or not
    @@methods = {}
  end

  # add a new node to the world landscape
  def add(url, name = nil)
    @@world << url
    @@nodes[url] = name if name
  end
end

class Communicator
  def initialize
  end
  # Abstract class representing communication between landed chunks
  # This class must be overriden by specific communicators: SSH, HTTP, Object Storage, and so forth
end

class Ruby
  include Singleton

  @@debug = false

  def self.debug
    @@debug == true
  end

  def self.debug=(value)
    @@debug = value
  end

  def debug
    @@debug
  end

  def debug=(value)
    @@debug = value
  end

  def initialize

    @@user = `whoami`.chomp
    @@host = '127.0.0.1'
    @original_methods = {}
    @@landed_methods = Set.new
    # landscape is a definition of hosts where given method would uun on, when called
    @@landscape = nil
  end

  def configure(user: nil, host: nil)
    @@user = user if user
    @@host = host if host
  end

  def run(context, method, *args)
    execute_remotely(method, context, *args)
  end

def land(context, target = nil, method_name, host)

  if @@landed_methods.include?(method_name)
    @@host = host
    return
  end

  klass = target.nil? ? Object : target

  # Retrieve the original method
  original_method = klass.instance_method(method_name)

  # Store the original method and context for later use
  @@original_methods ||= {}
  @@original_methods[method_name] = { method: original_method, context: context }

  # Proactively resolve dependencies and populate original methods
  full_dependency_chain(method_name).each do |dependency|
    unless @@original_methods.key?(dependency)
      method_obj = Object.instance_method(dependency)
      @@original_methods[dependency] = { method: method_obj, context: context }
    end
  end

  # Reference the current instance
  hub_instance = self

  # Redefine the method locally
  klass.define_method(method_name) do |*args, &block|
    # Execute the method remotely and capture the result
    remote_result = hub_instance.run(context, method_name, *args, &block)

    # Log or display the captured output if needed
    captured_output = remote_result["output"]

    # Update dependent variables in the local context
    updated_variables = remote_result["variables"]
    updated_variables.each do |key, value|
      if key.start_with?("@")
        context.eval("#{key} = #{value.inspect}")
      end
  end
    @@landed_methods.add(method_name)
     puts remote_result["output"] if remote_result["output"]
     remote_result["result"]
#    remote_result["output"]
end
end

private

def method_dependencies(method)
  # Get the source code of the method
  source = method.source

  # Parse the source code to identify method calls
  dependencies = []
  sexp = Ripper.sexp(source)

  # Traverse the parsed S-expression
  traverse_sexp(sexp) do |node|
    # Look for method calls (:vcall or :call)
    if node.is_a?(Array) && node[0] == :vcall
      # Extract the method name
      dependencies << node[1][1].to_sym if node[1].is_a?(Array) && node[1][0] == :@ident
    elsif node.is_a?(Array) && node[0] == :call
      dependencies << node[2][1].to_sym if node[2].is_a?(Array) && node[2][0] == :@ident
    end
  end
  dependencies.uniq
end

def traverse_sexp(sexp, &block)
  return unless sexp.is_a?(Array)

  yield(sexp)
  sexp.each { |node| traverse_sexp(node, &block) }
end

def full_dependency_chain(method_name, seen_methods = Set.new)
  # Prevent infinite loops for cyclic dependencies
  return [] if seen_methods.include?(method_name)

  seen_methods.add(method_name)

  # Check if the method is already in @original_methods
  unless @@original_methods.key?(method_name)
    # Attempt to retrieve the method dynamically
    begin
      method_obj = Object.instance_method(method_name)
      context = binding # Default to the current binding
      @@original_methods[method_name] = { method: method_obj, context: context }
    rescue NameError
      # Skip if the method does not exist
      return []
    end
  end

  # Retrieve the method object and context from original methods
  method_info = @@original_methods[method_name]
  method_obj = method_info[:method]
  context = method_info[:context]

  # Analyze direct dependencies of the method
  dependencies = method_dependencies(method_obj)

  # Recursively find dependencies of dependencies
  full_chain = dependencies.flat_map do |dependency|
    full_dependency_chain(dependency, seen_methods)
  end

  [method_name] + full_chain.uniq
end

def output_dependency_chain(method_name)
  result = ""
  chain = full_dependency_chain(method_name)

  chain.each do |dependency|
    begin
      # Retrieve the method object from original methods
      method_info = @@original_methods[dependency]
      method_obj = method_info[:method]

      # Append the source of the method
      result << method_obj.source + "\n"
    rescue => e
      result << "# Error processing dependency #{dependency}: #{e.message}\n"
    end
  end
  result
end

def get_context_variables(context)
  dependencies = {}

  # add global variables
 global_vars = global_variables.map do |var|
   [var, eval(var.to_s, context)]
  end

  # add instance variables
  instance_vars = context.eval('instance_variables').map do |var|
    [var, context.eval(var.to_s)]
  end

  # add class variables (if context self is a class or module)
  class_vars = if context.eval('self').is_a?(Class) || context.eval('self').is_a?(Module)
                context.eval('self.class_variables').map do |var|
                  [var, context.eval("self.class_variable_get(:#{var})")]
                end
              else
                []
              end

  # Add constants (if context self is a class or module)
  constants = if context.eval('self').is_a?(Class) || context.eval('self').is_a?(Module)
              context.eval('self.constants').map do |const|
                [const, context.eval("self.const_get(:#{const})")]
              end
            else
              []
            end

  # combine all variables into dependencies
  # NOTE and TODO: global_vars are excluded for the sake of performance and stability 
  dependencies =  instance_vars + class_vars + constants
  dependencies = dependencies.to_h
end

# Serialize a Ruby method and its dependencies
def serialize_method(method_name, caller_context)
  # Retrieve the original method object and context
  method_info = @@original_methods[method_name]
  method_obj = method_info[:method]
  context = method_info[:context] || caller_context

  # Extract the method source code
  method_body = method_obj.source

  # Collect instance and global variables from the caller context
  variables = get_context_variables(context)

  # Return serialized method and dependencies
  {
    method_name: method_name,
    method_body: method_body,
    dependencies: variables
  }.to_json
end

def add_parameter_to_method(method_body, new_param)
  # Match the method definition line, accounting for missing parentheses
  method_body.sub(/def\s+(\w+)(\(([^)]*)\))?/) do |match|
    method_name = Regexp.last_match(1)
    params = Regexp.last_match(3) || "" # Default to an empty string if no params
    # Add the new parameter
    updated_params = params.empty? ? new_param : "#{params}, #{new_param}"
    "def #{method_name}(#{updated_params})"
  end
end

# Execute the serialized method on a remote host
def execute_remotely(method_name, context, *args)
  # Serialize the method and its dependencies
  serialized_data = serialize_method(method_name, context)
  data = JSON.parse(serialized_data)

  # Collect serialized dependencies (instance/global variables)
  deps = ""
  data["dependencies"].each do |key, value|
    deps << "#{key} = #{value.inspect}\n" if key.start_with?("@", "@@", "$")
  end

  # Collect all method definitions in the dependency chain
  method_definitions = output_dependency_chain(method_name)

  # Serialized arguments for the method call
  serialized_args = args.map(&:inspect).join(", ")

  # Generate the remote script
  remote_script = <<~RUBY
    require 'json'
    require 'stringio'

    # Capture both STDOUT and STDERR into a single stream
    output_stream = StringIO.new
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = output_stream
    $stderr = output_stream

    begin
    # Serialized dependencies
    #{deps}

    # Serialized method definitions
    #{method_definitions}

    # Execute the method with arguments
    result = #{method_name}(#{serialized_args})
    # Capture updated state of dependent variables
    updated_variables = {
      #{data["dependencies"].keys.map { |key| "\"#{key}\": #{key}" }.join(", ")}
    }
    ensure
    # Restore STDOUT and STDERR
    $stdout = original_stdout
    $stderr = original_stderr
    end
    # Combine the captured output with the result and variables
    output = {
      variables: updated_variables,
      output: output_stream.string.strip, # Captured "natural" output
      result: result
    }
    puts output.to_json
  RUBY

  dbg("Remote Script:\n#{remote_script}")

  # Execute the script on the remote host
  output = ""
  Net::SSH.start(@@host, @@user) do |ssh|
    output = ssh.exec!("ruby -e #{Shellwords.escape(remote_script)}")
  end
  JSON.parse(output.strip)
end

def dbg(text)
  puts text if @@debug
end

end

end

