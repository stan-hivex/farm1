import 'package:farm/core/african_phone_countries.dart';
import 'package:farm/core/crypto_coin_limit.dart';
import 'package:farm/pages/assistant/hands_free.dart';
import 'package:farm/pages/business/business_kyb_logic.dart';
import 'package:farm/pages/business/ops/project_logic.dart';
import 'package:farm/pages/business/ops/team_logic.dart';
import 'package:farm/utils/personal_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registration uses the same African list as login', () {
    expect(kAfricanPhoneCountries.length, greaterThan(50));
    expect(kAfricanPhoneCountries.any((c) => c['iso'] == 'KE' && c['code'] == '+254'), isTrue);
    expect(kAfricanPhoneCountries.any((c) => c['iso'] == 'NG'), isTrue);
    expect(kDefaultLoginCountry['iso'], 'KE');
    final isos = kAfricanPhoneCountries.map((c) => c['iso']).toSet();
    expect(isos.length, kAfricanPhoneCountries.length);
  });

  test('merchant QR credits stay off the personal activity list', () {
    expect(
      isPersonalActivity({
        'status': 'completed',
        'transaction_type': 'merchant_payment',
        'is_outgoing': false,
        'description': 'Public QR merchant payment',
      }),
      isFalse,
    );
    expect(
      isPersonalActivity({
        'status': 'completed',
        'transaction_type': 'merchant_payment',
        'is_outgoing': true,
      }),
      isTrue,
    );
    expect(
      isPersonalActivity({
        'status': 'completed',
        'transaction_type': 'transfer',
        'is_outgoing': false,
      }),
      isTrue,
    );
  });

  test('coin limits come only from the payload', () {
    final parsed = parseCoinLimit({
      'data': {
        'currency': 'usdc',
        'minimumAmount': 1.5,
        'maximumAmount': 20000,
        'minimumUsd': 2,
        'maximumUsd': 100000,
      },
    });
    expect(parsed!.minAmount, 1.5);
    expect(parsed.maxUsd, 100000);
    expect(parsed.allowsUsd(2), isTrue);
    expect(parsed.allowsUsd(1), isFalse);
    expect(parsed.allowsUsd(100001), isFalse);
    expect(parsed.rangeLabel, contains('USDC'));

    final list = parseCoinLimitList({
      'data': {
        'coins': [
          {'currency': 'btc', 'min_usd': 10, 'max_usd': 500},
          {'coin': 'eth', 'min': 0.01, 'max': 5},
        ],
      },
    });
    expect(limitFor(list, 'BTC')!.minUsd, 10);
    expect(limitFor(list, 'eth')!.maxAmount, 5);
    expect(parseCoinLimit({'data': {}}), isNull);
  });

  test('Hey Mkulima extracts a command and ignores other speech', () {
    expect(parseHandsFree('hey mkulima what is my balance').command, 'what is my balance');
    expect(parseHandsFree('please check the weather').wake, isFalse);
    expect(parseHandsFree('Hey Mkulima').hasCommand, isFalse);
    expect(voiceTextLooksLikeSecret('my pin is 1234'), isTrue);
    expect(voiceTextLooksLikeSecret('send 10 to mama'), isFalse);
    expect(handsFreeLimits, contains('pocket'));
    expect(handsFreeLimits.toLowerCase(), contains('pin'));
  });

  test('team list, roles, invites and remove targets parse', () {
    final snap = parseTeamResponse({
      'data': {
        'members': [
          {'id': null, 'role': 'owner', 'user': {'full_name': 'Asha'}},
          {'id': 'm1', 'role': 'finance', 'user': {'username': 'lee'}},
        ],
        'invites': [
          {'identifier': '+254700000001', 'role': 'operations'},
        ],
      },
      'meta': {'my_role': 'owner'},
    });
    expect(snap.members, hasLength(2));
    expect(snap.invites.single['role'], 'operations');
    expect(snap.assignableRoles, contains('admin'));
    expect(snap.assignableRoles, isNot(contains('owner')));
  });

  test('a filled project can be submitted for tokenization', () {
    expect(
      projectIsFilled({
        'project_name': 'Solar drier',
        'target_amount': 1000,
        'summary': 'Dry grain',
      }),
      isTrue,
    );
    expect(projectIsFilled({'project_name': 'X', 'target_amount': 10}), isFalse);
    expect(submitForTokenizationLabel, 'Submit for tokenization');
  });

  test('KYB submit requires Didit and does not offer a manual path', () {
    expect(kybAllowsApplicationSubmit(kybStateFor('none')), isFalse);
    expect(kybAllowsApplicationSubmit(kybStateFor('approved')), isTrue);
    expect(kybDiditRequiredMessage.toLowerCase(), contains('didit'));
    expect(kybBody(KybUiState.notStarted).toLowerCase(), contains('didit'));
  });
}
