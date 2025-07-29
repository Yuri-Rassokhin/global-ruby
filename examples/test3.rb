#!/usr/bin/ruby

$cores = 0

def header
  puts "Hello!"
end

def get_infra
  header
  `cat /proc/cpuinfo | grep processor | wc -l`.to_i
end

require_relative '../sources/global-ruby'
hub = Global::Ruby.instance
hub.configure(user: 'ubuntu', host: '130.162.50.40')

$cores += get_infra

# move the method to the remote host
hub.land(binding, :get_infra, '130.162.50.40')

$cores += get_infra

puts "Total cores on the servers: #{$cores}"

