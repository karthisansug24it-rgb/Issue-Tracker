class CommentModel {
  final int id;
  final int issueId;
  final int authorId;
  final String authorName;
  final String commentText;
  final String createdAt;

  CommentModel({
    required this.id,
    required this.issueId,
    required this.authorId,
    required this.authorName,
    required this.commentText,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? 0,
      issueId: json['issueId'] ?? 0,
      authorId: json['authorId'] ?? 0,
      authorName: json['authorName'] ?? 'User',
      commentText: json['commentText'] ?? '',
      createdAt: json['createdAt'] != null
          ? json['createdAt'].toString().substring(0, 10)
          : 'Today',
    );
  }
}
