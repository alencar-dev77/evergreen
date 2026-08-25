import 'package:evergreen/shared/utils/byte_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bytes crus abaixo de um kilobyte', () {
    expect(ByteSize.compact(0), '0 B');
    expect(ByteSize.compact(840), '840 B');
  });

  test('kilobyte é arredondado — a casa decimal ali não diz nada', () {
    expect(ByteSize.compact(1024), '1 KB');
    expect(ByteSize.compact(1024 * 840), '840 KB');
  });

  test('a partir de megabyte, uma casa e vírgula decimal', () {
    expect(ByteSize.compact(1024 * 1024), '1,0 MB');
    expect(ByteSize.compact((1024 * 1024 * 2.4).round()), '2,4 MB');
  });

  test('não passa de gigabyte', () {
    expect(ByteSize.compact(1024 * 1024 * 1024 * 3), '3,0 GB');
  });
}
