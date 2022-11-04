require 'test/unit'

class Card
  include Comparable
 
  attr_reader :suit, :value

  # Value to use as ace low
  ACE_LOW = 1

  # Value to use as ace high
  ACE_HIGH = 14

  # initialize the card with a suit and a value
  def initialize suit, value
    super()
    @suit = suit
    @value = value
  end

  # Return the low card
  def low_card
    ace? ? Card.new(suit, ACE_LOW) : self
  end

  # Return if the card is an ace high
  def ace?
    value == ACE_HIGH
  end

  def ace_low?
    value == ACE_LOW
  end

  # Return if the card has suit spades
  def spades?
    suit == :spades
  end

  # Return if the card has suit diamonds
  def diamonds?
    suit == :diamonds
  end

  # Return if the card is suit hearts
  def hearts?
    suit == :hearts
  end

  # Return if the card has suit clubs
  def clubs?
    suit == :clubs
  end

  # Compare cards based on values and suits
  # Ordered by suits and values - the suits_index will be introduced below
  def <=> other
    if other.is_a? Card
      (suit_index(suit) <=> suit_index(other.suit)).nonzero? || value <=> other.value
    else
      value <=> other
    end
  end

  # Allow for construction of card ranges across suits
  # the suits_index will be introduced below
  def succ
    if ace?
      i = suit_index suit
      Card.new(Deck::SUITS[i + 1] || Deck::SUITS.first, ACE_LOW)
    else
      Card.new(suit, value + 1)
    end
  end

  def successor? other
    !ace? && succ == other
  end

  def straight_successor? other
    !ace? && succ === other
  end

  # Compare cards for equality in value
  def == other
    if other.is_a? Card
      value == other.value
    else
      value == other
    end
  end
  alias :eql? :==

  # overwrite hash with value since cards with same values are considered equal
  alias :hash :value

  # Compare cards for strict equality (value and suit)
  def === other
    if other.is_a? Card
      value == other.value && suit == other.suit
    else
      false
    end
  end
  
  private
  
  # If no deck, this has to be done with an array of suits
  # gets the suit index
  def suit_index suit
    Deck::SUITS.index suit
  end
end

class Hand < Array

  # .. RANKS
  RANKS = {
    straight_flush:  8,
    four_of_a_kind:  7,
    full_house:      6,
    flush:           5,
    straight:        4,
    three_of_a_kind: 3,
    two_pair:        2,
    pair:            1
  }.freeze

  def initialize(*cards)
    raise ArgumentError.new "There must be 5 cards" unless cards.count == 5
    super(cards)
    sort_by! &:value # This will give you a nicely sorted hand by default
    freeze
  end

  # The hand's rank as an array containing the hand's
  # type and that type's base score
  def rank
    RANKS.detect { |method, rank| send :"#{method}?" } || [:high_card, 0]
  end

  # The hand's type (e.g. :flush or :pair)
  def type
    rank.first
  end

  # The hand's base score (based on rank)
  def base_score
    rank.last
  end

  # The hand's score is an array starting with the
  # base score, followed by the kickers.
  def score
    ([base_score] + kickers.map(&:value))
  end

  # Tie-breaking kickers, ordered high to low.
  def kickers
    same_of_kind + (aces_low? ? aces_low.reverse : single_cards.reverse)
  end

  # If the hand's straight and flush, it's a straight flush
  def straight_flush?
    straight? && flush?
  end

  # Is a value repeated 4 times?
  def four_of_a_kind?
    same_of_kind? 4
  end

  # Three of a kind and a pair make a full house
  def full_house?
    same_of_kind?(3) && same_of_kind?(2)
  end

  # If the hand only contains one suit, it's flush
  def flush?
    suits.uniq.one?
  end
  
  # single cards in the hand
  def single_cards
    select{ |c| count(c) == 1 }.sort_by(&:value)
  end

  # This is the only hand where high vs low aces comes into play.
  def straight?
    aces_high_straight? || aces_low_straight?
  end

  # Is a card value repeated 3 times?
  def three_of_a_kind?
    collapsed_size == 2 && same_of_kind?(3)
  end

  # Are there 2 instances of repeated card values?
  def two_pair?
    collapsed_size == 2 && same_of_kind?(2)
  end

  # Any repeating card value?
  def pair?
    same_of_kind?(2)
  end

  # Does the hand include one or more aces?
  def aces?
    any? &:ace?
  end

  # Ordered (low to high) array of card values (assumes aces high)
  def values
    map(&:value).sort
  end

  # Ordered Array of card suits
  def suits
    sort.map &:suit
  end

  # A "standard" straight, treating aces as high
  def aces_high_straight?
    all?{|card| card === last || card.successor?(self[index(card) + 1]) }
  end
  alias :all_successors? :aces_high_straight?

  # Special case straight, treating aces as low
  def aces_low_straight?
    aces? && aces_low.all_successors?
  end
  alias :aces_low? :aces_low_straight?

  # The card values as an array, treating aces as low
  def aces_low
    Hand.new *map(&:low_card)
  end

  private

  # Are there n cards of the same kind?
  def same_of_kind?(n)
    !!detect{|card| count(card) == n }
  end
  
  def same_of_kind
    2.upto(4).map{|n| select{|card| count(card) == n }.reverse }.sort_by(&:size).reverse.flatten.uniq
  end

  # How many cards vanish if we collapse the cards to single values
  def collapsed_size
    size - uniq.size
  end
  
end

class Deck < Array
  # the hands this deck creates
  attr_reader :hands
  
  # You can install any order here, Bridge, Preferans, Five Hundred
  SUITS = %i(clubs diamonds hearts spades).freeze

  # Initialize a deck of cards
  def initialize
    super (Card.new(SUITS.first, 1)..Card.new(SUITS.last, 14)).to_a
    shuffle!
  end

  # Deal n hands
  def deal! hands=5
    @hands = hands.times.map {|i| Hand.new *pop(5) }
  end
  
  # ... and so on
end

# ================================================================================================

class TestHand < Test::Unit::TestCase
  # Helpers for generating Card instances
  # from short-hand notation
  def card(string)
    suit = case string
    when /^h/i then :hearts
    when /^d/i then :diamonds
    when /^c/i then :clubs
    when /^s/i then :spades
    else raise ArgumentError
    end
    value = string[1..-1].to_i
    raise ArgumentError unless (2..14).cover? value
    Card.new suit, value
  end
  
  def cards(string)
    string.split(/[^hdcs\d]/i).map { |str| card str }
  end
  
  # ======
  
  def test_aces?
    hand = Hand.new *cards("h2 h3 h4 h5 h6")
    assert !hand.aces?, "#aces? should be false"
    hand = Hand.new *cards("h2 h3 h4 h5 h14")
    assert hand.aces?, "#aces? should be true"
  end
  
  def test_values
    hand = Hand.new *cards("h2 c2 h4 s5 h10")
    assert_equal [2, 2, 4, 5, 10], hand.values
  end
  
  def test_suits
    hand = Hand.new *cards("h2 c2 h4 s5 h10")
    assert_equal [:clubs, :hearts, :hearts, :hearts, :spades], hand.suits
  end
  
  def test_straight_flush
    hand = Hand.new *cards("h2 h3 h4 h5 h6")
    assert hand.straight_flush?, "Hand should be a straight flush"
    assert_equal :straight_flush, hand.type, "Type should by :straight_flush"
    assert_equal [8, 6, 5, 4, 3, 2], hand.score, "Score should be the base score followed by the values, descending"
  end
  
  def test_straight_flush_aces_high
    hand = Hand.new *cards("h14 h10 h11 h12 h13")
    assert hand.straight_flush?, "Hand should be a straight flush"
    assert_equal :straight_flush, hand.type, "Type should by :straight_flush"
    assert_equal [8, 14, 13, 12, 11, 10], hand.score, "Score should be the base score followed by the values, descending"
  end
  
  def test_straight_flush_aces_low
    hand = Hand.new *cards("h14 h2 h3 h4 h5")
    assert hand.straight_flush?, "Hand should be a straight flush"
    assert_equal :straight_flush, hand.type, "Type should by :straight_flush"
    assert_equal [8, 5, 4, 3, 2, 1], hand.score, "Score should be the base score followed by the values (aces low), descending"
  end
  
  def test_four_of_a_kind
    hand = Hand.new *cards("h3 d3 c3 s3 c11")
    assert hand.four_of_a_kind?, "Hand should contain four of a kind"
    assert_equal :four_of_a_kind, hand.type, "Type should by :four_of_a_kind"
    assert_equal [7, 3, 11], hand.score, "Score should be base score followed by the repeated value, then the remaining value"
  end
  
  def test_full_house
    hand = Hand.new *cards("h3 d3 c3 s11 c11")
    assert hand.full_house?, "Hand should be a full house"
    assert_equal :full_house, hand.type, "Type should by :full_house"
    assert_equal [6, 3, 11], hand.score, "Score should be base score followed by the thrice repeated value, then the twice repeated value"
  end
  
  def test_flush
    hand = Hand.new *cards("c2 c3 c6 c7 c11")
    assert hand.flush?, "Hand should be flush"
    assert_equal :flush, hand.type, "Type should by :flush"
    assert_equal [5, 11, 7, 6, 3, 2], hand.score, "Score should be base score followed by the values, descending"
  end
  
  def test_straight
    hand = Hand.new *cards("c3 c4 s5 h6 c7")
    assert hand.straight?, "Hand should be straight"
    assert_equal :straight, hand.type, "Type should by :straight"
    assert_equal [4, 7, 6, 5, 4, 3], hand.score, "Score should be base score followed by the values, descending"
  end
  
  def test_straight_aces_high
    hand = Hand.new *cards("c10 c11 s12 h13 c14")
    assert hand.straight?, "Hand should be an aces-high straight"
    assert_equal [4, 14, 13, 12, 11, 10], hand.score, "Score should be base score followed by the values, descending"
  end
  
  def test_straight_aces_low
    hand = Hand.new *cards("c14 c2 s3 h4 c5")
    assert_equal [4, 5, 4, 3, 2, 1], hand.score, "Score should be base score followed by the values, descending"
  end
  
  def test_three_of_a_kind
    hand = Hand.new *cards("h3 d3 c3 s10 c11")
    assert hand.three_of_a_kind?, "Hand should contain three of a kind"
    assert_equal :three_of_a_kind, hand.type, "Type should by :three_of_a_kind"
    assert_equal [3, 3, 11, 10], hand.score, "Score should be base score followed by the repeated value, then the remaining values, descending"
  end
  
  def test_two_pair
    hand = Hand.new *cards("h3 d3 c10 s10 c11")
    assert hand.two_pair?, "Hand should contain two pairs"
    assert_equal :two_pair, hand.type, "Type should by :two_pair"
    assert_equal [2, 10, 3, 11], hand.score, "Score should be base score followed by the repeated values, descending, then the remaining values, descending"
  end
  
  def test_pair
    hand = Hand.new *cards("h3 d3 c9 s10 c11")
    assert hand.pair?, "Hand should contain a pair"
    assert_equal :pair, hand.type, "Type should by :pair"
    assert_equal [1, 3, 11, 10, 9], hand.score, "Score should be base score followed by the paired value, then the remaining values, descending"
  end
  
  def test_poor_hand
    hand = Hand.new *cards("h3 d4 c7 s8 c11")
    assert_equal :high_card, hand.type, "Type should by :high_card"
    assert_equal [0, 11, 8, 7, 4, 3], hand.score, "Score should be base score followed by the values, descending"
  end
end