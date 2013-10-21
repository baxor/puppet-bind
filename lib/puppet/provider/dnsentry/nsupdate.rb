require 'tempfile'

Puppet::Type.type(:dnsentry).provide(:nsupdate) do
  commands :dig => 'dig', :nsupdate => 'nsupdate'

  def namearr
    resource[:nametype].split(' ')
  end

  def name
    namearr[0]
  end

  def type
    namearr[1]
  end

  def q
    dig(type, name).split("\n")
  end

  def initialize(value={})
    super(value)
    @properties = {}
    nextline = false
    @line = nil
    q.collect do |line|
      if nextline
	@line = line
	return
      end
      if line =~ /ANSWER SECTION/
        nextline = true
      end
    end
    @dontflush = false
  end

  def exists?
    return !(@line.nil?)
  end

#  def reverse
#  end

#  def reverse=(value)
#  end

  def rrclass
    if @line =~ /#{name}[[:space:]]+[0-9]+\((IN|CH|HS)\)/
      return $1
    end
    return nil
  end
  
  def rrclass=(value)
    @properties[:rrclass] = value
  end

  def rrdata
    nextline=false
    retval = []
    q.collect do |line|
      if line =~ /^\s*$/
        nextline=false
	if(!retval.empty?)
	  return retval
	end
      end
      if nextline
        arr = line.split(' ')
	retval << arr[4..-1].join(' ')
      end
      if line =~ /ANSWER SECTION/
        nextline=true
      end
    end
    return nil
  end
  
  def rrdata=(value)
    @properties[:rrdata] = value
  end
  
  def ttl
    if @line =~ /#{name}[[:space:]]+\([0-9]+\)/
      return $1
    end
  end

  def ttl=(value)
    @properties[:ttl] = value
  end

  def create
    commandstring = "server 127.0.0.1\n"
    rrdata = resource[:rrdata]
    if(!rrdata.is_a? Array)
      rrdata = [ rrdata ]
    end
    rrdata.each do |data|
      commandstring << "update add #{name} #{resource[:ttl]} #{resource[:rrclass]} #{type} #{data}\n"
    end
    commandstring << "send\n"
    file = Tempfile.new('nsupdate-create-')
    file.write(commandstring)
    file.close
    nsupdate(file.path)
    #file.unlink
    @dontflush = true
  end

  def destroy
    commandstring = "server 127.0.0.1\n"
    if !resource[:rrdata]
      rrdata = [ "" ]
    else
      rrdata = resource[:rrdata]
    end
    rrdata.each do | data | 
      commandstring << "update delete #{name} #{type} #{data}\nsend\n"
    end
    file = Tempfile.new('nsupdate-destroy-')
    file.write(commandstring)
    file.close
    nsupdate(file.path)
    #file.unlink
    @dontflush = true
  end

  def flush
    if @dontflush
      @dontflush = false
      return
    end
    if @properties[:rrdata].nil?
      @properties[:rrdata] = resource[:rrdata]
    end
    if @properties[:rrclass].nil?
      @properties[:rrclass] = resource[:rrclass]
    end
    if @properties[:ttl].nil?
      @properties[:ttl] = resource[:ttl]
    end
    rrdata = @properties[:rrdata]
    if !rrdata.is_a? Array
      rrdata = [ rrdata ]
    end
    commandstring = "server 127.0.0.1\n"
    rrdata.each do |val|
      commandstring << "update delete #{name} #{type} #{val}\n"
      commandstring << "update add #{name} #{@properties[:ttl]} #{@properties[:rrclass]} #{type} #{val}\n"
    end
    commandstring << "send\n"
    file = Tempfile.new('nsupdate-flush-')
    file.write(commandstring)
    file.close
    nsupdate(file.path)
    #file.unlink
  end
end
