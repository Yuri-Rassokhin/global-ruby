
require './lib/global-ruby'

@prefix = "LOG"

def header2
  @prefix
end

def header
  puts header2 + ": " + "scanning #{`hostname`.strip} with variable #{@data}..."
end

def msg(text)
  puts "LOG: #{text}"
end

def collect_info
  header
  `cat /proc/cpuinfo  | grep processor | wc -l`.to_i
end

@data = 3

hosts = [ '127.0.0.1', '130.162.50.40' ] # Specify any SSH-accessible hosts
puts "Total cores: #{hosts.sum { |host| Global.run(binding, host, :collect_info) }}"

#hosts.each { |h| Global.run(binding, h, :collect_info) }
#hosts.each { |host| puts Global.run(binding, host, File.method(:exist?), "/tmp") }

