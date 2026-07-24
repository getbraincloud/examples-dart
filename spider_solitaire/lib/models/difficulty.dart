/// Spider Solitaire difficulty levels.
///
/// All variants use a 104-card deck (two standard 52-card decks). The suit
/// count controls how many different suits appear in those 104 cards:
///   - one:  104 cards of a single suit (easiest).
///   - two:  52 cards each of two suits.
///   - four: 26 cards each of all four suits (classic).
enum Difficulty {
  oneSuit('1 Suit', 1),
  twoSuit('2 Suit', 2),
  fourSuit('4 Suit', 4);

  const Difficulty(this.label, this.suitCount);

  final String label;
  final int suitCount;
}
