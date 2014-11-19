define dns::zone (
  $soa = "${::fqdn}.",
  $soa_email = "root.${::fqdn}.",
  $zone_ttl = '604800',
  $zone_refresh = '604800',
  $zone_retry = '86400',
  $zone_expire = '2419200',
  $zone_minimum = '604800',
  $nameservers = [ $::fqdn ],
  $reverse = false,
  $zone_type = 'master',
  $allow_transfer = [],
  $allow_forwarder = [],
  $forward_policy = 'first',
  $slave_masters = undef,
  $zone_notify = false,
  $ensure = present
) {

  $cfg_dir = $dns::server::params::cfg_dir

  validate_array($allow_transfer)
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
    file { "db.${name}"
      target  => $zone_file,
      content => template("${module_name}/zone_file.erb")
      require     => Class['dns::server::install'],
      notify      => Class['dns::server::service'],
    }
  }
}
