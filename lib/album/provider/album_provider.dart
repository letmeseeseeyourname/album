

import 'package:flutter/material.dart';
import '../../network/constant_sign.dart';
import '../../network/network_provider.dart';
import '../../network/response/response_model.dart';
import '../../user/native_bridge.dart';
import '../models/file_detail_model.dart';
import '../models/file_upload_model.dart';
import '../models/file_upload_response_model.dart';

class AlbumProvider extends ChangeNotifier{


  //nass/ps/storage/reportSyncTaskFiles
  Future<ResponseModel<bool>> reportSyncTaskFiles(
      int  taskId, List<FileDetailModel> fileList) async {
    // ...existing code...
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/reportSyncTaskFiles";
    ResponseModel<bool> responseModel = await requestAndConvertResponseModel(
        url,
        formData: {"taskId": taskId, "fileList": fileList},
        netMethod: NetMethod.post);
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
        netMethod: NetMethod.post);
    // ...existing code...

    return responseModel;
  }

  //nass/ps/storage/createSyncTask
  Future<ResponseModel<FileUploadResponseModel>> createSyncTask(
      List<FileUploadModel> fileList) async {
    // ...existing code...
    var uuid = await NativeBridge.uuid();
    String url = "${AppConfig.hostUrl()}/nass/ps/storage/createSyncTask";
    String extraDeviceName = "Windows";
    ResponseModel<FileUploadResponseModel> responseModel =
    await requestAndConvertResponseModel(url,
        formData: {
          "extraDeviceName": extraDeviceName,
          "extraDeviceCode": uuid,
          "fileList": fileList
        },
        netMethod: NetMethod.post);
    // ...existing code...

    return responseModel;
  }
}