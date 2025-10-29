class AppConfig {
  // static bool paySign = true;
  static int environment = 0;
  static String hostUrl() {
    if (environment == 0) {
      return 'http://127.0.0.1:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  static String userUrl() {
    if (environment == 0) {
      return 'https://p6albumserver.joykee.com';
    }
    return 'https://p6albumserver.joykee.com';
  }

  static String minio() {
    if (environment == 0) {
      return 'http://127.0.0.1:9000';
    }
    return 'http:/127.0.0.1:9000';
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
