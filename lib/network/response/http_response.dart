class HttpResponse<T> {
  int statusCode = 0;
  T data;
  String message = "";

  bool get isHttpSuccess => statusCode == 200;

  HttpResponse({required this.statusCode, required this.data, required this.message});

  HttpResponse<E> convert<E>(
      {required int statusCode, required E data, required String message}) {
    return HttpResponse<E>(
        statusCode: statusCode,
        data: data,
        message: message);
  }

  @override
  String toString() {
    return 'HttpResponse{statusCode: $statusCode, data: ${data?.toString() ?? "null"}, message: $message';
  }
}