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

define keepalived::vrrp_script(
	$script,			# the script to run
	$interval = 1,			# check every <N> seconds
	# FIXME: these '-1' should actually be ints when puppet supports them
	$rise = '-1',			# require <N> successes for OK
	$fall = '-1',			# require <N> failures for KO
	$weight = 0			# FIXME: this parameter currently unused
) {
	include keepalived

	file { "/etc/keepalived/${name}.script":
		content => template('keepalived/keepalived.script.erb'),
		owner => root,
		group => nobody,
		mode => 600,		# u=rw
		ensure => present,
		notify => Service['keepalived'],
	}
}

# vim: ts=8
