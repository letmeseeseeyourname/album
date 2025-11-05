import 'package:json_annotation/json_annotation.dart';

part 'p6item_list.g.dart';

@JsonSerializable()
class P6itemList {
    @JsonKey(name: 'headUrl')
    final String? headUrl;
    @JsonKey(name: 'nickName')
    final String? nickName;
    @JsonKey(name: 'photoCount')
    final int? photoCount;
    @JsonKey(name: 'photoUseStorage')
    final double? photoUseStorage;
    @JsonKey(name: 'sharePhotoCount')
    final int? sharePhotoCount;
    @JsonKey(name: 'shareVideoCount')
    final int? shareVideoCount;
    @JsonKey(name: 'useStorage')
    final double? useStorage;
    @JsonKey(name: 'userId')
    final int? userId;
    @JsonKey(name: 'videoCount')
    final int? videoCount;
    @JsonKey(name: 'videoUseStorage')
    final double? videoUseStorage;

    const P6itemList({
        required this.headUrl,
        required this.nickName,
        required this.photoCount,
        required this.photoUseStorage,
        required this.sharePhotoCount,
        required this.shareVideoCount,
        required this.useStorage,
        required this.userId,
        required this.videoCount,
        required this.videoUseStorage,
    });

    factory P6itemList.fromJson(Map<String, dynamic> json) => _$P6itemListFromJson(json);

    Map<String, dynamic> toJson() => _$P6itemListToJson(this);

    P6itemList copyWith({
        String? headUrl,
        String? nickName,
        int? photoCount,
        double? photoUseStorage,
        int? sharePhotoCount,
        int? shareVideoCount,
        double? useStorage,
        int? userId,
        int? videoCount,
        double? videoUseStorage,
    }) {
        return P6itemList(
            headUrl: headUrl ?? this.headUrl,
            nickName: nickName ?? this.nickName,
            photoCount: photoCount ?? this.photoCount,
            photoUseStorage: photoUseStorage ?? this.photoUseStorage,
            sharePhotoCount: sharePhotoCount ?? this.sharePhotoCount,
            shareVideoCount: shareVideoCount ?? this.shareVideoCount,
            useStorage: useStorage ?? this.useStorage,
            userId: userId ?? this.userId,
            videoCount: videoCount ?? this.videoCount,
            videoUseStorage: videoUseStorage ?? this.videoUseStorage,
        );
    }
}

// Run this command to generate the required code:
// flutter pub run build_runner build --delete-conflicting-outputs
