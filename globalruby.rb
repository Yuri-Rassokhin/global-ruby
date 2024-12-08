module Global

require 'json'
require 'net/ssh'
require 'method_source'
require 'shellwords'
require 'ripper'
require 'set'
require 'singleton'

class Ruby
  include Singleton

  def initialize
    @user = `whoami`
    @host = '127.0.0.1'
  end

  def configure(user:, host: nil)
    @user = user
    @host = host ? host : @host
#    @hosts = hosts ? (hosts.is_a?(Array) ? hosts : [ hosts ]) : nil
  end

  def run(context, method, *args)
    execute_remotely(method, context, *args)
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
      dependencies << node[1][1] if node[1].is_a?(Array) && node[1][0] == :@ident
    elsif node.is_a?(Array) && node[0] == :call
      dependencies << node[2][1] if node[2].is_a?(Array) && node[2][0] == :@ident
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

  # Get the method object
  method_obj = Object.instance_method(method_name)
  dependencies = method_dependencies(method_obj)

  # Recursively find dependencies of dependencies
  full_chain = dependencies.flat_map do |dependency|
    [dependency] + full_dependency_chain(dependency, seen_methods)
  end

  full_chain.uniq
end

def output_dependency_chain(method_name)
  result = ""
  chain = full_dependency_chain(method_name)
  chain.each do |dependency|
    method_obj = Object.instance_method(dependency)
    result << "#{method_obj.source}\n"
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
def serialize_method(method_name, context)
  # Use MethodSource to get the method body
  method_body = context.method(method_name).source
#  dependencies = context.local_variables.map do |var|
#    [var, context.local_variable_get(var)]
#  end.to_h
  variables = get_context_variables(context)
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
  host = @host
  user = @user
  serialized_data = serialize_method(method_name, context)
  # Build the Ruby script to execute remotely
  data = JSON.parse(serialized_data)
  deps = ""
#  call = ""
  updated_method = data["method_body"]
   data["dependencies"].each do |key, value|
      next unless key.start_with?("@", "@@", "$")
      deps << "#{key} = #{value.inspect} \n"
#       updated_method = add_parameter_to_method(updated_method, key)
#       if call == ""
#        call = "#{value.inspect}"
#       else
#        call << ", #{value.inspect}"
#      end
  end

  serialized_args = args.map(&:inspect).join(", ")

  remote_script = <<~RUBY
    #{output_dependency_chain(method_name)}
    #{deps}
    #{updated_method}
    result = #{data["method_name"]}(#{serialized_args})
    puts result
  RUBY

#  puts remote_script
  # Execute the script on the remote host and capture the output
  output = ""
  Net::SSH.start('127.0.0.1', 'opc') do |ssh|
    output = ssh.exec!("ruby -e #{Shellwords.escape(remote_script)}")
  end
  output.strip
end

end

end

