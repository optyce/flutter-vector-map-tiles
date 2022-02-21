import 'dart:async';

import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import '../../vector_map_tiles.dart';
import '../executor/executor.dart';

abstract class CancellableTileRequest {
  final TileIdentity tileId;
  final CancellationCallback _cancelled;

  CancellableTileRequest(this.tileId, this._cancelled);

  bool get isCancelled => _cancelled();
  CancellationCallback get cancelled => _cancelled;

  void testCancelled() {
    if (isCancelled) {
      throw CancellationException();
    }
  }
}

class TileRequest extends CancellableTileRequest {
  TileRequest(
      {required TileIdentity tileId, required CancellationCallback cancelled})
      : super(tileId, cancelled);
}

class TileResponse {
  final TileIdentity identity;
  final Tileset? tileset;

  TileResponse({required this.identity, this.tileset});
}

abstract class TileSupplier {
  int get maximumZoom;
  List<Future<TileResponse>> stream(TileRequest request);
}

class TileProviderRequest extends CancellableTileRequest {
  final double? zoom;

  TileProviderRequest(
      {required TileIdentity tileId,
      this.zoom,
      required CancellationCallback cancelled})
      : super(tileId, cancelled);
}

abstract class TileProvider {
  int get maximumZoom;
  Future<TileResponse> provide(TileProviderRequest request);
}
