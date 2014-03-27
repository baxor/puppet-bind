class bind(
		$zones = hiera('bind::zones', {}),
		$allow_recursion=hiera('bind::allow_recursion',[]),
		$ipaddresses = hiera('bind::listen_on', [ $ipaddress ]),
		$ncotempl = hiera('bind::ncotempl', "bind/nco.erb"),
		$options = hiera('bind::options', [])
	  )
{
	$zonenames = keys($zones)

	file { "/etc/bind/named.conf.options":
		ensure => present,
		owner => "root",
		group => "bind",
		content => template($ncotempl),
		notify => Service['bind9'],
		require => Package['bind9'],
	}
	file { "/etc/bind/named.conf.local":
		ensure => present,
		owner => "root",
		group => "bind",
		content => template("bind/ncl.erb"),
		notify => Service['bind9'],
		require => Package['bind9'],
	}
	file { "/etc/bind/data":
		ensure => directory,
		owner => "root",
		group => "bind",
		mode => "0775",
		require => Package['bind9'],
	}
	service { "bind9":
		ensure => running,
		enable => true,
		restart => "rndc reload",
	}
	package { "bind9":
		ensure => latest,
	}
	package { "dnsutils":
		ensure => latest,
	}

	bind::zonefile {$zonenames: 
	}
	Dnsentry <<| |>> {
		require => Package['dnsutils']
	}
}
