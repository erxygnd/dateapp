String buildChatId(String firstUid, String secondUid) {
  // Iki UID'yi siralayinca A_B de B_A de ayni chatId olur.
  // Boylece ayni iki kisi icin yanlislikla iki farkli sohbet acilmaz.
  final ids = [firstUid, secondUid]..sort();
  return "${ids[0]}_${ids[1]}";
}
