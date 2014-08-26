library googleapis_auth.metadata_server;

import 'dart:async';
import 'dart:convert';

import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/src/oauth2_flows/metadata_server.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:unittest/unittest.dart';

import '../test_utils.dart';

main() {
  var apiUrl = 'http://metadata/computeMetadata/v1';
  var tokenUrl = '$apiUrl/instance/service-accounts/default/token';
  var scopesUrl = '$apiUrl/instance/service-accounts/default/scopes';

  Future<Response> successfullAccessToken(Request request) {
    expect(request.method, equals('GET'));
    expect(request.url.toString(), equals(tokenUrl));

    var body = JSON.encode({
      'access_token' : 'atok',
      'expires_in' : 3600,
      'token_type' : 'Bearer',
    });
    return new Future.value(new Response(body, 200));
  }

  Future<Response> invalidAccessToken(Request request) {
    expect(request.method, equals('GET'));
    expect(request.url.toString(), equals(tokenUrl));

    var body = JSON.encode({
      // Missing 'expires_in' entry
      'access_token' : 'atok',
      'token_type' : 'Bearer',
    });
    return new Future.value(new Response(body, 200));
  }

  Future<Response> successfullScopes(Request request) {
    expect(request.method, equals('GET'));
    expect(request.url.toString(), equals(scopesUrl));

    return new Future.value(new Response('s1\ns2', 200));
  }

  group('metadata-server-authorization-flow', () {
    test('successfull', () {
      int requestNr = 0;
      var flow = new MetadataServerAuthorizationFlow(
          mockClient(expectAsync((request) {
        var url = request.url.toString();
        if (url == tokenUrl) {
          return successfullAccessToken(request);
        } else if (url == scopesUrl) {
          return successfullScopes(request);
        } else {
          fail("Invalid URL $url (expected: $tokenUrl or $scopesUrl).");
        }
      }, count: 2), expectClose: false));

      flow.run().then(expectAsync((AccessCredentials credentials) {
        expect(credentials.accessToken.data, equals('atok'));
        expect(credentials.accessToken.type, equals('Bearer'));
        expect(credentials.scopes, equals(['s1', 's2']));

        var now = new DateTime.now().toUtc();
        expectExpiryOneHourFromNow(credentials.accessToken);
      }));
    });

    test('invalid-server-reponse', () {
      int requestNr = 0;
      var flow = new MetadataServerAuthorizationFlow(
          mockClient(expectAsync((request) {
        if (requestNr++ == 0) return invalidAccessToken(request);
        else return successfullScopes(request);
      }, count: 2), expectClose: false));
      expect(flow.run(), throwsA(isException));
    });


    test('token-transport-error', () {
      int requestNr = 0;
      var flow = new MetadataServerAuthorizationFlow(
          mockClient(expectAsync((request) {
        var dummyRequest = new Request(request.method, request.url);
        if (requestNr++ == 0) return transportFailure.send(dummyRequest);
        else return successfullScopes(request);
      }, count: 2), expectClose: false));
      expect(flow.run(), throwsA(isTransportException));
    });

    test('scopes-transport-error', () {
      int requestNr = 0;
      var flow = new MetadataServerAuthorizationFlow(
          mockClient(expectAsync((request) {
        var dummyRequest = new Request(request.method, request.url);
        if (requestNr++ == 0) return successfullAccessToken(request);
        else return transportFailure.send(dummyRequest);
      }, count: 2), expectClose: false));
      expect(flow.run(), throwsA(isTransportException));
    });
  });
}
