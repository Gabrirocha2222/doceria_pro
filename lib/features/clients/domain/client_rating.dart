enum ClientRating {
  like('like', 'Like'),
  neutral('neutral', 'Neutro'),
  dislike('dislike', 'Dislike');

  const ClientRating(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ClientRating fromDatabase(String value) {
    return values.firstWhere(
      (rating) => rating.databaseValue == value,
      orElse: () => neutral,
    );
  }
}
