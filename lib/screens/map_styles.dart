import 'package:flutter_map/flutter_map.dart';

/// Base-map tile styles for the Map screen (#4.1). All are free, key-less tile
/// sources usable without an account. `subdomains` is empty for sources that
/// don't use an {s} placeholder.
enum MapStyle { standard, satellite, dark, terrain }

class MapStyleDef {
  final String id, label, url;
  final List<String> subdomains;
  final double maxZoom;
  const MapStyleDef(this.id, this.label, this.url, this.subdomains, this.maxZoom);
}

const kMapStyles = <MapStyle, MapStyleDef>{
  MapStyle.standard: MapStyleDef(
    'standard', 'Standard',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png', [], 19),
  MapStyle.satellite: MapStyleDef(
    'satellite', 'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', [], 19),
  MapStyle.dark: MapStyleDef(
    'dark', 'Dark',
    'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}', [], 16),
  MapStyle.terrain: MapStyleDef(
    'terrain', 'Terrain',
    'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', ['a', 'b', 'c'], 17),
};

MapStyle mapStyleFromId(String? id) =>
    kMapStyles.entries.firstWhere((e) => e.value.id == id, orElse: () => kMapStyles.entries.first).key;

/// Builds the TileLayer for a style.
TileLayer tileLayerFor(MapStyle style) {
  final d = kMapStyles[style]!;
  return TileLayer(
    urlTemplate: d.url,
    subdomains: d.subdomains,
    maxNativeZoom: d.maxZoom.toInt(),
    userAgentPackageName: 'com.papathought.kutsu',
  );
}
