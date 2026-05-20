String buildChatId(String firstUid, String secondUid) {
  final ids = [firstUid, secondUid]..sort();
  return "${ids[0]}_${ids[1]}";
}
