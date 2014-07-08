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

# NOTE: $name should be a path for $source as long as $content is empty.
define keepalived::group_script(
	$group,
	$content = '',
	$ensure = present
) {
	include keepalived

	#if $content == '' {
	# finds the file name in a complete path; eg: /tmp/dir/file => file
	$file = regsubst($name, '(\/[\w.]+)*(\/)([\w.]+)', '\3')
	$base = sprintf("%s", regsubst($file, '\.sh$', ''))	# rstrip any .sh
	#}

	$valid_name = $content ? {
		'' => "${base}",
		default => "${name}",
	}

	file { "/etc/keepalived/groups/${group}/notify.d/${valid_name}.sh":
		ensure => $ensure,
		content => $content ? {
			'' => undef,
			default => $content,
		},
		source => $content ? {
			'' => $name,	# eg: puppet:///files/keepalived/scripts/x.sh
			default => undef,
		},
		owner => root,
		group => nobody,
		mode => 700,		# u=rwx
		#notify => Service['keepalived'],
		require => [
			Keepalived::Group["${group}"],
			File["/etc/keepalived/groups/${group}/notify.d/"],
		],
	}
}

# vim: ts=8
