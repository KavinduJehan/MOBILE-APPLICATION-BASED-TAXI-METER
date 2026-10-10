import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_trip/src/offline_map.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'raster MBTiles reads XYZ coordinates using the reversed TMS row',
    () async {
      sqfliteFfiInit();
      final temp = await Directory.systemTemp.createTemp('taxi-map-test-');
      final path = '${temp.path}/sample.mbtiles';
      final db = await databaseFactoryFfi.openDatabase(path);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xFF00AA00), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1, 1);
      final png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      await db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
      await db.execute(
        'CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)',
      );
      await db.insert('metadata', {'name': 'format', 'value': 'png'});
      await db.insert('metadata', {'name': 'name', 'value': 'Test map'});
      await db.insert('tiles', {
        'zoom_level': 2,
        'tile_column': 1,
        'tile_row': 2,
        'tile_data': png,
      });
      await db.close();
      final archive = await OfflineMapArchive.open(path);
      expect(base64Encode((await archive.tile(1, 1, 2))!), base64Encode(png));
      expect(await archive.tile(1, 2, 2), isNull);
      await archive.db.close();
      await File(path).delete();
      await temp.delete();
    },
  );
  test('unsupported vector MBTiles fails with an actionable error', () async {
    sqfliteFfiInit();
    final temp = await Directory.systemTemp.createTemp('taxi-map-test-');
    final path = '${temp.path}/vector.mbtiles';
    final db = await databaseFactoryFfi.openDatabase(path);
    await db.execute('CREATE TABLE metadata (name TEXT, value TEXT)');
    await db.insert('metadata', {'name': 'format', 'value': 'pbf'});
    await db.close();
    await expectLater(OfflineMapArchive.open(path), throwsFormatException);
    await File(path).delete();
    await temp.delete();
  });
}
