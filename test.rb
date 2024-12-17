#!/usr/bin/ruby

puts "Starting on #{`hostname`}"

$x = 2

@y = 3

def dep2
  @y = @y +1
end

def dep
  dep2
  @y = @y * 5
end

def hello(arg)
  dep
  puts "Hello from #{`hostname`.strip}! It's #{@y * arg}"
end

puts "@y = #{@y}"
hello(@y+2)
puts "@y = #{@y}"

require_relative './globalruby'
require_relative './runner'

hub = Global::Ruby.instance
hub.configure(user: 'ubuntu', host: '130.162.50.40')
hub.debug = false

# Run given method in the context where hub was declared, on a previously configured host
# puts run!(hub, :hello, @y+2)

# Run given method in the current context on a previously configured host
# puts hub.run(binding, :hello, @y+2)

# Asssign given method to run on the specified host, when called

hub.land(binding, :hello, '130.162.50.40')

puts "@y = #{@y}"
puts hello(@y+2)
puts "@y = #{@y}"

puts hello(@y+2)

hub.land(binding, :hello, '127.0.0.1')

puts hello(@y+2)

