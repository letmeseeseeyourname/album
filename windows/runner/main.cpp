#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Mutex name for single instance (must be unique)
const wchar_t kMutexName[] = L"joykee-firmlyalbum-single-instance";
// Flutter window class name
const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
// Custom message to show window
const UINT WM_SHOW_WINDOW = WM_USER + 100;
// Default window size
constexpr int kDefaultWindowWidth = 1280;
constexpr int kDefaultWindowHeight = 720;

// Global mutex handle
HANDLE g_mutex = NULL;

// Callback function to find and show existing window
BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam) {
wchar_t className[256];
GetClassNameW(hwnd, className, 256);

if (wcscmp(className, kWindowClassName) == 0) {
// Found the Flutter window, store its handle
*reinterpret_cast<HWND*>(lParam) = hwnd;
return FALSE; // Stop enumeration
}
return TRUE; // Continue enumeration
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
        _In_ wchar_t *command_line, _In_ int show_command) {
// Try to open existing mutex
g_mutex = OpenMutexW(MUTEX_ALL_ACCESS, FALSE, kMutexName);

if (g_mutex != NULL) {
// Mutex exists, another instance is running
// Find the existing window and show it
HWND existingWindow = NULL;
EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(&existingWindow));

if (existingWindow != NULL) {
// Show the window
ShowWindow(existingWindow, SW_SHOW);
ShowWindow(existingWindow, SW_RESTORE);
SetForegroundWindow(existingWindow);

// Send custom message to notify Flutter app
PostMessage(existingWindow, WM_SHOW_WINDOW, 0, 0);
}

CloseHandle(g_mutex);
return 0;
}

// Create new mutex - we are the first instance
g_mutex = CreateMutexW(NULL, FALSE, kMutexName);
if (g_mutex == NULL) {
// Failed to create mutex, but continue anyway
}

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

// Avoid negative or excessively small Y-coordinate calculations
if (start_y < 0) start_y = 50;
// ----------------------

FlutterWindow window(project);
Win32Window::Point origin(start_x, start_y);
Win32Window::Size size(kDefaultWindowWidth, kDefaultWindowHeight);
if (!window.Create(L"AI\x76f8\x518c\x7ba1\x5bb6", origin, size)) {
::CoUninitialize();
if (g_mutex) {
CloseHandle(g_mutex);
g_mutex = NULL;
}
return EXIT_FAILURE;
}
window.SetQuitOnClose(true);

::MSG msg;
while (::GetMessage(&msg, nullptr, 0, 0)) {
::TranslateMessage(&msg);
::DispatchMessage(&msg);
}

::CoUninitialize();

// Release mutex when app closes
if (g_mutex) {
CloseHandle(g_mutex);
g_mutex = NULL;
}

return EXIT_SUCCESS;
}