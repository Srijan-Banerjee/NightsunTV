import 'dart:math' as math;

/// Text helpers shared by the catalog, search and UI.
///
/// The search index deliberately avoids locale-sensitive APIs: channel names
/// come from dozens of languages and we want stable behaviour on every device.
const Map<String, String> _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a', 'ǎ': 'a', 'ǟ': 'a', 'ǡ': 'a', 'ǻ': 'a', 'ȁ': 'a',
  'ȃ': 'a', 'ȧ': 'a', 'ạ': 'a', 'ả': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a',
  'ẫ': 'a', 'ậ': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
  'æ': 'ae', 'ǽ': 'ae',
  'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd', 'ð': 'd', 'ȡ': 'd', 'ɗ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
  'ę': 'e', 'ě': 'e', 'ȅ': 'e', 'ȇ': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
  'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e', 'ə': 'e',
  'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g', 'ǧ': 'g', 'ǵ': 'g', 'ĥ': 'h',
  'ħ': 'h', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i',
  'ĭ': 'i', 'į': 'i', 'ı': 'i', 'ǐ': 'i', 'ȉ': 'i', 'ȋ': 'i', 'ỉ': 'i',
  'ị': 'i', 'ĳ': 'ij', 'ĵ': 'j', 'ķ': 'k', 'ĸ': 'k', 'ł': 'l', 'ĺ': 'l',
  'ļ': 'l', 'ľ': 'l', 'ŀ': 'l', 'ǉ': 'lj', 'ñ': 'n', 'ń': 'n', 'ņ': 'n',
  'ň': 'n', 'ŉ': 'n', 'ŋ': 'n', 'ǌ': 'nj', 'ò': 'o', 'ó': 'o', 'ô': 'o',
  'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o', 'ơ': 'o',
  'ǒ': 'o', 'ǫ': 'o', 'ǭ': 'o', 'ȍ': 'o', 'ȏ': 'o', 'ȫ': 'o', 'ȭ': 'o',
  'ȯ': 'o', 'ȱ': 'o', 'ọ': 'o', 'ỏ': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o',
  'ỗ': 'o', 'ộ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
  'œ': 'oe', 'ŕ': 'r', 'ŗ': 'r', 'ř': 'r', 'ș': 's', 'ś': 's', 'ŝ': 's',
  'ş': 's', 'š': 's', 'ß': 'ss', 'ţ': 't', 'ť': 't', 'ŧ': 't', 'ț': 't',
  'þ': 'th', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u',
  'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u', 'ư': 'u', 'ǔ': 'u', 'ǖ': 'u',
  'ǘ': 'u', 'ǚ': 'u', 'ǜ': 'u', 'ȕ': 'u', 'ȗ': 'u', 'ụ': 'u', 'ủ': 'u',
  'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u', 'ŵ': 'w', 'ý': 'y',
  'ÿ': 'y', 'ŷ': 'y', 'ȳ': 'y', 'ỳ': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z', 'ȥ': 'z',
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
  'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
  'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  'α': 'a', 'β': 'b', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'ζ': 'z', 'η': 'e',
  'θ': 'th', 'ι': 'i', 'κ': 'k', 'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'x',
  'ο': 'o', 'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'τ': 't', 'υ': 'y',
  'φ': 'f', 'χ': 'ch', 'ψ': 'ps', 'ω': 'o',
};

final RegExp _wordChar = RegExp(r'^[\p{L}\p{N}\p{M}]$', unicode: true);
final RegExp _spaces = RegExp(r'\s+');
final RegExp _asciiAlphaNumeric = RegExp(r'^[a-z0-9]$');

/// Lower-cases, strips accents and turns punctuation into separators.
///
/// Scripts that are not transliterated (Arabic, Devanagari, Chinese…) are kept
/// intact so native-language searches still work. Combining marks are kept
/// attached to their base letter.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final replacement = _diacritics[char];
    if (replacement != null) {
      buffer.write(replacement);
    } else if (char == '&') {
      buffer.write(' and ');
    } else if (char == "'" || char == '’' || char == '‘') {
      // Keep words joined: "O'Brien" is searched as "obrien".
    } else if (_asciiAlphaNumeric.hasMatch(char)) {
      buffer.write(char);
    } else if (rune > 127 && _wordChar.hasMatch(char)) {
      buffer.write(char);
    } else {
      buffer.write(' ');
    }
  }
  return buffer
      .toString()
      .replaceAll(_spaces, ' ')
      .trim();
}

/// A no-space variant used to match names such as "BBC One" with "bbcone".
String compactForSearch(String value) =>
    normalizeForSearch(value).replaceAll(' ', '');

/// One or two initials for logo fallbacks.
String channelInitials(String name) {
  final cleaned = name.replaceAll(RegExp(r'^[^a-zA-Z0-9]+'), '').trim();
  if (cleaned.isEmpty) return 'TV';
  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty && _wordChar.hasMatch(String.fromCharCode(word.runes.first)))
      .toList();
  if (words.isEmpty) return 'TV';
  String firstChar(String word) => String.fromCharCode(word.runes.first).toUpperCase();
  final first = firstChar(words.first);
  if (words.length == 1) {
    final compact = words.first.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    final runes = compact.runes.toList();
    return runes.length >= 2
        ? String.fromCharCodes(runes.take(2)).toUpperCase()
        : first;
  }
  return '$first${firstChar(words[1])}';
}

/// Thousands separators without pulling in an intl dependency.
String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

String formatShortDate(DateTime? date) {
  if (date == null) return 'Unknown';
  final local = date.toLocal();
  return '${_months[local.month - 1]} ${local.year}';
}

String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 5) return 'Late night';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 22) return 'Good evening';
  return 'Late night';
}

String pluralize(int count, String singular, [String? plural]) {
  if (count == 1) return '1 $singular';
  return '$count ${plural ?? '${singular}s'}';
}

/// Stable accent hue so a channel keeps the same fallback colour everywhere.
int stableHue(String seed, {int spread = 360}) {
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash % math.max(1, spread);
}

String readableException(Object error) {
  final text = error.toString();
  if (text.startsWith('Exception: ')) return text.substring(11);
  return text;
}
