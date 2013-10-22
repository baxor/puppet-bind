my bind module
==============

Why another module?
-------------------

There are a number of other bind modules on the puppet forge, but most
of those that I looked at just manage `named.conf`, and require you to
copy zonefiles around. In the best case those zonefiles would be
generated; but still, that is precisely what I do *not* want to do, so
hence this module.

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

<pre>
---
bind::listen_on: 
  - 192.168.1.1
</pre>

This will make bind listen on the specified IP addresses. It will also
be used to decide whether bind is master or slave for a given zone (see
below). This is obviously data that's specific to one nameserver

<pre>
---
bind::zones:
  zone1.example.com:
    master: 192.168.1.1
    slaves:
      - 192.168.1.2
      - 192.168.1.3
  zone2.example.com:
    master: 192.168.1.2
    slaves:
      - 192.168.1.1
</pre>

This specifies all the zones that we have, and tells the nameservers
for which zones they should be the master, and for which zones they
should be the slave.

In the above example, the name server which has 192.168.1.1 in its
`bind::listen_on` value is master for hosts in `zone1.example.com`, with
`192.168.1.2` and `192.168.1.3` being slaves; and the name server
listening on `192.168.1.2` is master for hosts in `zone2.example.com`,
with `192.168.1.1` slave. The `named.conf.local` file will be generated
with that in mind.

`bind::listen_on` defaults to the value of the `ipaddress` fact, which
is probably right if you have just one IP address.

To actually add something to the DNS zone, use the dnsentry custom type:

<pre>
dnsentry { "webserver_a_record":
  nametype => "www.example.com a", # namevar
  ttl => 86400, # the default
  class => "IN", # the default
  rrdata => [ "192.168.1.1", "192.168.1.2" ]
  ensure => present,
}
</pre>

This will use `dig` and `nsupdate` to read data and/or perform any
changes.

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

Known issues
------------

- The puppet class only works on Debian (and derivatives) for now.
  Patches welcome.
- `bind::listen_on` doesn't actually influence the named.conf.options
  file yet. This will be fixed when I get around to it.
- The zone file entries are currently configured to accept updates, by
  IP, from the master only. A better way would be to allow updates
  through TSIG-signed DDNS requests, but that's a bit more involved.
