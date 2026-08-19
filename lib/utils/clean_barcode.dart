/// Cleans and normalizes barcode input while preserving exact raw input.
/// 1. Prioritizes exact raw input and punctuation-cleaned raw input.
/// 2. Removes literal modifier key string artifacts (e.g. "ShiftF1024ShiftJ33744" -> "F1024J33744").
/// 3. Maps Shifted top-row Mongolian keyboard symbols (!,№,₮,%,*,(,)) and Cyrillic keys to EN QWERTY only if Cyrillic/symbols are present.
List<String> getBarcodeCandidates(String? input) {
  if (input == null || input.trim().isEmpty) return const [];
  final raw = input.trim();
  final Set<String> candidates = {raw};

  final punctRegex = RegExp(r'^[\s,.;:"\\/!\-_+]+|[\s,.;:"\\/!\-_+]+$');
  final cleanRaw = raw.replaceAll(punctRegex, '');
  if (cleanRaw.isNotEmpty) {
    candidates.add(cleanRaw);
  }

  // Remove literal "Shift", "Control", "Alt", "CapsLock", "Meta" string artifacts
  String noModifier = raw.replaceAll(
      RegExp(r'Shift|Control|Alt|CapsLock|Meta', caseSensitive: false), '');
  noModifier = noModifier.trim();
  if (noModifier.isNotEmpty) {
    candidates.add(noModifier);
    final noModifierClean = noModifier.replaceAll(punctRegex, '');
    if (noModifierClean.isNotEmpty) candidates.add(noModifierClean);
  }

  if (RegExp(r'[а-яА-ЯөӨүҮ№₮!"%*()?:]').hasMatch(raw)) {
    const mnToEn = <String, String>{
      'ф': 'q', 'ц': 'w', 'у': 'e', 'ж': 'r', 'э': 't', 'н': 'y', 'г': 'u', 'ш': 'i',
      'щ': 'o', 'з': 'p', 'х': 'h', 'ъ': ']', 'й': 'a', 'ы': 's', 'б': 'd', 'ө': 'f',
      'а': 'g', 'р': 'j', 'о': 'k', 'л': 'l', 'д': ';', 'я': 'z', 'ч': 'x', 'ё': 'c',
      'с': 'v', 'м': 'b', 'и': 'n', 'т': 'm', 'ь': ',', 'ю': '/', 'в': 'd', 'п': 'g',
      'к': 'r', 'е': 'e', 'ү': 'u',
      'Ф': 'Q', 'Ц': 'W', 'У': 'E', 'Ж': 'R', 'Э': 'T', 'Н': 'Y', 'Г': 'U', 'Ш': 'I',
      'Щ': 'O', 'З': 'P', 'Х': 'H', 'Ъ': '}', 'Й': 'A', 'Ы': 'S', 'Б': 'D', 'Ө': 'F',
      'А': 'G', 'Р': 'J', 'О': 'K', 'Л': 'L', 'Д': ':', 'Я': 'Z', 'Ч': 'X', 'Ё': 'C',
      'С': 'V', 'М': 'B', 'И': 'N', 'Т': 'M', 'Ь': '<', 'Ю': '?', 'В': 'D', 'П': 'G',
      'К': 'R', 'Е': 'E', 'Ү': 'U'
    };

    const shiftedNumMap = <String, String>{
      '!': '1',
      '"': '2',
      '№': '3',
      '₮': '4',
      '%': '5',
      ':': '6',
      '?': '7',
      '*': '8',
      '(': '9',
      ')': '0'
    };

    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (shiftedNumMap.containsKey(char)) {
        sb.write(shiftedNumMap[char]);
      } else if (mnToEn.containsKey(char)) {
        sb.write(mnToEn[char]);
      } else {
        sb.write(char);
      }
    }

    final converted = sb.toString().replaceAll(punctRegex, '').trim();
    if (converted.isNotEmpty) candidates.add(converted);
  }

  return candidates.toList();
}

String cleanBarcode(String? input) {
  if (input == null || input.trim().isEmpty) return '';
  final raw = input.trim();
  final punctRegex = RegExp(r'^[\s,.;:"\\/!\-_+]+|[\s,.;:"\\/!\-_+]+$');
  final cleanRaw = raw.replaceAll(punctRegex, '');
  if (cleanRaw.isNotEmpty) return cleanRaw;
  return raw;
}
