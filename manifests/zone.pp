define dns::zone (
  $soa = "${::fqdn}.",
  $soa_email = "root.${::fqdn}.",
  $zone_ttl = '86400',
  $zone_refresh = '86400',
  $zone_retry = '86400',
  $zone_expire = '300',
  $zone_minimum = '60',
  $nameservers = [ $::fqdn ],
  $reverse = false,
  $zone_type = 'master',
  $allow_transfer = [],
  $allow_update = [],
  $allow_forwarder = [],
  $forward_policy = 'first',
  $slave_masters = undef,
  $zone_notify = false,
  $ensure = present
) {

  $cfg_dir = $dns::server::params::cfg_dir

  validate_array($allow_transfer)
  validate_array($allow_update)
  validate_array($allow_forwarder)
  if $dns::server::options::forwarder and $allow_forwarder {
    fatal("You cannot specify a global forwarder and \
    a zone forwarder for zone ${soa}")
  }
  if !member(['first', 'only'], $forward_policy) {
    error('The forward policy can only be set to either first or only')
  }

  $zone = $reverse ? {
    true    => "${name}.in-addr.arpa",
    default => $name
  }

  $zone_file = "${cfg_dir}/zones/db.${name}"

  if $ensure == absent {
    file { $zone_file:
      ensure => absent,
    }
  } else {
    # Include Zone in named.conf.local
    concat::fragment{"named.conf.local.${name}.include":
      ensure  => $ensure,
      target  => "${cfg_dir}/named.conf.local",
      order   => 3,
      content => template("${module_name}/zone.erb")
    } -> 
    # Zone Database
    file { "db.${name}":
      path    => $zone_file,
      content => template("${module_name}/zone_file.erb"),
      replace => false,
      require => Class['dns::server::install'],
      notify  => Class['dns::server::service'],  #TODO:  notify -> Exec['mco-xoom-dns-start'] -- trigger site-wide re-addition of all dns records if the zone file is ever re-written
    }  

    $zone_serial = inline_template('<%= Time.now.to_i %>')
    exec { "bump-${zone}-serial":
      command     => "sed -i 's/_SERIAL_/${zone_serial}/' ${zone_file}",
      path        => ['/bin', '/sbin', '/usr/bin', '/usr/sbin'],
      refreshonly => true,
      subscribe   => File["db.${name}"],
      provider    => posix,
      user        => 'bind',
      group       => 'bind',
      require     => Class['dns::server::install'],
      notify      => Class['dns::server::service'],
    }
  }
}
