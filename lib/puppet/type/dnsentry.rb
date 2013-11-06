Puppet::Type.newtype(:dnsentry) do
  @doc = "Manages a DNS entry in a BIND server using nsupdate."

  ensurable

  newparam(:nametype, :namevar => true) do
    desc "the RR name and type"

    validate do |val|
      arr = val.split(' ')
      if arr.length < 2
        raise ArgumentError, " %s does not include the type!" % val
      end
      #if ["SOA", "PTR", "ANY"].include?(arr[1].upcase)
      if ["SOA", "ANY"].include?(arr[1].upcase)
        raise ArgumentError, " %s cannot be specified as type " % val
      end
    end
  end

#  newproperty(:reverse) do
#    desc "whether to also create a reverse (i.e., PTR) record. Can only be used on A or AAAA RRs"
#
#    defaultto :false
#
#    newvalues(:true, :false)
#  end

  newproperty(:rrdata, :array_matching => :all) do
    desc "data for the RR"
    def insync?(is)
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      else
        is == @should
      end
    end
  end

  newproperty(:rrclass) do
    desc "RR class."

    defaultto "IN"

    newvalues("IN", "CH", "HS")
  end

  newproperty(:ttl) do
    desc "TTL for this RR"

    defaultto 86400

    munge do |value|
      Integer(value)
    end
  end

  validate do
    arr = self[:nametype].split(' ')
    #if ["A", "AAAA"].include?(arr[1].upcase!) && self[:reverse] == :true
      #raise ArgumentError, " cannot create a reverse record for %s RRs" % arr[1].upcase
    #end
    if (self[:rrdata].nil? || self[:rrdata].empty?) && self[:ensure] == :present
      raise ArgumentError, " the rrdata property is required"
    end
  end
end
