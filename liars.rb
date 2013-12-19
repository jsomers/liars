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

class BlindOddsBot < Player
  def initialize(name)
    @name = name
  end
  
  def go!
    if latest_bid
      if latest_bid.quantity > dice_in_play / 6
        challenge!
      else
        if latest_bid.value == 6
          bid!(latest_bid.quantity + 1, 1)
        else
          bid!(latest_bid.quantity, latest_bid.value + 1)
        end
      end
    else
      bid!(1, hand[0])
    end
  end
end
  
class SweetSixteenBot < Player
  def initialize(name)
    @name = name
  end
  
  def go!
  myRand = rand
    if latest_bid
      if dice_in_play == 10 || dice_in_play == 9
    if hand[3] == 6 && hand[4] == 6
      if latest_bid.quantity == 1 || (latest_bid.quantity == 2 && latest_bid.value < 6)
        bid!(2, 6)
      elsif latest_bid.quantity == 2 && latest_bid.value == 6
        bid!(3, 6)
      elsif latest_bid.quantity == 3 && latest_bid.value == 6
        bid!(4, 1)
      else
        challenge!
      end
    elsif hand[4] == 6
      if latest_bid.quantity == 1
        if myRand < 0.24416
          bid!(2, 6)
        else
          bid!(2, 1)
        end
      elsif latest_bid.quantity == 2 && latest_bid.value < 6
        if myRand < 0.48832
          bid!(2, 6)
        elsif myRand < 0.63832
          bid!(3, 1)
        else
          challenge!
        end
      elsif latest_bid.quantity == 2 && latest_bid.value == 6
        if myRand < 0.48832
          bid!(3, 6)
        elsif myRand < 0.63832
          bid!(3, 1)
        else
          challenge!
        end
      else
        challenge!
      end
    else
      if latest_bid.quantity == 1
        if myRand < 0.48832
          bid!(2, 6)
        else
          bid!(2, 1)
        end
      elsif latest_bid.quantity == 2 && latest_bid.value < 6
        if myRand < 0.15109
          bid!(2, 6)
        elsif myRand < 0.75109
          bid!(3, 1)
        else
          challenge!
        end
      elsif latest_bid.quantity == 2 && latest_bid.value == 6
        if myRand < 0.05109
          bid!(3, 6)
        elsif myRand < 0.75109
          bid!(3, 1)
        else
          challenge!
        end
      else
        challenge!
      end
    end
    elsif dice_in_play == 8
      if hand[3] == 6 && hand[4] == 6
        if latest_bid.quantity == 1 || (latest_bid.quantity == 2 && latest_bid.value < 6)
          bid!(2, 6)
        elsif latest_bid.quantity == 2 && latest_bid.value == 6
          bid!(3, 6)
        elsif latest_bid.quantity == 3 && latest_bid.value == 6
          bid!(4, 6)
        else
          challenge!
        end
      elsif hand[4] == 6
        if latest_bid.quantity == 1
          if myRand < 0.162773
            bid!(2, 6)
          else
            bid!(2, 1)
          end
        elsif latest_bid.quantity == 2 && latest_bid.value < 6
          if myRand < 0.162773
            bid!(2, 6)
          elsif myRand < 0.53832
            bid!(3, 1)
          else
            challenge!
          end
        elsif latest_bid.quantity == 2 && latest_bid.value == 6
          if myRand < 0.162773
            bid!(3, 6)
          elsif myRand < 0.53832
            bid!(3, 1)
          else
            challenge!
          end
        else
          challenge!
        end
      else
        if latest_bid.quantity == 1
          if myRand < 0.162773
            bid!(2, 6)
          else
            bid!(2, 1)
          end
        elsif latest_bid.quantity == 2 && latest_bid.value < 6
          if myRand < 0.15109
            bid!(2, 6)
          elsif myRand < 0.45109
            bid!(3, 1)
          else
            challenge!
          end
        elsif latest_bid.quantity == 2 && latest_bid.value == 6
          if myRand < 0.15109
            bid!(3, 6)
          elsif myRand < 0.45109
            bid!(3, 1)
          else
            challenge!
          end
        else
          challenge!
        end
      end
    elsif dice_in_play == 7
      if hand[hand.size - 2] == 6 && hand[hand.size - 1] == 6
        if latest_bid.quantity == 1 || (latest_bid.quantity == 2 && latest_bid.value < 6)
          bid!(2, 6)
        elsif latest_bid.quantity == 2 && latest_bid.value == 6
          bid!(3, 6)
        else
          challenge!
        end
      elsif hand[hand.size - 1] == 6
        if latest_bid.quantity == 1
          if myRand < 0.162773
            bid!(2, 6)
          else
            bid!(2, 1)
          end
        elsif latest_bid.quantity == 2 && latest_bid.value < 6
          if myRand < 0.162773
            bid!(2, 6)
          elsif myRand < 0.43832
            bid!(3, 1)
          else
            challenge!
          end
        elsif latest_bid.quantity == 2 && latest_bid.value == 6
          if myRand < 0.162773
            bid!(3, 6)
          elsif myRand < 0.43832
            bid!(3, 1)
          else
            challenge!
          end
        else
          challenge!
        end
      else
        if latest_bid.quantity == 1
          if myRand < 0.102773
            bid!(2, 6)
          else
            bid!(2, 1)
          end
        elsif latest_bid.quantity == 2 && latest_bid.value < 6
          if myRand < 0.10109
            bid!(2, 6)
          elsif myRand < 0.35109
            bid!(3, 1)
          else
            challenge!
          end
        elsif latest_bid.quantity == 2 && latest_bid.value == 6
          if myRand < 0.10109
            bid!(3, 6)
          elsif myRand < 0.35109
            bid!(3, 1)
          else
            challenge!
          end
        else
          challenge!
        end
      end
    else
      if latest_bid.quantity == 1 && latest_bid.value < 6
        if myRand < 0.333
          bid!(1, 6)
        elsif myRand < 0.666
          bid!(2, 1)
        else
          challenge!
        end
      elsif (latest_bid.quantity == 1 && latest_bid.value == 6) || (latest_bid.quantity == 2 && latest_bid.value < 6)
        if myRand < 0.333
          bid!(2, 6)
        else
          challenge!
        end
      else
        challenge!
      end
    end
    else
    if hand[hand.size - 2] == 6 && hand[hand.size - 1] == 6
      bid!(2, 6)
    elsif hand[hand.size - 1] == 6
      if myRand < 0.651937
        bid!(1, 6)
      else
        bid!(1, 1)
      end
    else
      if myRand < 0.351937
        bid!(1, 6)
      else
        bid!(1, 1)
      end
    end
    end
  end
end

class JimboBot < Player
  def go!
    # Start with logic similar to Nikhil's BlindOddsBot
    # Update probability of n dice of value k based on own hand, 
    # and on other players' bids, conditioned on their reliability in the past,
    # and on depth into round (earlier bids are less reliable).
  end
end

class FlowBot < Player
  # This bot just tries to go with the flow of the game
  # Also it's a play on the name of the band "Flobots" (http://en.wikipedia.org/wiki/Flobots)
  # Also it plays "blind", not looking at its own hand, and therefore is pretty dumb

  def initialize(name)
    @name = name
  end
  
  def go!
    if latest_bid
      if rand > (latest_bid.quantity / dice_in_play)
        bids_array = bids.map { |b| b.value }
        freq_array = [0.0,0.0,0.0,0.0,0.0,0.0]
        bids_array.each { |v| freq_array[v-1] += 1 }
        freq_array_pct = freq_array.collect { |n| n / bids_array.length }

        if freq_array_pct.max > 0.6
          flow_bid = freq_array_pct.index(freq_array_pct.max) + 1

          if flow_bid > latest_bid.value
            bid!(latest_bid.quantity, flow_bid)
          else
            bid!(latest_bid.quantity + 1, flow_bid)
          end
        else
          if latest_bid.value != 6
            bid!(latest_bid.quantity, latest_bid.value + 1)
          else
            bid!(latest_bid.quantity + 1, 1)
          end
        end
      else
        challenge!
      end
    else
      bid!(1, 1)
    end
  end
end

class BayesBot < Player
  # This is Adam's awesome bot. Its tactics are secret. Don't peek!
  # Although you can probably figure out its high-level strategy from the name.
  
  def initialize(name)
    @name = name
  end
 
  def go!
  
    #prevent code from breaking due to dumb bids
    if latest_bid
      if latest_bid.quantity > dice_in_play
        challenge!
        return
      end
      if latest_bid.quantity == dice_in_play and latest_bid.value == 6
        challenge!
        return
      end
    end
    
    #set initial priors
    five_priors = [0.401877572016461,0.401877572016461,0.160751028806584,0.0321502057613169,0.00321502057613169,0.000128600823045268]
    four_priors = [0.482253086419753,0.385802469135803,0.115740740740741,0.0154320987654321,0.000771604938271605]
    three_priors = [0.578703703703704,0.347222222222222,0.0694444444444445,0.00462962962962963]
    two_priors = [0.694444444444445,0.277777777777778,0.0277777777777778]
    one_priors = [0.833333333333333,0.166666666666667]
    all_priors = [one_priors,two_priors,three_priors,four_priors,five_priors]
    #individual hand tables
    all_odds = {}
    number_of_dice_per_player.each do |name,num_dice|
      all_odds[name] = []
      6.times do |n|
        all_odds[name] << all_priors[num_dice-1].dup
      end
    end
    
    #initialize tables
    my_hand_odds = create_hand_table(hand)
    public_odds_prob = aggregate_table(all_odds,"public",my_hand_odds,"","","")
    public_odds_cum = make_table_cum(public_odds_prob)
    real_odds_prob = aggregate_table(all_odds,"real",my_hand_odds,"","","")
    real_odds_cum = make_table_cum(real_odds_prob)
    
    #adjust hand probabilities
    bids.each do |b|
      new_all_odds = create_new_hash(all_odds)
      #update bid value probabilities
      for i in 0..number_of_dice_per_player[b.player]
        #prior on dice in hand
        prior_dice_in_hand_prob = all_odds[b.player][b.value-1][i]
        #prior on bid
        prior_bid_prob = public_odds_cum[b.value-1][b.quantity]
        #conditional prob of bid given dice in hand
        hypo_hand = []
        for j in 1..i
          hypo_hand << b.value
        end
        for j in (i+1)..number_of_dice_per_player[b.player]
          hypo_hand << (b.value + 1) % 6
        end
        hypo_player_table = create_hand_table(hypo_hand)
        hypo_agg_prob_table = aggregate_table(all_odds,"hypothetical",my_hand_odds,b.player,hypo_player_table,hypo_hand.length)
        hypo_agg_cum_table = make_table_cum(hypo_agg_prob_table)
        cond_prob = hypo_agg_cum_table[b.value-1][b.quantity]
        #calculate new probability using Bayes theorem
        updated_probability = prior_dice_in_hand_prob * cond_prob / prior_bid_prob
        new_all_odds[b.player][b.value-1][i] = updated_probability
        #adjust other probabilities proportionally
        proportional_sum = 0
        for k in 1..6
          proportional_sum += all_odds[b.player][k-1][i] 
        end
        for k in 1..6
          if k != b.value
            new_all_odds[b.player][k-1][i] = all_odds[b.player][k-1][i] - ((all_odds[b.player][k-1][i] / proportional_sum) * (new_all_odds[b.player][b.value-1][i] - all_odds[b.player][b.value-1][i]))
          end
        end
      end
      all_odds = create_new_hash(new_all_odds)
      public_odds_prob = aggregate_table(all_odds,"public",my_hand_odds,"","","")
      public_odds_cum = make_table_cum(public_odds_prob)
      real_odds_prob = aggregate_table(all_odds,"real",my_hand_odds,"","","")
      real_odds_cum = make_table_cum(real_odds_prob)
    end
	
    #p real_odds_cum
    
    #set strategy
    #more strategies to come later once the other bots catch up
    strategy = "safe"
      
    best_odds = 0
    if latest_bid
      if latest_bid.value == 6
        start_quantity = latest_bid.quantity + 1
        start_value = 1
      else
        start_quantity = latest_bid.quantity
        start_value = latest_bid.value + 1
      end
    else
      start_quantity = 1
      start_value = 1
    end
      
    #make decision
    if strategy == "safe"
      for a in start_quantity..dice_in_play
        for b in 1..6
          if a != start_quantity or b >= start_value
            if real_odds_cum[b-1][a] > best_odds
              best_odds = real_odds_cum[b-1][a]
              best_quantity = a
              best_value = b
            end
            if real_odds_cum[b-1][a] == best_odds and start_quantity == a and start_value == b
              best_quantity = a
              best_value = b
            end
          end
        end
      end
      if latest_bid
        if (1-real_odds_cum[latest_bid.value-1][latest_bid.quantity]) > real_odds_cum[best_value-1][best_quantity]
          challenge!
        else
          bid!(best_quantity, best_value)
        end
      else
        bid!(best_quantity, best_value)
      end
    end
  end
  
  def aggregate_table(all_odds,table_type,my_hand_odds,hypothetical_player,hypothetical_hand,hypothetical_hand_size)
    temp_all_odds = create_new_hash(all_odds)
    temp_dice_in_play = dice_in_play
    temp_number_of_dice_per_player = number_of_dice_per_player
    
    if table_type == "real"
      temp_all_odds[self] = my_hand_odds
    elsif table_type == "hypothetical"
      temp_all_odds[hypothetical_player] = hypothetical_hand
      temp_dice_in_play -= number_of_dice_per_player[hypothetical_player] 
      temp_dice_in_play += hypothetical_hand_size
      temp_number_of_dice_per_player[hypothetical_player] = hypothetical_hand_size
    end
  
		#initialize aggregate table to 0's
		aggregate_odds_prob = []
		for i in 1..6
			face_odds = []
			for j in 0..temp_dice_in_play
				face_odds << 0
			end
			aggregate_odds_prob << face_odds
		end
	
		for j in 0...6 
			#initialize iter_dice to 0
			iter_dice = {}
			players.each do |name|
				iter_dice[name] = 0
			end
	
			#calculate
			while iter_dice[players[0]] <= temp_number_of_dice_per_player[players[0]]
				temp_sum = 0	
				temp_product = 1
				players.each do |name|
					temp_sum += iter_dice[name]
					temp_product *= temp_all_odds[name][j][iter_dice[name]]
				end
				aggregate_odds_prob[j][temp_sum] += temp_product
				iter_dice[players[players.length-1]] += 1
				k = players.length - 1
				while k >= 0
					if iter_dice[players[k]] > temp_number_of_dice_per_player[players[k]]
						if k > 0
							iter_dice[players[k]] = 0
              iter_dice[players[k-1]] += 1
            end
          end
					k -= 1
				end
			end
			j += 1
		end
    
		return aggregate_odds_prob

  end
  
  def make_table_cum(prob_table)
    cum_table = Marshal.load(Marshal.dump(prob_table))
    for x in 0...cum_table.length
      for y in 0...cum_table[x].length
        for z in (y+1)...cum_table[x].length
          cum_table[x][y] += prob_table[x][z]
        end
      end
    end
    return cum_table
  end
  
  def create_hand_table(target_hand)
    hand_odds = [[],[],[],[],[],[]]
    for x in 1..6
      num_same = target_hand.count(x)
      for y in 0..target_hand.length
        if y == num_same
          hand_odds[x-1] << 1
        else
          hand_odds[x-1] << 0
        end
      end
    end
    return hand_odds
  end
  
  def create_new_hash(old_hash)
    new_hash = {}
    old_hash.each do |key, value|
      new_hash[key] = Marshal.load(Marshal.dump(value))
    end
    return new_hash
  end

end
