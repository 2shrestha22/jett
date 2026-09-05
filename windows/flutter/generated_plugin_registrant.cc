//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <desktop_drop/desktop_drop_plugin.h>
#include <file_selector_windows/file_selector_windows.h>
#include <sentry_flutter/sentry_flutter_plugin.h>
#include <uri_content/uri_content_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  DesktopDropPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DesktopDropPlugin"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  SentryFlutterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SentryFlutterPlugin"));
  UriContentPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UriContentPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
