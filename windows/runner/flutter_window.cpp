#include "flutter_window.h"

#include <optional>
#include <string>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

// S317 (S-21/Φ2): αποκλεισμός του παραθύρου από τα capture APIs των Windows
// (screenshots, PrintWindow, screen share, Game Bar, Recall). Δεν είναι DRM:
// φιλτράρει τα δημόσια APIs — bypass με in-process hooks/drivers είναι εκτός
// εμβέλειας. Σε Windows < 2004 το 0x11 συμπεριφέρεται ως WDA_MONITOR (μαύρο).
constexpr DWORD kAffinityExcluded = WDA_EXCLUDEFROMCAPTURE;
constexpr DWORD kAffinityNone = WDA_NONE;

// Native ανάλογο του DebugConfig: ορατό μόνο με debugger/DebugView, χωρίς PII.
void TraceSecurity(const std::string& message) {
  OutputDebugStringA(("[S317] " + message + "\n").c_str());
}

// Μία και μοναδική πράξη: εφαρμογή affinity + readback (μόνο διαγνωστικό).
// Παίρνει HWND (όχι `this`) ώστε να μη εξαρτάται από τη ζωή του FlutterWindow.
bool ApplyCaptureAffinity(HWND window, DWORD affinity) {
  if (window == nullptr || !::IsWindow(window)) {
    TraceSecurity("skip: invalid hwnd");
    return false;
  }
  if (!::SetWindowDisplayAffinity(window, affinity)) {
    TraceSecurity("SetWindowDisplayAffinity failed, err=" +
                  std::to_string(::GetLastError()));
    return false;
  }
  DWORD readback = 0;
  if (!::GetWindowDisplayAffinity(window, &readback)) {
    TraceSecurity("GetWindowDisplayAffinity failed, err=" +
                  std::to_string(::GetLastError()));
  } else if (readback != affinity) {
    // Διαγνωστικό μόνο: δεν μετατρέπεται σε σφάλμα για το Dart (θα προκαλούσε
    // περιττά retries) — η ίδια η κλήση Set πέτυχε.
    TraceSecurity("readback mismatch: got " + std::to_string(readback));
  }
  TraceSecurity("applied affinity=" + std::to_string(affinity));
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  // S317: fail-closed αρχική κατάσταση. Το παράθυρο δεν έχει εμφανιστεί ακόμη
  // (Show() γίνεται στο πρώτο Flutter frame), άρα δεν υπάρχει παράθυρο διαρροής.
  // ΔΕΝ είναι πολιτική: η πολιτική ON/OFF μένει αποκλειστικά στο Dart (S165) —
  // το native ξεκινά κλειστό και το Dart το ανοίγει μόνο με επιβεβαιωμένο
  // `enabled == false`.
  ApplyCaptureAffinity(GetHandle(), kAffinityExcluded);

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // S317: κανάλι μετά το RegisterPlugins (ίδιος engine messenger, άλλο όνομα).
  // Ο handler κρατά το HWND by value: καμία εξάρτηση από το `this` και κανένα
  // dangling pointer αν κληθεί μετά το OnDestroy (το OnDestroy το αποσυνδέει).
  security_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "super_note/security",
          &flutter::StandardMethodCodec::GetInstance());
  const HWND window = GetHandle();
  security_channel_->SetMethodCallHandler(
      [window](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) {
        if (call.method_name() != "setSecure") {
          // elapsedRealtime: παραμένει notImplemented (S-03) — ίδια συμπεριφορά
          // με σήμερα (MissingPluginException -> wall-clock fallback στο Dart).
          result->NotImplemented();
          return;
        }
        const flutter::EncodableValue* arguments = call.arguments();
        // Το Dart στέλνει map `{'secure': bool}` — όπως στο Android
        // (`call.argument<Boolean>("secure")`). Διαβάζουμε το **πεδίο**, όχι όλο
        // το arguments (αλλιώς κάθε κλήση καταλήγει invalid_args).
        // std::get_if (όχι std::get): χτίζουμε με _HAS_EXCEPTIONS=0 + /WX.
        const bool* secure = nullptr;
        if (arguments != nullptr) {
          const auto* args = std::get_if<flutter::EncodableMap>(arguments);
          if (args != nullptr) {
            const auto it = args->find(flutter::EncodableValue("secure"));
            if (it != args->end()) {
              secure = std::get_if<bool>(&it->second);
            }
          }
        }
        if (secure == nullptr) {
          // Fail-closed: χωρίς ρητό bool δεν αλλάζει καμία κατάσταση
          // (σκόπιμη απόκλιση από Android, που προεπιλέγει false).
          result->Error("invalid_args", "setSecure requires a bool 'secure'");
          return;
        }
        if (ApplyCaptureAffinity(window,
                                 *secure ? kAffinityExcluded : kAffinityNone)) {
          result->Success();
        } else {
          result->Error("apply_failed", "SetWindowDisplayAffinity failed");
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // S317: ρητό unregister ΠΡΙΝ καταστραφεί ο controller — ο destructor του
  // MethodChannel ΔΕΝ αποσυνδέει τον handler (method_channel.h:96-98), άρα
  // χωρίς αυτό ο handler θα έμενε καταχωρημένος στον messenger.
  // Idempotent: το OnDestroy καλείται δύο φορές (WM_DESTROY + destructor).
  if (security_channel_) {
    security_channel_->SetMethodCallHandler(nullptr);
    security_channel_.reset();
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
