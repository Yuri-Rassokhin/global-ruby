#!/usr/bin/env ruby
require 'net/ping'
require 'socket'
require 'timeout'
require 'net/ssh'

# Configuration
SUBNET = "192.168.1"  # Change to match your network
SSH_PORT = 22
PING_TIMEOUT = 1
SSH_TIMEOUT = 2
SSH_KEY_PATH = "~/.ssh/id_rsa"  # Change to your SSH private key
USERNAME = "your_user"  # Change to the SSH username
THREADS = 50  # Number of concurrent threads

# Output file for active SSH hosts
OUTPUT_FILE = "ssh_hosts.txt"
mutex = Mutex.new

# Clear output file
File.open(OUTPUT_FILE, 'w') {}

puts "Scanning subnet #{SUBNET}.0/24 with #{THREADS} concurrent threads..."

# Define worker queue
queue = Queue.new
(1..254).each { |i| queue.push("#{SUBNET}.#{i}") }

threads = THREADS.times.map do
  Thread.new do
    while !queue.empty?
      ip = queue.pop(true) rescue nil
      next unless ip

      # Ping check
      if Net::Ping::External.new(ip, nil, PING_TIMEOUT).ping?
        puts "Host #{ip} is online. Checking SSH..."

        # SSH Check using socket
        begin
          Timeout.timeout(SSH_TIMEOUT) do
            socket = TCPSocket.new(ip, SSH_PORT)
            socket.close
            puts "✔ SSH is available on #{ip}"

            # Attempt SSH login
            begin
              Net::SSH.start(ip, USERNAME, keys: [File.expand_path(SSH_KEY_PATH)], non_interactive: true) do |ssh|
                puts "✅ Successfully logged in to #{ip} as #{USERNAME}"
                mutex.synchronize { File.open(OUTPUT_FILE, 'a') { |f| f.puts ip } }
              end
            rescue => e
              puts "❌ SSH login failed for #{ip}: #{e.message}"
            end
          end
        rescue Timeout::Error, Errno::ECONNREFUSED
          puts "✘ SSH is not available on #{ip}"
        end
      end
    end
  end
end

# Wait for all threads to finish
threads.each(&:join)

puts "Scan complete. SSH-accessible hosts saved in #{OUTPUT_FILE}"


