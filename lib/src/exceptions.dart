part of legit;

class GitException {
  final String message;

  GitException(this.message);
}

class InvalidRevException extends GitException {
  InvalidRevException(String input) : super("Invalid Rev: ${input}");
}
