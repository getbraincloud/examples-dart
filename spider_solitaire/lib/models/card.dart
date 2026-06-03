enum Suit {
  spades('♠', 'S'),
  hearts('♥', 'H'),
  diamonds('♦', 'D'),
  clubs('♣', 'C');

  const Suit(this.symbol, this.code);
  final String symbol;
  final String code;

  bool get isRed => this == hearts || this == diamonds;
}

class Rank {
  const Rank._(this.value, this.label);
  final int value; // Ace = 1, King = 13
  final String label;

  static const ace = Rank._(1, 'A');
  static const two = Rank._(2, '2');
  static const three = Rank._(3, '3');
  static const four = Rank._(4, '4');
  static const five = Rank._(5, '5');
  static const six = Rank._(6, '6');
  static const seven = Rank._(7, '7');
  static const eight = Rank._(8, '8');
  static const nine = Rank._(9, '9');
  static const ten = Rank._(10, '10');
  static const jack = Rank._(11, 'J');
  static const queen = Rank._(12, 'Q');
  static const king = Rank._(13, 'K');

  static const all = <Rank>[
    ace, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king
  ];

  static Rank fromValue(int v) => all[v - 1];
}

class PlayingCard {
  PlayingCard({required this.suit, required this.rank, this.faceUp = false});

  final Suit suit;
  final Rank rank;
  bool faceUp;

  String get shortLabel => '${rank.label}${suit.symbol}';

  @override
  String toString() => '${rank.label}${suit.code}${faceUp ? '' : '?'}';
}
