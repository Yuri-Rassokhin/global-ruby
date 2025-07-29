
require './sources/global-ruby'

def header
  puts "Scanning #{`hostname`.strip} with data = #{@data}..."
end

def collect_info
  header
  `cat /proc/cpuinfo  | grep processor | wc -l`.to_i
end

@data = 3

hosts = [ '127.0.0.1' ]
puts hosts.sum { |host| Global.run(binding, host, :collect_info) }
