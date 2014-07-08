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

define keepalived::group(
	$vrrp = [],
	$runnotify = true,		# run scripts in group/notify.d/ ?
	$autogroup = false		# internal option, private or expert use
) {
	include keepalived

	$conntrackd = $keepalived::conntrackd

	file { "/etc/keepalived/groups/${name}/":
		ensure => directory,		# make sure this is a directory
		recurse => true,		# recursively manage directory
		purge => true,			# purge all unmanaged files
		force => true,			# also purge subdirs and links
		owner => root,
		group => root,
		mode => 644,			# u=rwx,go=rx
		#notify => Service['keepalived'],
		require => File['/etc/keepalived/groups/'],
	}

	file { "/etc/keepalived/groups/${name}/notify.d/":
		ensure => directory,		# make sure this is a directory
		recurse => true,		# recursively manage directory
		purge => true,			# purge all unmanaged files
		force => true,			# also purge subdirs and links
		owner => root,
		group => root,
		mode => 644,			# u=rwx,go=rx
		#notify => Service['keepalived'],
		require => File["/etc/keepalived/groups/${name}/"],
	}

	# TODO: this could become a template if we want to add in some features
	file { "/etc/keepalived/groups/${name}/notify.sh":
		source => 'puppet:///modules/keepalived/notify.sh',
		owner => root,
		group => nobody,
		mode => 700,		# u=rwx
		ensure => $runnotify ? {
			false => absent,
			default => present,
		},
		#notify => Service['keepalived'],
	}

	file { "/etc/keepalived/${name}.group":
		content => template('keepalived/keepalived.group.erb'),
		owner => root,
		group => nobody,
		mode => 600,		# u=rw
		ensure => present,
		notify => Service['keepalived'],
	}
}

# vim: ts=8
