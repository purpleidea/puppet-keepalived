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

define keepalived::vrrp(
	$state = 'BACKUP',		# MASTER or BACKUP
	$nopreempt = false,		# nopreempt require BACKUP as $state
	$preempt_delay = 0,		# preempt_delay require BACKUP as $state
	$interface,
	$ipaddress,
	$routerid,
	$priority = '',			# prio is chosen automatically if unset
	$advertint = 1,
	$mcastsrc = '',
	$password,
	$trackprimary = true,		# for the dont_track_primary directive
	$trackif = [],
	$trackscript = [],		# list of script directives to track
	$group = 'default',		# to be used with autogrouping
	# the following options are for shorewall
	$shorewall = '',		# override global with true or false
	$shorewall_zone = '',		# manually override guess based on name
	$shorewall_ipaddress = '',	# for shorewall (blank allows all)
	$watchip = '',			# this can safely accept ipaddress/cidr
	$ensure = present
) {
	include keepalived

	if ( "${password}" == '' ) {
		fail("A valid password is required for the keepalived::vrrp[${name}] definition.")
	}

	if ( "${routerid}" == '' ) {
		fail("A valid routerid is required for the keepalived::vrrp[${name}] definition.")
	}

	$FW = '$FW'			# make using $FW in shorewall easier

	$conntrackd = $keepalived::conntrackd
	$bool_shorewall = $shorewall ? {
		true => true,				# force enable
		false => false,				# force disable
		#'' => $keepalived::shorewall,
		default => $keepalived::shorewall,	# use global
	}

	$instance = $name

	file { "/etc/keepalived/${instance}.vrrp":
		content => template('keepalived/keepalived.vrrp.erb'),
		owner => root,
		group => nobody,
		mode => 600,		# u=rw
		ensure => $ensure,
		notify => Service['keepalived'],	# this seems to work!
		# NOTE: add unnecessary alias names so that if one of those
		# variables appears more than once, an error will be raised.
		alias => ["password-${password}", "routerid-${routerid}"],
	}

	# create a 'tag' of this object's name, to get picked up in the group
	# XXX: FIXME: TODO: it would be nice to compartmentalize this under /etc/keepalived/groups/ but i have to get a live system first to test: "include path/*.blah"
	file { "/etc/keepalived/${name}.${group}.vrrpname":
		content => "${name}\n",
		owner => root,
		group => nobody,
		mode => 600,		# u=rw
		ensure => $ensure,
		notify => Service['keepalived'],
		require => File['/etc/keepalived/'],
	}

	# shorewall
	$split = split($name, '_')	# eg: VI_NET
	$a = $split[0]			# 'VI'
	$b = $split[1]			# ZONE
	$bool = (("${split[2]}" == '') and ("${a}_${b}" == "${name}") and ("${a}" == 'VI') and ("${b}" != ''))

	$valid_shorewall_zone = $shorewall_zone ? {
		'' => $bool ? {
			true => inline_template('<%= @b.downcase %>'),
			default => '',
		},
		default => "${shorewall_zone}",	# pass through, user decides
	}

	# NOTE: there is only source, because dest is part of the vrrp protocol
	$valid_shorewall_ipaddress = $shorewall_ipaddress ? {
		'' => '',
		/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/(3[0-2]|[12]?[0-9])$/ => ":${1}.${2}.${3}.${4}",	# strip cidr if present
		default => ":${shorewall_ipaddress}",
	}

	if $bool_shorewall and ( "${valid_shorewall_zone}" != '' ) {
		shorewall::rule { "vrrp-${name}": rule => "
		VRRP/ACCEPT    $FW    ${valid_shorewall_zone}
		VRRP/ACCEPT    ${valid_shorewall_zone}${valid_shorewall_ipaddress}    $FW
		", ensure => $ensure, comment => 'Allow VRRP traffic.'}
	}

	# check ip and strip off cidr (if present)
	case $watchip {	# TODO: add IPv6 support
		/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/(3[0-2]|[12]?[0-9])$/: {
			# with cidr
			$valid_watchip = "${1}.${2}.${3}.${4}"
		}
		/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/: {
			# no cidr
			$valid_watchip = $watchip
		}
		/^$/: {
			# empty string, pass through
			$valid_watchip = ''
		}
		default: {
			fail('$watchip must be either a valid IP address or empty.')
		}
	}

	# HACK: since certain ip's can only get added once an interface exists,
	# and keepalived can start too early and miss seeing this happen, we'll
	# sometimes get a scenario where the vip address never got added. To be
	# good engineers, we periodically check if an expected vip isn't there,
	# (using ping) and reload keepalived to refresh the old interface list.
	cron { "keepalived-${instance}":
		# the: > /dev/null 2>&1 disables email notifications from cron!
		# only run a reload if the service is already started...	# XXX: test this new part...
		command => "(/bin/ping -qc 1 ${valid_watchip} || (/sbin/service keepalived status && /sbin/service keepalived reload)) > /dev/null 2>&1",
		user => root,
		minute => '*/3',	# run every three minutes
		ensure => $valid_watchip ? {
			'' => absent,
			default => $ensure ? {
				absent => absent,
				default => present,
			},
		},
	}
}

# vim: ts=8
