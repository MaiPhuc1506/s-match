import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../court_map/widgets/court_maplibre_map.dart';

/// A viewport is only a starting point; a new location must be selected.
class FacilityLocationPicker extends StatefulWidget {
  const FacilityLocationPicker({super.key, this.initialLocation});
  final LatLng? initialLocation;

  @override
  State<FacilityLocationPicker> createState() => _FacilityLocationPickerState();
}

class _FacilityLocationPickerState extends State<FacilityLocationPicker> {
  MapLibreMapController? _controller;
  LatLng? _selected;
  Circle? _marker;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  Future<void> _drawMarker() async {
    final controller = _controller;
    final selected = _selected;
    if (!_ready || controller == null || selected == null) return;
    if (_marker != null) await controller.removeCircle(_marker!);
    _marker = await controller.addCircle(
      CircleOptions(
        geometry: selected,
        circleRadius: 9,
        circleColor: '#006851',
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set Location')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Tap the map to select the facility location.'),
        ),
        Expanded(
          child: MapLibreMap(
            styleString: CourtMapLibreMap.smatchMintStyleAsset,
            initialCameraPosition: CameraPosition(
              target: widget.initialLocation ?? CourtMapLibreMap.userLocation,
              zoom: widget.initialLocation == null ? 11 : 15,
            ),
            onMapCreated: (controller) => _controller = controller,
            onStyleLoadedCallback: () {
              if (!mounted) return;
              setState(() => _ready = true);
              _drawMarker();
            },
            onMapClick: (_, location) {
              setState(() => _selected = location);
              _drawMarker();
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null || !_ready
                    ? null
                    : () => Navigator.pop(context, _selected),
                child: const Text('Confirm Location'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
