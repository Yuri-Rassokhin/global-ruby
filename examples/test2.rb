#!/usr/bin/ruby

def header
  puts "Scanning #{`hostname`.strip} with data = #{@data}..."
end

def collect_info
  header
  `cat /proc/cpuinfo  | grep processor | wc -l`.to_i
end

@data = 3

require_relative '../sources/global-ruby'

hosts = [ '130.162.50.40', '127.0.0.1' ]
puts hosts.sum { |host| Global.run(binding, host, :collect_info) }

