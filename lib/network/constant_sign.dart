class AppConfig {
  // static bool paySign = true;
  static int environment = 0;
  static String p2pIP = "127.0.0.1";
  static String usedIP = p2pIP;
  static String hostPort = "8080";
  static String minioPort = "9000";

  static String  get currentIP {
    return "http://$usedIP";
  }

  static String hostUrl() {
    if (environment == 0) {
      return "$currentIP:$hostPort";
    }
    return "$currentIP:$hostPort";
  }

  static String userUrl() {
    if (environment == 0) {
      return 'https://p6albumserver.joykee.com';
    }
    return 'https://p6albumserver.joykee.com';
  }

  static String minio() {
    if (environment == 0) {
      return "$currentIP:$minioPort";
    }
    return "$currentIP:$minioPort";
  }

  static String avatarURL() {
    return "http://joykee-oss.joykee.com";
  }

  static String protocolUrl() {
    return "https://p6albumserver.joykee.com/expose-resources/protocol/zh-cn/用户协议.html";
  }

  static String privacyUrl() {
    return "https://p6albumserver.joykee.com/expose-resources/protocol/zh-cn/隐私政策.html";
  }

  static String shareListURL() {
    return "https://p6albumserver.joykee.com/expose-resources/inventory/zh-cn/第三方信息共享清单.html";
  }

  static String dataCollectURL() {
    return "https://p6albumserver.joykee.com/expose-resources/inventory/zh-cn/个人信息收集清单.html";
  }
}
