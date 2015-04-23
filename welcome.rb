#!/usr/bin/env ruby

require 'rubygems'
require 'colorize'
require 'artii'

a = Artii::Base.new :font => 'small'
puts a.asciify(" Entcom ").light_blue
puts a.asciify(" Enterprise ").red
puts a.asciify(" v . 0 . 1 ").light_blue

ip = `ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk '{ print $2 }' | awk -F: '{ print $2 }'`.chomp
mac = `ifconfig eth0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`.chomp
bcast = `ifconfig | grep "Bcast" | grep -v "127.0.0.1" | awk '{ print $3 }' | awk -F: '{ print $2 }'`.chomp
smask = `ifconfig | grep "Bcast" | grep -v "127.0.0.1" | awk '{ print $4 }' | awk -F: '{ print $2 }'`.chomp
gateway = `ip route | awk '/default/ { print $3 }'`.chomp

puts "\nIP Address: #{ip}"
puts "MAC Address: #{mac}"
puts "Broadcast: #{bcast}"
puts "Subnet Mask: #{smask}"
puts "Gateway: #{gateway}"

dhcp = `grep dhcp /etc/network/interfaces` != ""
dns_file = File.read(File.join File.dirname(__FILE__), "dns.txt").chomp
dns = dns_file.length > 0 ? dns_file : false

puts "\nChoose from the following options:"
puts "1) Configure Static Networking#{" [selected]" unless dhcp}"
puts "2) Enable DHCP#{" [selected]" if dhcp}"
puts "3) Configure DNS#{" [#{dns}]" if dns} "
puts "4) Reboot"
puts "5) Shutdown"

def gets_or_default(default)
	r = gets.chomp
	r == "" ? default : r
end

def reboot
	puts "Rebooting..."
	`reboot`
	sleep 10
end

def write_config(static_opts={})
	s = if static_opts[:dhcp]
		<<-eos
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
  #{"dns-nameservers #{static_opts[:dns]}" if static_opts[:dns]}
		eos
	else
		<<-eos
auto lo
iface lo inet loopback

auto eth0
  iface eth0 inet static
  address #{static_opts[:ip]}
  netmask #{static_opts[:smask]}
  gateway #{static_opts[:gateway]}
  broadcast #{static_opts[:bcast]}
  #{"dns-nameservers #{static_opts[:dns]}" if static_opts[:dns]}
		eos
	end

	File.open("/etc/network/interfaces","w") {|f| f.write s }
end

def ask_to_reboot
	print "New settings applied. Restart? (y/n) "
	if gets.chomp == "y"
		reboot
	end
end

while true
	print "\n? "
	case gets.chomp.to_i
	when 1
		puts "Configuring static networking..."
		print "IP Address (#{ip}): "
		new_ip = gets_or_default ip

		print "Subnet Mask (#{smask}): "
		new_smask = gets_or_default smask

		print "Broadcast Address (#{bcast}): "
		new_bcast = gets_or_default bcast

		print "Gateway IP: (#{gateway}): "
		new_gateway = gets_or_default gateway

		write_config ip: new_ip, smask: new_smask, bcast: new_bcast,
			gateway: new_gateway, dns: dns

		ask_to_reboot
	when 2
		puts "Enabling DHCP..."
		#`dhclient eth0`
		write_config dhcp: true, dns: dns
		ask_to_reboot
	when 3
		puts "DNS Settings..."
		new_dns = []
		print "Primary name server: "
		new_dns.push gets.chomp
		print "Secondary name server (leave blank for none): "
		new_dns.push gets.chomp
		new_dns *= ' '
		write_config dhcp: dhcp, dns: new_dns
		File.open('dns.txt','w'){|f| f.write new_dns }
		ask_to_reboot
	when 4
		reboot
	when 5
		puts "Shutting down..."
		`poweroff`
		sleep 10
	end
end
