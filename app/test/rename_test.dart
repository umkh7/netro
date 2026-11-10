import 'package:flutter_test/flutter_test.dart';
import 'package:netro/country.dart';

void main() {
  test('rename', () {
    expect(renameForCountry('Швеция LTE', 'nl'), 'Нидерланды LTE');
    expect(renameForCountry('Европа LTE · 1', 'nl'), 'Нидерланды LTE · 1');
    expect(renameForCountry('Авто LTE 🚀', 'de'), 'Германия · Авто LTE 🚀');
    expect(renameForCountry('Нидерланды · Авто LTE 🚀', 'de'), 'Германия · Авто LTE 🚀');
    expect(renameForCountry('Северная Македония · 2', 'nl'), 'Нидерланды · 2');
    expect(renameForCountry('Германия', 'de'), 'Германия');
  });
}
