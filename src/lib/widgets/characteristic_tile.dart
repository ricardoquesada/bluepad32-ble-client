import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "../utils/snackbar.dart";

import "descriptor_tile.dart";

const Map<String, Map<String, dynamic>> uuidToBP32CharacteristicMap = const {
  '4627c4a4-ac01-46b9-b688-afc5c1bf7f63': {'name': 'Bluepad32 version', 'type': 'string'},
  '4627c4a4-ac02-46b9-b688-afc5c1bf7f63': {'name': 'Max supported connections', 'type': 'int'},
  '4627c4a4-ac03-46b9-b688-afc5c1bf7f63': {'name': 'Enable BLE connections', 'type': 'bool'},
  '4627c4a4-ac04-46b9-b688-afc5c1bf7f63': {'name': 'Start scanning and auto connect', 'type': 'bool'},
  '4627c4a4-ac05-46b9-b688-afc5c1bf7f63': {'name': 'Connected controllers', 'type': 'int'},
  '4627c4a4-ac06-46b9-b688-afc5c1bf7f63': {'name': 'Connected devices notification'},
  '4627c4a4-ac07-46b9-b688-afc5c1bf7f63': {'name': 'Gamepad mappings: Xbox or Nintendo', 'type': 'mapping'},
  '4627c4a4-ac08-46b9-b688-afc5c1bf7f63': {'name': 'Enable Allowlist', 'type': 'bool'},
  '4627c4a4-ac09-46b9-b688-afc5c1bf7f63': {'name': 'Controllers in Allowlist', 'type': 'bdaddrs'},
  '4627c4a4-ac0a-46b9-b688-afc5c1bf7f63': {'name': 'Enable virtual controller', 'type': 'bool'},
  '4627c4a4-ac0b-46b9-b688-afc5c1bf7f63': {'name': 'Disconnect controller'},
  '4627c4a4-ac0c-46b9-b688-afc5c1bf7f63': {'name': 'Delete stored BT keys', 'type': 'button'},
  '4627c4a4-ac0d-46b9-b688-afc5c1bf7f63': {'name': 'Reboot device', 'type': 'button'},
};

class CharacteristicTile extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;

  const CharacteristicTile({Key? key, required this.characteristic, required this.descriptorTiles}) : super(key: key);

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  List<int> _value = [];

  late StreamSubscription<List<int>> _lastValueSubscription;

  @override
  void initState() {
    super.initState();
    _lastValueSubscription = widget.characteristic.lastValueStream.listen((value) {
      _value = value;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _lastValueSubscription.cancel();
    super.dispose();
  }

  BluetoothCharacteristic get c => widget.characteristic;

  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  Future onReadPressed() async {
    try {
      await c.read();
      Snackbar.show(ABC.c, "Read: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Read Error:", e), success: false);
    }
  }

  Future onWritePressed() async {
    try {
      await c.write(_getRandomBytes(), withoutResponse: c.properties.writeWithoutResponse);
      Snackbar.show(ABC.c, "Write: Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
    }
  }

  Future writeInt(int value) async {
    try {
      await c.write([value], withoutResponse: c.properties.writeWithoutResponse);
      Snackbar.show(ABC.c, "Write: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
    }
    try {
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
    }
  }

  Future onSubscribePressed() async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unsubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      Snackbar.show(ABC.c, "$op : Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
    }
  }

  Widget buildUuid(BuildContext context) {
    String uuid;
    if (uuidToBP32CharacteristicMap.containsKey(widget.characteristic.uuid.str))
      uuid = uuidToBP32CharacteristicMap[widget.characteristic.uuid.str]!['name'];
    else
      uuid = '0x${widget.characteristic.uuid.str.toUpperCase()}';
    print(uuid);
    return Text(uuid, style: TextStyle(fontSize: 13));
  }

  Widget buildValue(BuildContext context) {
    String data = _value.toString();
    return Text(data, style: TextStyle(fontSize: 13, color: Colors.grey));
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
        child: Text("Read"),
        onPressed: () async {
          await onReadPressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildWriteButton(BuildContext context) {
    bool withoutResp = widget.characteristic.properties.writeWithoutResponse;
    return TextButton(
        child: Text(withoutResp ? "WriteNoResp" : "Write"),
        onPressed: () async {
          await onWritePressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildSwitchButton(BuildContext context) {
    return Switch(
      value: _value.length > 0 && _value[0] != 0,
      onChanged: (bool value) async {
        await writeInt(value ? 1 : 0);
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget buildPushButton(BuildContext context) {
    return ElevatedButton(
        child: const Text('Button'),
        onPressed: () async {
          await writeInt(1);
          if (mounted) {
            setState(() {});
          }
        },
    );
  }

  Widget buildSubscribeButton(BuildContext context) {
    bool isNotifying = widget.characteristic.isNotifying;
    return TextButton(
        child: Text(isNotifying ? "Unsubscribe" : "Subscribe"),
        onPressed: () async {
          await onSubscribePressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildButtonRow(BuildContext context) {
    bool toggle = false;
    bool button = false;
    bool read = widget.characteristic.properties.read;
    bool write = widget.characteristic.properties.write;
    bool notify = widget.characteristic.properties.notify;
    bool indicate = widget.characteristic.properties.indicate;
    if (uuidToBP32CharacteristicMap.containsKey(widget.characteristic.uuid.str)
        && uuidToBP32CharacteristicMap[widget.characteristic.uuid.str]!.containsKey('type')) {
      toggle = uuidToBP32CharacteristicMap[widget.characteristic.uuid
          .str]!['type']! == 'bool';
      button = uuidToBP32CharacteristicMap[widget.characteristic.uuid
          .str]!['type']! == 'button';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (read) buildReadButton(context),
        if (write) buildWriteButton(context),
        if (notify || indicate) buildSubscribeButton(context),
        if (toggle) buildSwitchButton(context),
        if (button) buildPushButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: ListTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Characteristic'),
            buildUuid(context),
            buildValue(context),
          ],
        ),
        subtitle: buildButtonRow(context),
        contentPadding: const EdgeInsets.all(0.0),
      ),
      children: widget.descriptorTiles,
    );
  }
}
