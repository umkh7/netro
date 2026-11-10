import 'package:flutter_test/flutter_test.dart';
import 'package:netro/settings.dart';

void main() {
  test('normalizeDomain', () {
    expect(normalizeDomain('https://umkh7.com/test'), 'umkh7.com');
    expect(normalizeDomain('https://www.Ozon.ru/product/1?x=2'), 'ozon.ru');
    expect(normalizeDomain('m.vk.com:443'), 'm.vk.com');
    expect(normalizeDomain('*.wb.ru'), 'wb.ru');
    expect(normalizeDomain('привет'), null);
    expect(normalizeDomain('abc'), null);
  });
}
