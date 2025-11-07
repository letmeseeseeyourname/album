class FileItem {
  final int? id;
  final String md5Hash;
  final String filePath;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String assetId;
  final int status;
  final String userId;
  final String deviceCode;
  final int duration;
  final int width;
  final int height;
  final double lng;
  final double lat;
  final double createDate;

  FileItem({
    this.id,
    required this.md5Hash,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.assetId,
    required this.status,
    required this.userId,
    required this.deviceCode,
    required this.duration,
    required this.width,
    required this.height,
    required this.lng,
    required this.lat,
    required this.createDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'md5Hash': md5Hash,
      'filePath': filePath,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'assetId': assetId,
      'status': status,
      'userId': userId,
      'deviceCode': deviceCode,
      'duration': duration,
      'width': width,
      'height': height,
      'lng': lng,
      'lat': lat,
      'createDate': createDate,
    };
  }

  factory FileItem.fromMap(Map<String, dynamic> map) {
    return FileItem(
      id: map['id'],
      md5Hash: map['md5Hash'],
      filePath: map['filePath'],
      fileName: map['fileName'],
      fileType: map['fileType'],
      fileSize: map['fileSize'],
      assetId: map['assetId'],
      status: map['status'],
      userId: map['userId'],
      deviceCode: map['deviceCode'],
      duration: map['duration'] is int ? map['duration'] : int.parse(map['duration'].toString()),
      width: map['width'] is int ? map['width'] : int.parse(map['width'].toString()),
      height: map['height'] is int ? map['height'] : int.parse(map['height'].toString()),
      lng: map['lng'] is double ? map['lng'] : double.parse(map['lng'].toString()),
      lat: map['lat'] is double ? map['lat'] : double.parse(map['lat'].toString()),
      createDate: map['createDate'] is double ? map['createDate'] : double.parse(map['createDate'].toString()),
    );
  }
}
