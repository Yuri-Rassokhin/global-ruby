#!/usr/bin/ruby

# ADD THIS
require_relative './globalruby'
require_relative './runner'

$x = 2

@y = 3

def dep2
end

def dep
  dep2
  @y = @y * 5
end

def hello(arg)
  dep
  puts "Hello! It's #{@y*arg}"
end

#ADD THIS
hub = Global::Ruby.instance

# YOU CAN RUN YOUR METHODS USING RUNNER'S CONTEXT
puts run!(hub, :hello, @y+2)

# YOU CAN RUN YOUR METHODS USING CURRENT CONTEXT
puts hub.run(binding, :hello, @y+2)

