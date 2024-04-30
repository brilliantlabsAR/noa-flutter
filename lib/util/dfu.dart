
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

class FirmwareFile {
  Uint8List binData;
  Uint8List datData;

  FirmwareFile({required this.binData, required this.datData});
}

class Firmware{

  static Future<String> currentVersion({String filePath=""}) async {
    if (filePath == "" ){
      var  dir = "assets/frame_firmware";
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final firmwareList = assetManifest.listAssets().where((string) => string.startsWith(dir)).toList();
      if (firmwareList.isEmpty){
        return "";
      }
      final firmware = firmwareList[0];
      final versionGrp = RegExp(r'frame-firmware-(v\d+\.\d+\.\d+).zip').firstMatch(firmware);
      if (versionGrp == null){
        return "";
      }
      return versionGrp.group(1)!;
      
    }else{
      final file = File(filePath);
      if (!file.existsSync()){
        return "";
      }
      final versionGrp = RegExp(r'frame-firmware-(v\d+\.\d+\.\d+).zip').firstMatch(filePath);
      if (versionGrp == null){
        return "";
      }
      return versionGrp.group(1)!;
     
    }
  }
  static Future<FirmwareFile> getFirmware({String zipPath=""}) async {
    if (zipPath == "" ){
      var  dir = "assets/frame_firmware";
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final firmwareList = assetManifest.listAssets().where((string) => string.startsWith(dir)).toList();
      if (firmwareList.isEmpty){
        return FirmwareFile(binData: Uint8List(0), datData: Uint8List(0));
      }
      final firmware = firmwareList[0];
      final data = await rootBundle.load(firmware);
      final bytes = data.buffer.asUint8List();
      final zip = ZipDecoder().decodeBytes(bytes);
      final bin = zip.firstWhere((file) => file.name.endsWith(".bin"));
      final dat = zip.firstWhere((file) => file.name.endsWith(".dat"));
      return FirmwareFile(binData: bin.content, datData: dat.content);
    }else{
      final file = File(zipPath);
      if (!file.existsSync()){
        return FirmwareFile(binData: Uint8List(0), datData: Uint8List(0));
      }
      final bytes = file.readAsBytesSync();
      final zip = ZipDecoder().decodeBytes(bytes);
      final bin = zip.firstWhere((file) => file.name.endsWith(".bin"));
      final dat = zip.firstWhere((file) => file.name.endsWith(".dat"));
      return FirmwareFile(binData: bin.content, datData: dat.content);
    }
  }
}