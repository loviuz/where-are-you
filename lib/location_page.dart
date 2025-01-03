
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'globals.dart' as global;
import 'locationService.dart';
import 'locationServiceHandler.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

Future<void> syncPosition(String lat, String long) async {

  final response = await http.post(
    Uri.parse(global.apiUrl),

    body: {
      'apikey': global.userApikey,
      'getset' : 'set',
      'name': global.name,
      'lat': lat,
      'long': long,
    });
}

Future<void>removePosition() async {

  final response = await http.post(
      Uri.parse(global.apiUrl),

      body: {
        'apikey': global.adminApikey,
        'getset' : 'set',
      });
}

class _LocationPageState extends State<LocationPage> {
  String? _currentAddress;
  Position? _currentPosition;

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
        .then((Position position) {
      setState(() => _currentPosition = position);
      _getAddressFromLatLng(_currentPosition!);
    }).catchError((e) {
      debugPrint(e);
    });
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    await placemarkFromCoordinates(
            _currentPosition!.latitude, _currentPosition!.longitude)
        .then((List<Placemark> placemarks) {
      Placemark place = placemarks[0];
      setState(() {
        _currentAddress =
            '${place.street}, ${place.subLocality}, ${place.subAdministrativeArea}, ${place.postalCode}';
      });
    }).catchError((e) {
      debugPrint(e);
    });

  }

  @override
  void initState() {
    super.initState();
    LocationServiceHandler.serviceStoppedStream.listen((_) {
      setState(() {
        global.onoff = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Location Page")),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('LAT: ${_currentPosition?.latitude ?? ""}'),
              Text('LNG: ${_currentPosition?.longitude ?? ""}'),
              Text('ADDRESS: ${_currentAddress ?? ""}'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _getCurrentPosition,
                child: const Text("Get Current Location"),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async{
              syncPosition(_currentPosition!.latitude.toString(), _currentPosition!.longitude.toString());
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text("Location shared one time")));
              },
                child: const Text("Single shot localization"),
              ),
              const SizedBox(height: 30),
              const Text('Activate auto update location'),
              Switch(
                // thumb color (round icon)
                activeColor: Colors.amber,
                activeTrackColor: Colors.cyan,
                inactiveThumbColor: Colors.blueGrey.shade600,
                inactiveTrackColor: Colors.grey.shade400,
                splashRadius: 50.0,
                // boolean variable value
                value: global.onoff,
                // changes the state of the switch
                onChanged: (value) {
                  setState(() => global.onoff = value);
                  if (value) {
                    LocationService.instance.start();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Perpetual sharing started")));
                  } else {
                    LocationService.instance.stop();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Perpetual sharing stopped")));
                  }
                },
              ),
              const SizedBox(height: 30),
              if (global.adminApikey != '')
                ElevatedButton(
                  onPressed: () async {
                    removePosition();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("All location deleted")));
                  },
                  child: const Text("Delete existing positions"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
