import "dart:io";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/features/ar/data/marker_cache.dart";

void main() {
  late Directory root;
  late List<String> fetched;

  setUp(() {
    root = Directory.systemTemp.createTempSync("markers");
    fetched = [];
  });
  tearDown(() => root.deleteSync(recursive: true));

  MarkerCache cache({
    File? Function(String path)? downloaded,
    Future<Uint8List> Function(String path)? fetch,
  }) => MarkerCache(
    cacheRoot: () async => root,
    downloaded: downloaded ?? (_) => null,
    fetch:
        fetch ??
        (path) async {
          fetched.add(path);
          return Uint8List.fromList([1, 2, 3]);
        },
  );

  const path = "ar/museum/markers/e1-1729500000000.webp";

  test("a downloaded town's copy wins, with nothing fetched", () async {
    final local = File("${root.path}/town.webp")..writeAsBytesSync([9]);

    final file = await cache(downloaded: (_) => local).fileFor(path);

    expect(file?.path, local.path);
    expect(fetched, isEmpty);
  });

  test("fetches a marker once, then serves it from the cache", () async {
    final markers = cache();

    final first = await markers.fileFor(path);
    final second = await markers.fileFor(path);

    expect(first?.readAsBytesSync(), [1, 2, 3]);
    expect(second?.path, first?.path);
    expect(fetched, [path]);
    // No half-written file left beside it.
    expect(File("${first!.path}.part").existsSync(), isFalse);
  });

  test("a marker that cannot be fetched is null, not a throw", () async {
    final file = await cache(
      fetch: (_) async => throw const SocketException("No signal"),
    ).fileFor(path);

    expect(file, isNull);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test("gives up on a fetch that does not answer", () async {
    final file = await MarkerCache(
      cacheRoot: () async => root,
      downloaded: (_) => null,
      fetch: (_) =>
          Future.delayed(const Duration(seconds: 5), () => Uint8List(0)),
      fetchTimeout: const Duration(milliseconds: 10),
    ).fileFor(path);

    expect(file, isNull);
  });

  test("never writes outside its own directory", () async {
    final file = await cache().fileFor("ar/../../outside.webp");

    expect(file, isNull);
    expect(fetched, isEmpty);
  });
}
