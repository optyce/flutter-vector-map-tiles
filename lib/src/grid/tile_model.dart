import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import '../executor/executor.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import '../profiler.dart';
import '../stream/tile_supplier.dart';
import '../tile_identity.dart';
import 'slippy_map_translator.dart';

typedef ZoomScaleFunction = double Function(int tileZoom);
typedef ZoomFunction = double Function();

class VectorTileModel extends ChangeNotifier {
  bool _disposed = false;
  bool get disposed => _disposed;

  final TileIdentity tile;
  final TileSupplier tileSupplier;
  final Theme theme;
  final Theme? symbolTheme;
  bool paintBackground;
  final bool showTileDebugInfo;
  final ZoomScaleFunction zoomScaleFunction;
  final ZoomFunction zoomFunction;
  double lastRenderedZoom = double.negativeInfinity;
  double lastRenderedZoomScale = double.negativeInfinity;
  late final TileTranslation defaultTranslation;
  TileTranslation? translation;
  Tileset? tileset;
  late final TimelineTask _firstRenderedTask;
  bool _firstRendered = false;

  VectorTileModel(
      this.tileSupplier,
      this.theme,
      this.symbolTheme,
      this.tile,
      this.zoomScaleFunction,
      this.zoomFunction,
      this.paintBackground,
      this.showTileDebugInfo) {
    defaultTranslation =
        SlippyMapTranslator(tileSupplier.maximumZoom).translate(tile);
    _firstRenderedTask = tileRenderingTask(tile);
  }

  bool get hasData => tileset != null;

  void rendered() {
    if (!_firstRendered) {
      _firstRendered = true;
      _firstRenderedTask.finish();
    }
  }

  void startLoading() async {
    final request =
        TileRequest(tileId: tile.normalize(), cancelled: () => _disposed);
    final futures = tileSupplier.stream(request);
    for (final future in futures) {
      future.whenComplete(() => _tileReady(future));
    }
  }

  void _tileReady(Future<TileResponse> future) async {
    try {
      _receiveTile(await future);
    } on CancellationException {
      // ignore, expected
    }
  }

  void _receiveTile(TileResponse received) {
    final newTranslation = SlippyMapTranslator(tileSupplier.maximumZoom)
        .specificZoomTranslation(tile, zoom: received.identity.z);
    tileset = received.tileset;
    translation = newTranslation;
    notifyListeners();
  }

  bool updateRendering() {
    final changed = hasChanged();
    if (changed) {
      lastRenderedZoom = zoomFunction();
      lastRenderedZoomScale = zoomScaleFunction(tile.z);
    }
    return changed;
  }

  bool hasChanged() {
    final lastRenderedZoom = zoomFunction();
    final lastRenderedZoomScale = zoomScaleFunction(tile.z);
    return lastRenderedZoomScale != this.lastRenderedZoomScale ||
        lastRenderedZoom != this.lastRenderedZoom;
  }

  void requestRepaint() {
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      super.dispose();
      _disposed = true;

      if (!_firstRendered) {
        _firstRendered = true;
        _firstRenderedTask.finish(arguments: {'cancelled': true});
      }
    }
  }

  @override
  void removeListener(ui.VoidCallback listener) {
    if (!_disposed) {
      super.removeListener(listener);
    }
  }
}
