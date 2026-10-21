# DBM for Ruby 3.4, where it is no longer bundled: a Hash kept in one file (Marshal). bin/gen_credits.rb uses it as a cache of git log lookups.
class DBM
  include Enumerable
  WRCREAT = 0x200
  NEWDB = 0x400
  READER = 0
  WRITER = 2
  def self.open(path, mode = 0666, flags = WRCREAT)
    db = new(path, mode, flags)
    return db unless block_given?
    begin yield db ensure db.close end
  end
  def initialize(path, mode = 0666, flags = WRCREAT)
    @path = path.to_s + ".wsbsd-dbm"
    @h = (File.exist?(@path) && flags != NEWDB) ? (Marshal.load(File.binread(@path)) rescue {}) : {}
    @closed = false
  end
  def [](k) @h[k.to_s] end
  def []=(k, v) @h[k.to_s] = v.to_s end
  alias store []=
  def fetch(k, *d) @h.fetch(k.to_s, *d) end
  def key?(k) @h.key?(k.to_s) end
  alias has_key? key?
  alias include? key?
  def delete(k) @h.delete(k.to_s) end
  def keys() @h.keys end
  def values() @h.values end
  def length() @h.length end
  alias size length
  def each(&b) @h.each(&b) end
  alias each_pair each
  def to_hash() @h.dup end
  def close
    return if @closed
    File.binwrite(@path, Marshal.dump(@h)); @closed = true
  end
  def closed?() @closed end
end
