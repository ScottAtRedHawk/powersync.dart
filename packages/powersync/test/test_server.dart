import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' show ByteStream;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class TestServer {
  late HttpServer server;
  Router app = Router();
  int connectionCount = 0;
  int maxConnectionCount = 0;
  int tokenExpiresIn;

  TestServer({this.tokenExpiresIn = 65});

  Future<void> init() async {
    app.post('/sync/stream', handleSyncStream);
    // Open on an arbitrary open port
    server = await shelf_io.serve(app.call, 'localhost', 0);
  }

  String get endpoint {
    return 'http://${server.address.host}:${server.port}';
  }

  Future<Response> handleSyncStream(Request request) async {
    connectionCount += 1;
    maxConnectionCount = max(connectionCount, maxConnectionCount);

    stream() async* {
      try {
        var blob = "*" * 5000;
        for (var i = 0; i < 50; i++) {
          yield {"token_expires_in": tokenExpiresIn, "blob": blob};
          await Future.delayed(Duration(microseconds: 1));
        }
      } finally {
        connectionCount -= 1;
      }
    }

    return Response.ok(
      encodeNdjson(stream()),
      headers: {
        'Content-Type': 'application/x-ndjson',
      },
      context: {
        'shelf.io.buffer_output': false,
      },
    );
  }

  void close() {
    server.close(force: true).ignore();
  }
}

Future<TestServer> createServer() async {
  var server = TestServer();
  await server.init();
  return server;
}

/// Convert Map -> ndjson ByteStream
ByteStream encodeNdjson(Stream<Object> jsonInput) {
  final stringInput = jsonInput.map((data) => '${convert.jsonEncode(data)}\n');
  final byteInput = stringInput.transform(convert.utf8.encoder);
  return ByteStream(byteInput);
}
