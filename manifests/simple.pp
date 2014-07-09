# Keepalived module by James
# Copyright (C) 2012-2013+ James Shubin
# Written by James Shubin <james@shubin.ca>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class keepalived::simple(	# TODO: turn into a type with $name as the group
	$ip = '',	# you can specify which ip address to use (if multiple)
	$vip = '',
	$shorewall = true,
	$zone = 'net',		# TODO: allow for a list of zones
	#$allow = 'all',	# TODO: allow for a list of ip's per zone
	$password = ''	# if empty, puppet will attempt to choose one magically
) {

	include keepalived::vardir
	#$vardir = $::keepalived::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::keepalived::vardir::module_vardir, '\/$', '')

	# add this part too :)
	class { '::keepalived':
		start => true,
		shorewall => $shorewall,
	}

	# NOTE: this $group variable is in here early in case we add in groups!
	#$group = "${name}"	# TODO
	$group = 'keepalived'

	$valid_ip = "${ip}" ? {
		'' => "${::keepalived_host_ip}" ? {	# smart fact...
			'' => "${::ipaddress}",		# puppet picks!
			default => "${::keepalived_host_ip}",	# smart
		},
		default => "${ip}",			# user selected
	}
	if "${valid_ip}" == '' {
		fail('No valid IP exists!')
	}

	if ! ($vip =~ /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/) {
		fail('You must specify a valid VIP to use with keepalived.')
	}

	file { "${vardir}/simple/":
		ensure => directory,	# make sure this is a directory
		recurse => true,	# recurse into directory
		purge => true,		# purge unmanaged files
		force => true,		# purge subdirs and links
		require => File["${vardir}/"],
	}

	# store so that a fact can figure out the interface and cidr...
	file { "${vardir}/simple/ip":
		content => "${valid_ip}\n",
		owner => root,
		group => root,
		mode => 600,	# might as well...
		ensure => present,
		require => File["${vardir}/simple/"],
	}

	# NOTE: this is a tag to protect the pass file...
	file { "${vardir}/simple/pass":
		content => "${password}" ? {
			'' => undef,
			default => "${password}",
		},
		owner => root,
		group => root,
		mode => 600,	# might as well...
		ensure => present,
		require => File["${vardir}/simple/"],
	}

	# NOTE: $name here should probably be the fqdn...
	@@file { "${vardir}/simple/pass_${fqdn}":
		content => "${::keepalived_simple_pass}\n",
		tag => "keepalived_simple_${group}",
		owner => root,
		group => root,
		mode => 600,
		ensure => present,
	}

	File <<| tag == "keepalived_simple_${group}" |>> {	# collect to make facts
	}

	# this figures out the interface from the $valid_ip value
	$if = "${::keepalived_simple_interface}"		# a smart fact!
	$cidr = "${::keepalived_simple_cidr}"			# even smarter!
	$p = "${::keepalived_simple_password}"			# combined fact
	# this fact is sorted, which is very, very important...!
	$fqdns_fact = "${::keepalived_simple_fqdns}"	# fact !
	$fqdns = split($fqdns_fact, ',')		# list !

	if "${if}" != '' and "${cidr}" != '' and "${p}" != '' {

		$vrrpname = inline_template('<%= "VI_"+@group.upcase %>')	# eg: VI_LOC
		keepalived::vrrp { "${vrrpname}":
			state => "${fqdns[0]}" ? {	# first in list
				'' => 'MASTER',		# list is empty
				"${fqdn}" => 'MASTER',	# we are first!
				default => 'BACKUP',	# other in list
			},
			interface => "${if}",
			mcastsrc => "${valid_ip}",
			# TODO: support configuring the label index!
			# label ethX:1 for first VIP ethX:2 for second...
			ipaddress => "${vip}/${cidr} dev ${if} label ${if}:1",
			# FIXME: this limits puppet-keepalived to 256 hosts maximum
			priority => inline_template("<%= 255 - (@fqdns.index('${fqdn}') or 0) %>"),
			routerid => 42,	# TODO: support configuring it!
			advertint => 3,	# TODO: support configuring it!
			password => "${p}",
			group => "keepalived_${group}",
			watchip => "${vip}",
			shorewall_zone => $shorewall ? {
				'' => unset,
				false => unset,
				'false' => unset,
				default => "${zone}",				
			},
			shorewall_ipaddress => $shorewall ? {
				'' => unset,
				false => unset,
				'false' => unset,
				default => "${valid_ip}",
			},
		}
	}
}

# vim: ts=8
