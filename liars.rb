#!/Users/jsomers/.rvm/rubies/ruby-1.9.2-p290/bin/ruby

require 'pry'

class Game
  # TODO: Throw an error if you try to access data that you shouldn't have
  # (like the dice for a player that's not your own). Means bots have
  # to be initialized with a player?
  
  # TODO: Throw an error if your bid isn't valid (i.e., is smaller than the
  # latest bid).
  
  NUMBER_OF_DICE_PER_HAND = 5
  
  require 'json'
  attr_accessor :players, :hands, :bids
  
  def initialize(*players)
    @players = players
    @hands = players.each_with_object({}) { |pl, h| h[pl] = create_hand }
    players.each { |pl| pl.game = self }
    @bids = []
    @turn_cursor = -1
  end
  
  def dice_remaining
    @hands.values.map(&:size).inject(:+)
  end
  
  def play!
    while players.size > 1
      next_player.go! until challenge?
      determine_round_winner!
      reset_round!
    end
    
    puts "Winner is #{players.first}"
  end
  
  def number_of_dice_of_value(value)
    @hands.values.flatten.count(value)
  end
  
  private
  
  def reset_round!
    shuffle_hands!
    @turn_cursor = @players.index(@round_loser).to_i - 1
    @bids = []
  end
  
  def challenge?
    @bids.last && @bids.last[:value] == :challenge
  end
  
  def shuffle_hands!
    @hands.each { |k, v| @hands[k] = v.shuffle }
  end
  
  def determine_round_winner!
    bid = @bids[-2]
    puts "#{@bids[-1][:player]} challenges bid: #{[bid[:quantity], bid[:value]].inspect}"
    puts "number_of_dice_of_value #{bid[:value]}: #{number_of_dice_of_value(bid[:value])}"
    @round_loser = if bid_is_good = (number_of_dice_of_value(bid[:value]) >= bid[:quantity])
      @bids.last[:player]
    else
      bid[:player]
    end
    puts "Bid is good?: #{bid_is_good}"
    @hands[@round_loser].pop
    if @hands[@round_loser].empty?
      @players.delete(@round_loser)
    end
    puts "Hands: #{@hands.inspect}"
  end
  
  def create_hand
    [].tap do |hand|
      NUMBER_OF_DICE_PER_HAND.times { hand << rand(6) + 1 }
    end
  end
  
  def next_player
    @turn_cursor += 1
    @players[@turn_cursor % @players.size]
  end
end

class Player
  attr_accessor :name, :game
  
  def initialize(name)
    @name = name
  end
  
  def go!
    last_bid = game.bids.last
    if last_bid
      if rand < 0.5
        game.bids << {:player => self, :value => last_bid[:value], :quantity => last_bid[:quantity] + 1}
      else
        game.bids << {:player => self, :value => :challenge}
      end
    else
      game.bids << {:player => self, :value => rand(6) + 1, :quantity => 1}
    end
  end
  
  def to_s
    name
  end
end

# game = Game.new(Player.new("nsrivast"), Player.new("jsomers"))