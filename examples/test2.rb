#!/usr/bin/ruby

def hw_info
  puts "scanning #{`hostname`.strip}..."
  `cat /proc/cpuinfo  | grep processor | wc -l`.to_i
end



require_relative '../sources/global-ruby'

hosts = [ '130.162.50.40', '127.0.0.1' ]
cores = 0

hosts.each { |h| Global.land(binding, :hw_info, h) and cores += hw_info }

puts "Total cores on all hosts: #{cores}"
