While participating in the 13th annual [EPP](http://www.ericharshbarger.org/epp/2013/) last weekend, I ran across a neat puzzle that led to some intersting algorithmic considerations. Some backstory: over the course of the 13 hours of the puzzle party, teams would find solutions to each of 13 puzzles in the form of stickers hidden around town. The stickers would contain a list of slot machine symbols, something like:

    Cherry  Seven  Bar  Spade  Seven

The meta-puzzle depended on the sets of symbols your team had found. Here's the jist:

    Find a way to assign a unique letter to each of the 13 possible symbols so
    that every solution that you have found is mapped to a valid word.

where "valid" here means "is on the [North American Competitive Scrabble Word List](http://www.ericharshbarger.org/epp/2009/TWL06.txt)".

## Design Considerations

### Observation 1.

The obvious brute-force approach would require checking the 26! / 13! ≈ 6 x 10^16 symbol-letter assignments. At an (optimistic) rate of one billion checks per second, that's about 2 billion years. Far longer than the 13 hours we had to work with. That means we'll need some way to represent and check partial solutions so that we can rule out large swaths of the potential solution space quickly.

I chose the fairly obvious approach of modeling an assignment as a hash. Then given an assigment like

```ruby
{ club: 'a', cherry: 'b' }
```

we can turn any set of symbols into a 'mask' to be looked up:

```ruby
[:cherry, :club, :cherry, :star, :star] => 'bab..'
```

The obvious thing to do at this point is scan the list of valid words, checking if any match the regex we've just defined. We may have to repeat this check a lot of times though, so we should avoid scanning all 8938 possible words each time if we can.

### Observation 2.

We have a long known prefix that we're interested in here, so this is a perfect place for a [trie](http://en.wikipedia.org/wiki/Trie). In the case of 'bab..', a trie would narrow things down to 7 possible choices after only 3 down the trie. Note: 10 is a *lot* less than 8938.

### Observation 3.

Our masking method actually loses some information - in the case of the above, the fact that the last two characters should be the same. We can narrow things further by considering an 'order type':

    [:cherry, :club, :cherry, :star, :star] => [0, 1, 0, 2, 2]

which would rule out 'babel' but still match 'baboo'. Here's the lookup structure I ended up using:

```ruby
OrderTypes = Solutions.map(&:order_type).uniq
Lookups = Hash[ OrderTypes.map { |t| [t, Trie.new] } ]
File.foreach("words.txt") do |w|
  w.strip!
  next unless Lookups.include? w.order_type
  Lookups[w.order_type].add w.downcase
end
```

Among the solutions that appeared, this order type analysis reduced the number of possibilities for each solution down from 8938 to 5839 in most cases and as low as 160 in the best case.

## Exploring the solution space

We now have a fast way to check a potential assignment, but we still need to be a little clever about how we traverse the set of possible assignments; ruling out 10 at a time still won't cut it. A fairly simple approach would look something like: given a partial assigment that you haven't ruled out, grab an unassigned symbol and recursively try assigning that symbol to each of the available letters.

### Observation 4.

The more often a symbol appears in our list of solutions, the easier it is to rule out potential assignments for it. That suggests that when we're grabbing an usused symbol, we should start with those with high frequency.

### Observation 5.

We don't need to assign only one symbol at a time. We could instead grab one solution and work backwards from the list of words it could possibly be to get a collection of assignments to check. For `[:club, :star, :grapes, :seven, :seven]` there are only 160 possible words that could match, and using those would be (26!/5!) / 160 = 49,335 times faster than brute-forcing it.

I actually ended up not using this last observation - sorting symbols by frequency is a big enough speed up on its own, and back-solving assignments from words didn't seem to be worth the added code complexity.

## The Result

Here's the core business logic that I ended up with:

```ruby
class Assignment
  def initialize map={}
    @map = map
  end

  # -- Solution checking -----

  def mask solution
    solution.map { |sym| @map[sym] || "." }.join ""
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
      Lookups[ot].root.include_fuzzy? m, "."  # Searches the trie with . as a wildcard
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
end

Assignment.new.search
```

The full implementation is [on GitHub](https://github.com/jamesdabbs/epp13-metapuzzle/blob/master/solver.rb). Here's what we get running it:

    $ bundle exec ruby solver.rb
    Building lookup structures ... 5.221848 s
    Starting search ...
      trhfeciuolasn
    Found solution: trhfeciuolasn
      club      => t  [:club, :star, :grapes, :seven, :seven]       => three
      grapes    => r  [:cherry, :crown, :spade, :heart, :star]      => flush
      star      => h  [:club, :horseshoe, :grapes, :bar, :star]     => torch
      cherry    => f  [:bell, :cherry, :club, :seven, :grapes]      => after
      seven     => e  [:horseshoe, :dollar, :club, :diamond, :bar]  => ontic
      bar       => c  [:cherry, :diamond, :cherry, :club, :star]    => fifth
      diamond   => i  [:bar, :horseshoe, :spade, :grapes, :club]    => court
      spade     => u  [:crown, :diamond, :cherry, :club, :heart]    => lifts
      horseshoe => o  [:spade, :crown, :club, :grapes, :bell]       => ultra
      crown     => l  [:seven, :club, :star, :diamond, :bar]        => ethic
      bell      => a
      heart     => s
      dollar    => n
      trhfeciuolasp
    Found solution: trhfeciuolasp
      club      => t  [:club, :star, :grapes, :seven, :seven]       => three
      grapes    => r  [:cherry, :crown, :spade, :heart, :star]      => flush
      star      => h  [:club, :horseshoe, :grapes, :bar, :star]     => torch
      cherry    => f  [:bell, :cherry, :club, :seven, :grapes]      => after
      seven     => e  [:horseshoe, :dollar, :club, :diamond, :bar]  => optic
      bar       => c  [:cherry, :diamond, :cherry, :club, :star]    => fifth
      diamond   => i  [:bar, :horseshoe, :spade, :grapes, :club]    => court
      spade     => u  [:crown, :diamond, :cherry, :club, :heart]    => lifts
      horseshoe => o  [:spade, :crown, :club, :grapes, :bell]       => ultra
      crown     => l  [:seven, :club, :star, :diamond, :bar]        => ethic
      bell      => a
      heart     => s
      dollar    => p
    Done ... 16.676031 s

Note: 22 seconds is a *whole lot* less than 2 billion years.