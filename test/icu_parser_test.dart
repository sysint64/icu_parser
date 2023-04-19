import 'package:icu_parser/icu_parser.dart';
import 'package:icu_parser/intl_message.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';

class MyIcuParser {
  final pluralAndGenderParser = IcuParser().message;
  final plainParser = IcuParser().nonIcuMessage;

  String? parse(String data, String locale, [Map<String, Object> args = const {}]) {
    Object parsed = pluralAndGenderParser.parse(data).value as Object;

    if (parsed is LiteralString && parsed.string.isEmpty) {
      parsed = plainParser.parse(data).value as Object;
    }

    final message = MainMessage();
    message.addPieces([parsed]);
    message.arguments = args.keys.toList();

    return _visit(message, locale, args);
  }

  String? _visit(Message? message, String locale, Map<String, Object> args) {
    if (message == null) {
      return null;
    }

    if (message is MainMessage) {
      return _visit(message.messagePieces[0], locale, args);
    } else if (message is LiteralString) {
      return message.string;
    } else if (message is CompositeMessage) {
      return message.pieces!.map((piece) => _visit(piece, locale, args)).join();
    } else if (message is VariableSubstitution) {
      if (message.index == null) {
        return '{${message.variableNameFromParser}}';
      }
      assert(
          args.containsKey(message.variableName), 'Argument ${message.variableName} is required');
      return args[message.variableName!].toString();
    } else if (message is Plural) {
      final zero = _visit(message.zero, locale, args);
      final one = _visit(message.one, locale, args);
      final two = _visit(message.two, locale, args);
      final few = _visit(message.few, locale, args);
      final many = _visit(message.many, locale, args);
      final other = _visit(message.other, locale, args)!;

      assert(
          args.containsKey(message.mainArgument), 'Argument ${message.mainArgument} is required');
      assert(args[message.mainArgument!] is num,
          'Argument ${message.mainArgument} should be a number');

      return Intl.plural(
        args[message.mainArgument!] as num,
        zero: zero,
        one: one,
        two: two,
        few: few,
        many: many,
        other: other,
        locale: locale,
      );
    } else if (message is Gender) {
      assert(
          args.containsKey(message.mainArgument), 'Argument ${message.mainArgument} is required');

      final female = _visit(message.female, locale, args);
      final male = _visit(message.male, locale, args);
      final other = _visit(message.other, locale, args)!;

      return Intl.gender(
        args[message.mainArgument!] as String,
        female: female,
        male: male,
        other: other,
        locale: locale,
      );
    } else if (message is Select) {
      final cases = <String, String>{};

      for (final key in message.cases.keys) {
        if (key != null) {
          cases[key] = _visit(message.cases[key], locale, args) ?? '';
        }
      }

      return Intl.select(
        args[message.mainArgument!]!,
        cases,
        locale: locale,
      );
    } else {
      throw StateError('Unknown message type: ${message.runtimeType}');
    }
  }
}

void main() {
  final icuParser = MyIcuParser();
  test('parse simple messages', () async {
    expect(icuParser.parse('Some text', 'en_US'), 'Some text');
  });

  test('parse variable substitution', () async {
    expect(
      icuParser.parse(
        'We’ve sent you\nan sms with the code to {phone}',
        'en_US',
        {'phone': '+79131234567'},
      ),
      'We’ve sent you\nan sms with the code to +79131234567',
    );
    expect(
      icuParser.parse(
        'your phone is: {phone}, we sent sms to your phone: {phone}',
        'en_US',
        {'phone': '+79131234567'},
      ),
      'your phone is: +79131234567, we sent sms to your phone: +79131234567',
    );

    expect(
      icuParser.parse(
        'Your phone is {phone}, Sms code is {code}',
        'en_US',
        {'phone': '+79131234567', 'code': '9999'},
      ),
      'Your phone is +79131234567, Sms code is 9999',
    );
  });

  test('parse variable substitution without variable', () async {
    expect(
      icuParser.parse(
        'We’ve sent you\nan sms with the code to {phone}',
        'en_US',
      ),
      'We’ve sent you\nan sms with the code to {phone}',
    );
  });

  test('ICUParser.parse plural substitution', () async {
    const message = '{num_emails_to_send, plural, '
        '=0 {No emails will be sent.}'
        '=1 {One email will be sent.}'
        'other {{num_emails_to_send} emails will be sent.}}';

    expect(
      icuParser.parse(message, 'en_US', {'num_emails_to_send': 0}),
      'No emails will be sent.',
    );
    expect(
      icuParser.parse(message, 'en_US', {'num_emails_to_send': 1}),
      'One email will be sent.',
    );
    expect(
      icuParser.parse(message, 'en_US', {'num_emails_to_send': 10}),
      '10 emails will be sent.',
    );
  });

  test('parse plural substitution ru', () async {
    const message = '{days, plural, '
        '=1 {{days} День}'
        'few {{days} Дня}'
        'other {{days} Дней}}';

    expect(icuParser.parse(message, 'ru_RU', {'days': 0}), '0 Дней');
    expect(icuParser.parse(message, 'ru_RU', {'days': 1}), '1 День');
    expect(icuParser.parse(message, 'ru_RU', {'days': 2}), '2 Дня');
    expect(icuParser.parse(message, 'ru_RU', {'days': 3}), '3 Дня');
    expect(icuParser.parse(message, 'ru_RU', {'days': 4}), '4 Дня');
    expect(icuParser.parse(message, 'ru_RU', {'days': 5}), '5 Дней');
    expect(icuParser.parse(message, 'ru_RU', {'days': 6}), '6 Дней');
    expect(icuParser.parse(message, 'ru_RU', {'days': 7}), '7 Дней');
    expect(icuParser.parse(message, 'ru_RU', {'days': 101}), '101 День');
    expect(icuParser.parse(message, 'ru_RU', {'days': 102}), '102 Дня');
  });

  test('parse gender substitution', () async {
    const message = '{userGender, select, '
        'female{{userName} is unavailable because she is not online.}'
        'male{{userName} is unavailable because he is not online.}'
        'other{{userName} is unavailable because they are not online.}}';

    expect(
      icuParser.parse(message, 'en_US', {'userGender': 'female', 'userName': 'Anna'}),
      'Anna is unavailable because she is not online.',
    );

    expect(
      icuParser.parse(message, 'en_US', {'userGender': 'male', 'userName': 'Ivan'}),
      'Ivan is unavailable because he is not online.',
    );

    expect(
      icuParser.parse(message, 'en_US', {'userGender': 'other', 'userName': 'It'}),
      'It is unavailable because they are not online.',
    );
  });

  test('parse gender substitution - reorder', () async {
    const message = '{userGender, select, '
        'other{{userName} is unavailable because they are not online.}'
        'male{{userName} is unavailable because he is not online.}'
        'female{{userName} is unavailable because she is not online.}}';

    expect(
      icuParser.parse(message, 'en_US', {'userGender': 'female', 'userName': 'Anna'}),
      'Anna is unavailable because she is not online.',
    );

    expect(
      icuParser.parse(message, 'en_US', {'userGender': 'male', 'userName': 'Ivan'}),
      'Ivan is unavailable because he is not online.',
    );

    expect(
      icuParser.parse(message, 'en_US', {'userGender': 'other', 'userName': 'It'}),
      'It is unavailable because they are not online.',
    );
  });

  test('parse select substitution', () async {
    const message = '{status, select, '
        'online{User is online}'
        'offline{User is offline}'
        'other{Can\'t read the user status}}';

    expect(
      icuParser.parse(message, 'en_US', {'status': 'online'}),
      'User is online',
    );

    expect(
      icuParser.parse(message, 'en_US', {'status': 'offline'}),
      'User is offline',
    );

    expect(
      icuParser.parse(message, 'en_US', {'status': 'other'}),
      'Can\'t read the user status',
    );
  });
}
