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
  attr_reader :hands, :winner, :rounds, :players
  
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
      @rounds << Round.new(@bids, @hands.each_with_object({}) { |(k, v), hsh| hsh[k] = v.dup}).set_winner(adjudicate_round!)
      puts "Round #{@rounds.length}: #{@rounds.last}" if DEBUG
    end
    
    @winner = @players.first
    self
  end
  
  def dice_in_play
    @hands.values.map(&:size).inject(:+)
  end
  
  def turn_count
    @turn_index + 1
  end
  
  def inspect
    {winner: @winner}.inspect
  end
  
  def latest_bid
    @bids.last
  end
  
  def number_of_dice_per_player
    @hands.each_with_object({}) { |(k, v), h| h[k] = v.size }
  end
  
  private
  
  def number_of_dice_of_value(value)
    @hands.values.flatten.count(value)
  end
  
  def challenge?
    latest_bid && latest_bid.challenge? 
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

class Round
  attr_accessor :bids, :hands, :winner
  
  def initialize(bids, hands)
    @bids, @hands = bids, hands
  end
  
  def set_winner(winner)
    @winner = winner
    self
  end
  
  def to_s
    "#{bids}, Winner: #{winner}. Hands were: #{hands}"
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
      "#{player} CHALLENGED"
    else
      "#{player} bid #{quantity.to_words} #{value}#{quantity > 1 ? 's' : ''}"
    end
  end
end

class Player
  attr_accessor :name, :game
  InvalidBidError = Class.new(StandardError)
  
  def initialize
    @name = "#{self.class.name}:#{object_id}"
  end
  
  def go!
    raise NotImplementedError.new("You must implement the `go!` method")
  end
  
  def latest_bid
    game.latest_bid
  end
  
  def bids
    game.bids
  end
  
  def hand
    game.hands[self].sort
  end
  
  def dice_in_play
    game.dice_in_play
  end
  
  def players
    game.players
  end
  
  def number_of_dice_per_player
    game.number_of_dice_per_player
  end
  
  def bid!(quantity, value)
    b = Bid.new(self, quantity, value)
    if valid_bid?(b)
      game.bids << b
    else
      raise InvalidBidError.new("Bid \"#{b}\" is invalid! (Previous bid: \"#{game.latest_bid})\"")
    end
  end
  
  def challenge!
    bid!(nil, :challenge)
  end
  
  def to_s
    name
  end
  
  private
  
  def valid_bid?(b)    
    return true if latest_bid.nil?
    return false if latest_bid.player == b.player || latest_bid.challenge?
    return true if b.challenge?
    
    (b.quantity == latest_bid.quantity && b.value > latest_bid.value) || b.quantity > latest_bid.quantity
  end
end

class InteractivePlayer < Player
  def initialize(name)
    @name = name
  end
  
  def go!
    puts "Bid history: #{bids.inspect}\n#{self}'s hand: #{hand.inspect}"
    print "#{self}'s bid (e.g., write '2 4' to mean 'two 4s'): "
    bid_input = gets.chomp
    if bid_input =~ /challenge/
      challenge!
    else
      bid!(*bid_input.split(' ').map(&:to_i))
    end
  end
end

class DumbBot < Player
  def initialize(name)
    @name = name
  end
  
  def go!
    if latest_bid
      if rand < 0.5
        bid!(latest_bid.quantity + 1, latest_bid.value)
      else
        challenge!
      end
    else
      bid!(1, rand(6) + 1)
    end
  end
end