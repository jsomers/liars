require 'pry'
require 'rubygems'
require 'numbers_and_words'

DEBUG = true

class Match
  def initialize(*players, number_of_games)
    @players, @number_of_games = players, number_of_games
    @games = []
  end
  
  def play!
    @number_of_games.times do
      @games << (g = Game.new(*@players).play!)
      puts "-" * 40 + "\nGame #{@games.size} won by #{g.winner}\n\n" if DEBUG
    end
    
    @games.each_with_object(Hash.new(0)) do |game, summary|
      summary[game.winner] += 1
    end
  end
end

class Game  
  attr_accessor :bids
  attr_reader :hands, :winner
  
  NUMBER_OF_DICE_PER_HAND = 5
  
  def initialize(*players)
    @players = players
    @hands = @players.each_with_object({}) { |pl, h| h[pl] = create_hand }
    @players.each { |pl| pl.game = self }
    @bids, @rounds, @turn_index = [], [], 0
  end
  
  def play!
    while @players.size > 1
      next_player.go! until challenge?
      @rounds << Round.new(@bids, adjudicate_round!)
      puts "Round #{@rounds.length}: #{@rounds.last}" if DEBUG
    end
    
    @winner = @players.first
    self
  end
  
  def dice_remaining
    @hands.values.map(&:size).inject(:+)
  end
  
  def turn_count
    @turn_index + 1
  end
  
  def inspect
    {winner: @winner}.inspect
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
    winner, loser = if bid_is_good?(challenged_bid)
                      [challenged_bid.player, challenge.player]
                    else 
                      [challenge.player, challenged_bid.player]
                    end
    
    @turn_index = @players.index(loser)
    remove_die_from_player!(loser)
    roll_new_hands!
    @bids = []
    winner
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
    @players[@turn_index % @players.size].tap do |pl|
      @turn_index += 1
    end
  end
end

class Round < Struct.new(:bids, :winner)
  def to_s
    "#{bids}, Winner: #{winner}"
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
    if challenge?
      "#{player} CHALLENGE"
    else
      "#{player}: #{quantity.to_words} #{value}#{quantity > 1 ? 's' : ''}"
    end
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
    game.hands[self].sort
  end
  
  def bid(quantity, value)
    b = Bid.new(self, quantity, value)
    if valid_bid?(b)
      game.bids << b
    else
      raise "Bid \"#{b}\" is invalid!"
    end
  end
  
  def challenge!
    bid(nil, :challenge)
  end
  
  def to_s
    name
  end
  
  private
  
  def valid_bid?(b)
    latest_bid = game.bids.last
    return true if latest_bid.nil?
    return false if latest_bid.player == b.player || latest_bid.challenge?
    return true if b.challenge?
    
    (b.quantity == latest_bid.quantity && b.value > latest_bid.value) || 
      b.quantity > latest_bid.quantity
  end
end

class InteractivePlayer < Player
  def initialize(name)
    @name = name
  end
  
  def go!
    puts "Bid history: #{game.bids.inspect}\n#{self}'s hand: #{hand.inspect}"
    print "#{self}'s bid (e.g., write '2 4' to mean 'two 4s'): "
    bid_input = gets.chomp
    if bid_input =~ /challenge/
      challenge!
    else
      bid(*bid_input.split(' ').map(&:to_i))
    end
  end
end

class DumbBot < Player
  def initialize(name)
    @name = name
  end
  
  def go!
    last_bid = game.bids.last
    if last_bid
      if rand < 0.5
        bid(last_bid.quantity + 1, last_bid.value)
      else
        challenge!
      end
    else
      bid(1, rand(6) + 1)
    end
  end
end

class ScottBot < Player
  def go!
    hand # [1, 4, 4, 5]
    game.dice_remaining # 22
  end
end

# TODO: Demo Mode? (Want to be able to halt before each player's decision, given what they know, 
# hit ENTER, then see what they come up with.)

# TODO: Write README that explains how to write bots, how to test them (against)
# an interactive bot, a dumbBot, etc.