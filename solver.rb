require "colorize"
require "trie"

Letters = Set.new "a".."z"

# -- Monkey-patches -----
# I would typically avoid these, but they are useful for these sorts of quick
# one-off projects

class Array
  def order_type
    @order_type ||= begin
      order = {}
      map { |c| order[c] ||= order.length }
    end
  end

  def by_frequency
    each_with_object Hash.new 0 do |sym, counts|
      counts[sym] += 1
    end.sort_by { |k,v| -v }.map &:first
  end
end

class String
  def order_type
    @order_type ||= chars.order_type
  end
end

class TrieNode
  def include_fuzzy? str, wildcard="."
    return true if str.empty?
    c, *cs = str.chars
    if c == wildcard
      Letters.any? { |c| walk(c).include_fuzzy? cs.join(""), wildcard rescue false }
    else
      walk(c).include_fuzzy? cs.join(""), wildcard rescue false
    end
  end
end

# ----------

start = Time.now
print "Building lookup structures ... "

Solutions = [
  [:club, :star, :grapes, :seven, :seven],
  [:cherry, :crown, :spade, :heart, :star],
  # Stupid freaking DVD puzzle,
  [:club, :horseshoe, :grapes, :bar, :star],
  [:bell, :cherry, :club, :seven, :grapes],
  [:horseshoe, :dollar, :club, :diamond, :bar],
  [:cherry, :diamond, :cherry, :club, :star],
  [:bar, :horseshoe, :spade, :grapes, :club],
  [:crown, :diamond, :cherry, :club, :heart],
  [:spade, :crown, :club, :grapes, :bell],
  [:seven, :club, :star, :diamond, :bar]
]

OrderTypes = Solutions.map(&:order_type).uniq

Symbols = Solutions.flatten.by_frequency

Lookups = Hash[ OrderTypes.map { |t| [t, Trie.new] } ]
File.foreach("words.txt") do |w|
  w.strip!
  next unless Lookups.include? w.order_type
  Lookups[w.order_type].add w.downcase
end
puts "#{Time.now - start} s"

# ----------

class Assignment
  def initialize map={}
    @map = map
  end

  # -- Solution checking -----

  def mask solution
    solution.map { |sym| @map[sym] || "." }.join ""
  end

  def full?
    @map.length == 13
  end

  def correct?
    Solutions.all? do |solution|
      word = mask solution
      Lookups[solution.order_type].has_key? word
    end
  end

  def possible?
    return correct? if full?

    Solutions.all? do |solution|
      ot = solution.order_type
      m  = mask solution
      Lookups[ot].root.include_fuzzy? m, "."
    end
  end

  # -- Search space traversal -----

  def children
    slot = Symbols.find { |s| @map[s].nil? }
    (Letters - @map.values).map do |letter|
      map       = @map.clone
      map[slot] = letter
      Assignment.new map
    end
  end

  def search
    print "  " + self.to_s.ljust(14) + "\r"
    if full? && correct?
      print_solution
    else
      children.each do |child|
        next unless child.possible?
        child.search
      end
    end
  end

  # -- Printing -----

  def to_s
    @map.values.join ""
  end

  def self.from_s str
    new Hash[ Symbols.take(str.length).zip str.chars ]
  end

  def print_solution
    puts "\nFound solution: #{self}".green
    @map.each_with_index do |(k,v), i|
      solution = (s = Solutions[i]) ? "#{s.to_s.ljust 45} => #{mask s}" : ""
      puts "  #{k.to_s.ljust 9} => #{v}\t#{solution}"
    end
  end
end

start = Time.now
puts "Starting search ..."
Assignment.new.search
puts "Done ... #{Time.now - start} s"
