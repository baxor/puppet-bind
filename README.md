my bind module
==============

Why another module?
-------------------

There are a number of other bind modules on the puppet forge, but most
of those that I looked at just manage `named.conf`, and require you to
copy zonefiles around. In the best case those zonefiles would be
generated; but still, that is precisely what I do *not* want to do, so
hence this module.

Instead, I think a bind module should allow one to define _zone file
entries_, and use the normal AXFR/IXFR DNS calls to distribute changes.
That's precisely what this module does.

Also, I used this module to learn how to write a custom type for puppet.
Given that, there's bound to be some ugliness in there, but it seems to
work for me. Bug reports are certainly welcome :)

How?
----

You may wish to update the template files. `ncl.erb` is used to generate
named.conf.local, `nco.erb` is used for named.conf.options, and
`zonetmpl.erb` is used for the initial content of a zone file. The latter is
not updated afterwards, any changes are done through `nsupdate`.

You need to do two things: define a zone, and add DNS entries to the
zone. For the first, you should include the bind class on your
nameservers. You'll want to define something in hiera, e.g.:

    ---
    bind::listen_on: 
      - 192.0.2.1

Note that you may also specify IPv6 addresses:

    ---
    bind::listen_on:
      - 192.0.2.1
      - 2001:db8::1

This will make bind listen on the specified IP addresses. It will also
be used to decide whether bind is master or slave for a given zone (see
below). This is obviously data that's specific to one nameserver.

Other per-nameserver options that can be specified:

- `bind::allow_recursion`: list of hosts allowed to make recursive
  queries to this nameserver
- `bind::ncotempl`: the template to be used to generate the
  `named.conf.options` file (default: `bind/nco.erb`)
- `bind::options`: any random BIND option you want to add.

Note that you should **not** change the `session-keyname` option, or
things **will** break. The module does not currently check for this;
this may change in the future. An example would be something like:

    ---
    bind::options:
      - tkey-gssapi-keytab "/etc/bind/bind.keytab"
      - dnssec-validation auto

You'll also need to specify the zones; this data would be specified in a
`common.yaml` or similar:

    ---
    bind::zones:
      zone1.example.com:
        master: 192.0.2.1
        slaves:
          - 198.51.100.1
          - 2001:db8::1
        updatepols:
          - grant * self
          - grant wouterkey zonesuby any
      zone2.example.com:
        master: 198.51.100.1
        slaves:
          - 192.0.2.1

This specifies all the zones that we have, and tells the nameservers
for which zones they should be the master, and for which zones they
should be the slave.

In the above example, the name server which has 192.0.2.1 in its
`bind::listen_on` value is master for hosts in `zone1.example.com`, with
`198.51.100.1` and `2001:db8::1` being slaves; and the name server
listening on `198.51.100.1` is master for hosts in `zone2.example.com`,
with `192.0.2.1` slave. The `named.conf.local` file will be generated
with that in mind.

In case the server on `198.51.100.1` happens to be the same server as
the one on `2001:db8::1` (as in the last `bind::listen_on` example),
then only a master block will be generated; so it's safe to have a
server be listed multiple times.

`bind::listen_on` defaults to the value of the `ipaddress` fact, which
is probably right if you have just one IP address.

The "updatepols" key allows to specify update policies for manual
administration of the zone, should this be wanted. Note that an update
policy of the form `grant local-ddns zonesub any` is silently added to
this list (this is why you should not change the name of the
`local-ddns` key).

Once you've done that, all you need to do now is to include the `bind`
class on your nameservers, with no options; everything will be set up
correctly. If you ever move things around in hiera, then the zone file
entries in `named.conf.local` will be updated automatically (but the
zone files _themselves_ will not; this may be fixed in a future release,
but for now you'll have to update the SOA field yourself).

To actually add something to the DNS zone, use the dnsentry custom type:

    dnsentry { "webserver_a_record":
      nametype => "www.example.com a", # namevar
      ttl => 86400, # the default
      rrclass => "IN", # the default
      rrdata => [ "192.168.1.1", "192.168.1.2" ]
      ensure => present,
    }

This will use `dig` and `nsupdate` to read data and/or perform any
changes.

You need to realize the `dnsentry` on the master nameserver for the
update to work, or you can use distributed types (the `bind` class
already includes the relevant `Dnsentry <<||>>` statement).

Note the special format of the "nametype" property: `name <space> type`.
Since an A record is absolutely not the same thing as a CNAME or a TXT
record (or whathaveyou), a different format would have made it
impossible for the provider to figure out whether a given resource
exists.

The rrdata attribute is required (except when `ensure` is set to `absent`)

When removing an entry (i.e., when `ensure` is set to `absent`) the
value of the rrdata attribute is used: if no rrdata attribute was presented,
then all RRs of the given type are removed. If an rrdata attribute was
presented, however, then only the RRs of the given type with the given
data will be removed.

Code status
===========

Known issues
------------

- The puppet class only works on Debian (and derivatives) for now.
  Patches welcome.

Planned features
----------------

- Transparent DNSSEC support. This will be something where you say
  `bind::dnssec: true` or similar in hiera, and everything else will
  happen magically. Might require some extra custom types, but we're not
  there yet.

Changelog
---------

- 1.0.0: Initial release
- 1.1.0: v6 support
- 1.2.0: use TSIG updates (with local-ddns key) rather than allow-update
  stanzas. Also, add support for random options in the `options` block.

 -- Wouter Verhelst, <w@uter.be>
