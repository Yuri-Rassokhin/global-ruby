#!/usr/bin/ruby

puts "Starting on #{`hostname`}"

def hw_info
  puts "Scanning #{`hostname`.strip}"
  `cat /proc/cpuinfo  | grep processor | wc -l`.to_i
end

cores = 0

cores += hw_info

puts cores



require_relative '../sources/global-ruby'


Global.land(binding, :hw_info, '130.162.50.40') # TODO: needed, but there must be default behaviour, landing to automatically picked node (maybe shape specified, too)

# The hub must be activated before the initial point of entry of the SW project. It's that simple.
cores += hw_info

puts cores
