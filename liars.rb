require 'pry'

class Game
  # TODO: Throw an error if you try to access data that you shouldn't have
  # (like the dice for a player that's not your own). Means bots have
  # to be initialized with a player?
  
  # TODO: Throw an error if your bid isn't valid (i.e., is smaller than the
  # latest bid).
  
  NUMBER_OF_DICE_PER_HAND = 5
  
  require 'json'
  attr_accessor :bids
  attr_reader :hands
  
  def initialize(*players)
    @players = players
    @hands = @players.each_with_object({}) { |pl, h| h[pl] = create_hand }
    @players.each { |pl| pl.game = self }
    @bids = []
    @turn_cursor = 0
  end
  
  def play!
    while @players.size > 1
      next_player.go! until challenge?
      adjudicate_round!
    end
    
    puts "Winner is #{@players.first}!"
  end
  
  def dice_remaining
    @hands.values.map(&:size).inject(:+)
  end
  
  private
  
  def number_of_dice_of_value(value)
    @hands.values.flatten.count(value)
  end
  
  def challenge?
    @bids.last && @bids.last.challenge? 
  end
  
  def roll_new_hands!
    @hands.each { |k, v| @hands[k] = create_hand(@hands[k].size) }
  end
  
  def adjudicate_round!
    challenged_bid, challenge = @bids[-2], @bids[-1]
    @round_loser = bid_is_good?(challenged_bid) ? challenge.player : challenged_bid.player
    @turn_cursor = @players.index(@round_loser)
    remove_die_from_player!(@round_loser)
    roll_new_hands!
    @bids = []
  end
  
  def bid_is_good?(bid)
    number_of_dice_of_value(bid.value) >= bid.quantity
  end
  
  def remove_die_from_player!(player)
    @hands[player].pop
    
    if @hands[player].empty?
      @players.delete(player)
    end
  end
  
  def create_hand(size = NUMBER_OF_DICE_PER_HAND)
    [].tap do |hand|
      size.times { hand << rand(6) + 1 }
    end
  end
  
  def next_player
    @players[@turn_cursor % @players.size].tap do |pl|
      @turn_cursor += 1
    end
  end
end

class Bid
  attr_accessor :player, :quantity, :value
  
  def initialize(player, quantity, value)
    @player = player
    @quantity = quantity
    @value = value
  end
  
  def challenge?
    value == :challenge
  end
  
  def to_s
    "#{player}: #{quantity} #{value}#{quantity > 1 ? 's' : ''}"
  end
end

class Player
  attr_accessor :name, :game
  
  def initialize
    @name = "#{self.class.name}:#{object_id}"
  end
  
  def go!
    raise NotImplementedError.new("You must implement the `go!` method")
  end
  
  def hand
    game.hands[self]
  end
  
  def bid(quantity, value)
    game.bids << Bid.new(self, quantity, value)
  end
  
  def challenge!
    bid(nil, :challenge)
  end
  
  def to_s
    name
  end
end

class InteractivePlayer < Player
  def initialize(name)
    @name = name
  end
  
  def go!
    puts "#{self}'s turn."
    puts "Bid history: #{game.bids.inspect}"
    puts "#{self}'s hand: #{hand.inspect}"
    print "Bid: "
    bid_input = gets.chomp
    if bid_input =~ /challenge/
      challenge!
    else
      bid(*bid_input.split(' ').map(&:to_i))
    end
  end
end

class Dumbot < Player
  def go!
    last_bid = game.bids.last
    if last_bid
      if rand < 0.5
        bid(last_bid[:quantity] + 1, last_bid[:value])
      else
        challenge!
      end
    else
      bid(1, rand(6) + 1)
    end
  end
end