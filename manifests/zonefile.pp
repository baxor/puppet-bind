define bind::zonefile($zonename = $title, $ensure = present) {
	$zones = hiera('bind::zones')
	$zone = $zones["$zonename"]
	$master = $zone["master"]
	file { "/etc/bind/data/$zonename":
		content => template("bind/zonetmpl.erb"),
		ensure => $ensure,
		replace => false
		notify => Service['bind9']
	}
}
