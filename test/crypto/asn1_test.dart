library googleapis_auth.test.asn1_test;

import 'dart:typed_data';

import 'package:googleapis_auth/src/crypto/asn1.dart';
import 'package:unittest/unittest.dart';

main() {
  expectArgumentError(List<int> bytes) {
    expect(() => ASN1Parser.parse(new Uint8List.fromList(bytes)),
           throwsA(isArgumentError));
  }

  invalidLenTest(int tagBytes) {
    test('invalid-len', () {
      expectArgumentError([tagBytes]);
      expectArgumentError([tagBytes, 0x07]);
      expectArgumentError([tagBytes, 0x82]);
      expectArgumentError([tagBytes, 0x82, 1]);
      expectArgumentError([tagBytes, 0x01, 1, 2, 3, 4]);
    });
  }

  group('asn1-parser', () {
    group('sequence', () {
      test('empty', () {
        var sequenceBytes = [ASN1Parser.SEQUENCE_TAG, 0];
        var sequence = ASN1Parser.parse(new Uint8List.fromList(sequenceBytes));
        expect(sequence is ASN1Sequence, isTrue);
        expect(sequence.objects, isEmpty);
      });

      test('one-element', () {
        var sequenceBytes =
            [ASN1Parser.SEQUENCE_TAG, 1, ASN1Parser.NULL_TAG, 0];
        var sequence = ASN1Parser.parse(new Uint8List.fromList(sequenceBytes));
        expect(sequence is ASN1Sequence, isTrue);
        expect(sequence.objects, hasLength(1));
        expect(sequence.objects[0] is ASN1Null, isTrue);
      });

      test('many-elements', () {
        var sequenceBytes = [ASN1Parser.SEQUENCE_TAG, 0x82, 0x01, 0x00];
        for (int i = 0; i < 128; i++) {
          sequenceBytes.addAll([ASN1Parser.NULL_TAG, 0]);
        }

        var sequence = ASN1Parser.parse(new Uint8List.fromList(sequenceBytes));
        expect(sequence is ASN1Sequence, isTrue);
        expect(sequence.objects.length, equals(128));
        for (int i = 0; i < 128; i++) {
          expect(sequence.objects[i] is ASN1Null, isTrue);
        }
      });

      invalidLenTest(ASN1Parser.SEQUENCE_TAG);
    });

    group('integer', () {
      test('small', () {
        for (int i = 0; i < 256; i++) {
          var integerBytes = [ASN1Parser.INTEGER_TAG, 1, i];
          var integer =
              ASN1Parser.parse(new Uint8List.fromList(integerBytes));
          expect(integer is ASN1Integer, isTrue);
          expect(integer.integer, equals(i));
        }
      });

      test('multi-byte', () {
        var integerBytes = [ASN1Parser.INTEGER_TAG, 3, 1, 2, 3];
        var integer =
            ASN1Parser.parse(new Uint8List.fromList(integerBytes));
        expect(integer is ASN1Integer, isTrue);
        expect(integer.integer, equals(0x010203));
      });

      invalidLenTest(ASN1Parser.INTEGER_TAG);
    });

    group('octet-string', () {
      test('small', () {
        var octetStringBytes = [ASN1Parser.OCTET_STRING_TAG, 3, 1, 2, 3];
        var octetString =
            ASN1Parser.parse(new Uint8List.fromList(octetStringBytes));
        expect(octetString is ASN1OctetString, isTrue);
        expect(octetString.bytes, equals([1, 2, 3]));
      });

      test('large', () {
        var octetStringBytes = [ASN1Parser.OCTET_STRING_TAG, 0x82, 0x01, 0x00];
        for (int i = 0; i < 256; i++) octetStringBytes.add(i % 256);

        var octetString =
            ASN1Parser.parse(new Uint8List.fromList(octetStringBytes));
        expect(octetString is ASN1OctetString, isTrue);
        for (int i = 0; i < 256; i++) {
          expect(octetString.bytes[i], equals((i % 256)));
        }
      });

      invalidLenTest(ASN1Parser.OCTET_STRING_TAG);
    });

    group('oid', () {
      // NOTE: Currently the oid is parsed as normal bytes, so we don't validate
      // the oid structure.
      test('small', () {
        var objIdBytes = [ASN1Parser.OBJECT_ID_TAG, 3, 1, 2, 3];
        var objId =
            ASN1Parser.parse(new Uint8List.fromList(objIdBytes));
        expect(objId is ASN1ObjectIdentifier, isTrue);
        expect(objId.bytes, equals([1, 2, 3]));
      });

      test('large', () {
        var objIdBytes = [ASN1Parser.OBJECT_ID_TAG, 0x82, 0x01, 0x00];
        for (int i = 0; i < 256; i++) objIdBytes.add(i % 256);

        var objId = ASN1Parser.parse(new Uint8List.fromList(objIdBytes));
        expect(objId is ASN1ObjectIdentifier, isTrue);
        for (int i = 0; i < 256; i++) {
          expect(objId.bytes[i], equals((i % 256)));
        }
      });

      invalidLenTest(ASN1Parser.OBJECT_ID_TAG);
    });
  });

  test('null', () {
    var objId = ASN1Parser.parse(
        new Uint8List.fromList([ASN1Parser.NULL_TAG, 0x00]));
    expect(objId is ASN1Null, isTrue);

    expectArgumentError([ASN1Parser.NULL_TAG]);
    expectArgumentError([ASN1Parser.NULL_TAG, 0x01]);
  });
}