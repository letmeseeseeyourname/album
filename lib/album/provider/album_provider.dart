import 'package:ablumwin/utils/win_helper.dart';
import 'package:flutter/material.dart';
import '../../network/constant_sign.dart';
import '../../network/network_provider.dart';
import '../../network/response/response_model.dart';
import '../../user/models/resource_list_model.dart';
import '../models/file_detail_model.dart';
import '../models/file_upload_model.dart';
import '../models/file_upload_response_model.dart';

class AlbumProvider extends ChangeNotifier {
  static final int myPageSize = 100;

  //nass/ps/storage/reportSyncTaskFiles
  Future<ResponseModel<bool>> reportSyncTaskFiles(
    int taskId,
    List<FileDetailModel> fileList,
  ) async {
    // ...existing code...
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/reportSyncTaskFiles";
    ResponseModel<bool> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {"taskId": taskId, "fileList": fileList},
      netMethod: NetMethod.post,
    );
    // ...existing code...

    return responseModel;
  }

  //nass/ps/storage/revokeSyncTask
  Future<ResponseModel<bool>> revokeSyncTask(int taskId) async {
    // ...existing code...
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/revokeSyncTask";
    ResponseModel<bool> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {"taskId": taskId},
      netMethod: NetMethod.post,
    );
    // ...existing code...

    return responseModel;
  }

  ///"isFileDel":"Y:不保留数据 N：保留数据"
  Future<ResponseModel<bool>> delSyncTask(int taskId) async{
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/delSyncTask";
    ResponseModel<bool> responseModel = await requestAndConvertResponseModel(
      url,
      formData: {
        "taskId": taskId,
        "isFileDel":'N',
      },
      netMethod: NetMethod.post,
    );
    return responseModel;
  }

  //nass/ps/storage/createSyncTask
  Future<ResponseModel<FileUploadResponseModel>> createSyncTask(
    List<FileUploadModel> fileList,
  ) async {
    // ...existing code...
    var uuid = await WinHelper.uuid();
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/createSyncTask";
    String extraDeviceName = "Windows";
    ResponseModel<FileUploadResponseModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: {
            "extraDeviceName": extraDeviceName,
            "extraDeviceCode": uuid,
            "fileList": fileList,
          },
          netMethod: NetMethod.post,
          useCache: false,
        );
    // ...existing code...
    // 打印返回信息
    debugPrint('┌──────────────────────────────────────────────────────');
    debugPrint('│ createSyncTask 返回结果:');
    debugPrint('│ isSuccess: ${responseModel.isSuccess}');
    debugPrint('│ code: ${responseModel.code}');
    debugPrint('│ message: ${responseModel.message}');
    if (responseModel.model != null) {
      debugPrint('│ taskId: ${responseModel.model?.taskId}');
      debugPrint('│ uploadPath: ${responseModel.model?.uploadPath}');
      debugPrint(
        '│ failedFileList: ${responseModel.model?.failedFileList?.length ?? 0} 个',
      );
    } else {
      debugPrint('│ model: null');
    }
    debugPrint('└──────────────────────────────────────────────────────');
    return responseModel;
  }

  Future<ResponseModel<ResourceListModel>> listResources(
    int page, {
    bool isPrivate = false,
    int? pageSize,
    String startDate = "",
    String endDate = "",
    List<int> locate = const [],
    List<int> person = const [],
  }) async {
    // ...existing code...
    String url = "${AppConfig.hostUrl()}/nass/ps/photo/listResources";
    ResponseModel<ResourceListModel> responseModel =
        await requestAndConvertResponseModel(
          url,
          formData: {
            "pageIndex": page,
            "pageSize": pageSize ?? myPageSize,
            "keyword": "",
            "startDate": startDate, //搜索开始日期时间戳
            "endDate": endDate,
            "locate": locate, //地点
            "person": person, //人物
            "sharePerson": [], //分享
            "extraDevice": [], //设备
            "scence": [], //场景
            "resType": "", //媒体格式
            "fileType": ["P", "V"], //P：图片 V：视频
            "isFavorite": "",
            "isPrivate": isPrivate ? "Y" : "N",
          },
          netMethod: NetMethod.post,
          useCache: false
        );

    return responseModel;
  }
}
