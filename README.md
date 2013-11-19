## Installation

You will need Ruby 1.9 and the `gem` program in order to run this code. Ruby should come installed on Macs and is easily downloadable on other systems. To check your version run:

```sh
ruby -v
```

from the command line. Then install the required gems:

```sh
gem install numbers_and_words
gem install pry
```

## Usage

Download the **liars.rb** file to your computer. On the command line, navigate to the directory containing that file. Then run:

```sh
irb -r ./liars.rb
```

This tells the interactive Ruby interpreter to start with the **liars.rb** file loaded. From there you should be able to run matches. For instance at the prompt you can write:

```rb
> Match.new(DumbBot.new('James'), DumbBot.new('Menke'), 10).play!
```

This will play out a 10-game match between two `DumbBots` named "James" and "Menke." Let's add an `InteractivePlayer` -- i.e., a player controlled by you -- to the mix!

```rb
> Match.new(DumbBot.new('James'), DumbBot.new('Menke'), InteractivePlayer.new('Nikhil'), 10).play!
```

Matches can be between any number of bots, for any number of games. Bots can be initialized with human-readable names for ease of debugging.

You'll see that the main **liars.rb** file has a `DEBUG` parameter that by default is set to `true`. If you don't like the verbose output about the progress of rounds, etc., you can set it to `false`.

## Making Your Bot

To make a bot you add code to the bottom of the **liars.rb** file. In particular you should write a new Ruby class that inherits from `Player`, like so:

```rb
class JimboBot < Player
end
```

To be valid, your bot must define a method called `go!`. The `go!` method determines, based on the current state of the game, what bids to make. Here's an example `go!` method from the (aptly named) `DumbBot`:

```rb
class DumbBot < Player
  def go!
    if latest_bid # Has there already been a bid in the round, or is mine the first?
      if rand < 0.5 # Flip a coin
        bid!(latest_bid.quantity + 1, latest_bid.value) # This is how you make bids!
      else
        challenge! # Challenge!
      end
    else
      bid!(1, rand(6) + 1)
    end
  end
end
```

This bot is dumb because all it uses to make its decision is the bid immediately before it. That's `latest_bid`. There are a bunch of other pieces of information a bot can use to make its decision, all made available as methods:

```rb
class YourBot < Player
  def go!
    # What's my hand right now?
    hand # => returns an array of dice like: [1, 4, 4, 5]
    
    # How many dice, total, held by all the players, are in play right now?
    dice_in_play # => 22
    
    # How many dice does each player have?
    number_of_dice_per_player # => {'James': 2, 'Menke': 1, 'Freedman': 4}
    
    # What are the bids so far in this round?
    bids # => returns an array of `Bid` objects
    
    # Each `Bid` object has a `player`, `quantity`, and `value`. You can inspect
    # these values, too. For instance you could write:
    if bids.last.quantity > bids.first.value
      # ...
    end
    
    # For convenience, instead of writing `bids.last` you can write `latest_bid`
    latest_bid
    latest_bid.player # => returns a `Player` instance. (Your bot, and all the other bots,
                      # are `Player` instances.)
    latest_bid.quantity # => 4
    latest_bid.value # => 3
    
    latest_bid.to_s # => The string representation of a bid is meant to be easy to read. In this case it
                    # might say "Menke bid four 3s", because the quantity was 4 and the value was 3.
                    
    # Given the above, you can make a bid:
    bid!(2, 1) # Make a bid of two 1s
    
    # Or issue a challenge:
    challenge!
  end
end
```

If you like, you can define your own data that will, by default, be persisted for the duration of the match. You do it by creating an `@instance_variable`. It might look like this:

```rb
class SmartBot < Player
  def initialize(name)
    @name = name
    @other_data_array = []
    @other_data_hash = {}
    # ...
  end
  
  def go!
    # Modify the data:
    @other_data_hash[players.first] = 10
    
    # Access the data:
    @other_data_hash[players.first] # => 10
  end
```
