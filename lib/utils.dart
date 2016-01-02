library legit.utils;

bool onlyOneTrue(List<bool> inputs) {
  return inputs.where((it) => it).length == 1;
}

String stripNewlines(String input) => input.replaceAll("\n", "");
