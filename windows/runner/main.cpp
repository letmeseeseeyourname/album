#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// 定义窗口默认尺寸 (与您代码中的 1280, 720 匹配)
constexpr int kDefaultWindowWidth = 1280;
constexpr int kDefaultWindowHeight = 720;

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // --- Calculate the center position ---
  // get screen size
  int screen_width = GetSystemMetrics(SM_CXSCREEN);
  int screen_height = GetSystemMetrics(SM_CYSCREEN);

  // Calculate the starting X and Y coordinates to achieve centering.
  int start_x = (screen_width - kDefaultWindowWidth) / 2;
  int start_y = (screen_height - kDefaultWindowHeight) / 2;

  // Avoid negative or excessively small Y-coordinate calculations (if the screen resolution is low).
  if (start_y < 0) start_y = 50;
  // ----------------------

  FlutterWindow window(project);
  Win32Window::Point origin(start_x, start_y);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"ablumwin", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
