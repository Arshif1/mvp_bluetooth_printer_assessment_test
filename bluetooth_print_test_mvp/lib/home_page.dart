import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_simple_bluetooth_printer/flutter_simple_bluetooth_printer.dart';
import 'package:app_settings/app_settings.dart';
import 'print_invoice.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  var bluetoothManager = FlutterSimpleBluetoothPrinter.instance;

  var _isScanning = false;
  bool _isLoading = false;
  var _isBle = false;
  var _isConnected = false;
  bool shouldShowShowPrintBtnForLastConnectedDevice = false;

  Map<String, dynamic> deviceInfo = {};
  var devices = <BluetoothDevice>[];
  BluetoothDevice? selectedPrinter;

  StreamSubscription<BTConnectState>? _subscriptionBtStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    autoConnectLastDevice();
    _discovery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _discovery();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth Printer App'),
        ),
        body: Stack(children: [
          Center(
            child: Container(
              height: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedPrinter == null || _isConnected
                                  ? null
                                  : () {
                                      _connectDevice();
                                    },
                              child: const Text("Connect",
                                  textAlign: TextAlign.center),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  selectedPrinter == null || !_isConnected
                                      ? null
                                      : () {
                                          if (selectedPrinter != null) {
                                            bluetoothManager.disconnect();
                                          }
                                          setState(() {
                                            _isConnected = false;
                                          });
                                        },
                              child: const Text("Disconnect",
                                  textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      deviceInfo.isNotEmpty
                          ? 'Connected Device: ${deviceInfo['macAddress']}'
                          : 'Connected Device: No device',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color:
                            deviceInfo.isNotEmpty ? Colors.green : Colors.red,
                      ),
                    ),
                    if (shouldShowShowPrintBtnForLastConnectedDevice)
                      ElevatedButton(
                        onPressed: () {
                          printWithLastConnectedDevice(
                              deviceInfo['macAddress'], deviceInfo['isBle']);
                        },
                        child: const Text('Print Invoice'),
                      ),
                    Visibility(
                      visible: Platform.isAndroid,
                      child: SwitchListTile.adaptive(
                        contentPadding:
                            const EdgeInsets.only(bottom: 20.0, left: 20),
                        title: const Text(
                          "BLE (low energy)",
                          textAlign: TextAlign.start,
                          style: TextStyle(fontSize: 19.0),
                        ),
                        value: _isBle,
                        onChanged: (bool? value) {
                          setState(() {
                            _isBle = value ?? false;
                            _isConnected = false;
                            selectedPrinter = null;
                            _scan();
                          });
                        },
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        _scan();
                      },
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                        child: Text("Rescan", textAlign: TextAlign.center),
                      ),
                    ),
                    _isScanning
                        ? const CircularProgressIndicator()
                        : Column(
                            children: devices
                                .map(
                                  (device) => ListTile(
                                    title: Text(device.name),
                                    subtitle: Text(device.address),
                                    onTap: () {
                                      // do something
                                      selectDevice(device);
                                    },
                                    trailing: OutlinedButton(
                                      onPressed: selectedPrinter == null ||
                                              device.name !=
                                                  selectedPrinter?.name
                                          ? null
                                          : () async {
                                              _print2X1();
                                            },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 20),
                                        child: Text("Print test",
                                            textAlign: TextAlign.center),
                                      ),
                                    ),
                                  ),
                                )
                                .toList()),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ]));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscriptionBtStatus?.cancel();
    super.dispose();
  }

  void _showBluetoothAlert() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bluetooth is off'),
          content: const Text('Please turn on Bluetooth to discover devices.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                Navigator.of(context).pop();
              },
              child: const Text('Open Bluetooth Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showBluetoothDisconnectionAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth Disconnected'),
          content: const Text(
              'The Bluetooth connection was lost. Would you like to reconnect?'),
          actions: [
            TextButton(
                child: const Text('Reconnect'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  var connectionStatus = await reconnect();
                  if (connectionStatus) {
                    _showBluetoothConnectedDialog();
                  } else {
                    _showCannotConnectBluetoothAlert();
                  }
                }),
            TextButton(
              child: const Text('Dismiss'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showBluetoothConnectedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connected'),
        content: const Text('You are now connected!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCannotConnectBluetoothAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cannot Connect'),
        content: const Text(
            'Unable to reconnect to the device. Please try again later.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> reconnect() async {
    setState(() {
      _isLoading = true;
    });
    if (deviceInfo != {}) {
      try {
        _isConnected = await bluetoothManager.connect(
            address: deviceInfo['macAddress'],
            isBLE: deviceInfo['isBle'] ?? false);

        return _isConnected;
      } on BTException catch (e) {
        print(e);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
    return false;
  }

  void _scan() async {
    devices.clear();
    try {
      setState(() {
        _isScanning = true;
      });
      if (_isBle) {
        final results =
            await bluetoothManager.scan(timeout: const Duration(seconds: 10));
        devices.addAll(results);
        setState(() {});
      } else {
        final bondedDevices = await bluetoothManager.getAndroidPairedDevices();
        devices.addAll(bondedDevices);
        setState(() {});
      }
    } on BTException catch (e) {
      print(e);
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _discovery() {
    devices.clear();
    try {
      bluetoothManager.discovery().listen(
        (device) {
          devices.add(device);
          setState(() {});
        },
        onError: (error) {
          if (error is BTException) {
            print(error);
            _showBluetoothAlert();
          }
        },
      );
    } on BTException catch (e) {
      print(e);
      _showBluetoothAlert();
    } catch (e) {
      print(e);
    }
  }

  void selectDevice(BluetoothDevice device) async {
    if (selectedPrinter != null) {
      if (device.address != selectedPrinter!.address) {
        await bluetoothManager.disconnect();
      }
    }

    selectedPrinter = device;
    setState(() {});
  }

  void _print2X1() async {
    setState(() {
      _isLoading = true;
    });
    if (selectedPrinter == null) {
      return;
    }

    final bytes = await printInvoice();
    String escPosCommand = String.fromCharCodes(bytes);

    try {
      await _connectDevice();
      if (!_isConnected) {
        _showBluetoothDisconnectionAlert();
        return;
      }
      final isSuccess = await bluetoothManager.writeText(escPosCommand);
      if (isSuccess) {
        await bluetoothManager.disconnect();
      }
    } on BTException catch (e) {
      print(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> printWithLastConnectedDevice(
      String macAddress, bool isBLE) async {
    setState(() {
      _isLoading = true;
    });
    final bytes = await printInvoice();
    String escPosCommand = String.fromCharCodes(bytes);

    try {
      _isConnected =
          await bluetoothManager.connect(address: macAddress, isBLE: isBLE);
      if (_isConnected) {
        final isSuccess = await bluetoothManager.writeText(escPosCommand);
        if (isSuccess) {
          await bluetoothManager.disconnect();
        }
      } else {
        _showBluetoothDisconnectionAlert();
      }
    } on BTException catch (e) {
      print(e);
    } finally {
      setState(() {
        _isLoading = false;
        deviceInfo = {'macAddress': macAddress, 'isBle': isBLE};
      });
    }
  }

  Future<void> autoConnectLastDevice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastDevice = prefs.getString('lastConnectedDevice');
    bool? isBle = prefs.getBool('isLE');

    if (lastDevice != null) {
      try {
        _isConnected = await bluetoothManager.connect(
            address: lastDevice, isBLE: isBle ?? false);
        if (_isConnected) {
          setState(() {
            deviceInfo = {'macAddress': lastDevice, 'isBle': isBle};
            shouldShowShowPrintBtnForLastConnectedDevice = true;
          });
        } else {
          setState(() {
            deviceInfo = {};
            shouldShowShowPrintBtnForLastConnectedDevice = false;
          });
        }
      } on BTException catch (e) {
        print(e);
      }
    }
  }

  _connectDevice() async {
    if (selectedPrinter == null) return;
    try {
      _isConnected = await bluetoothManager.connect(
          address: selectedPrinter!.address, isBLE: selectedPrinter!.isLE);
      if (_isConnected) {
        deviceInfo = {
          'macAddress': selectedPrinter!.address,
          'isBle': selectedPrinter!.isLE
        };
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('lastConnectedDevice');

        await prefs.setString(
            'lastConnectedDevice', selectedPrinter!.address.toString());
        await prefs.setBool('isLE', selectedPrinter!.isLE);
      }
    } on BTException catch (e) {
      print(e);
    }
  }
}
