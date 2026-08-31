{{flutter_js}}
{{flutter_build_config}}

// Flutter's generated service worker can keep an older preview alive in an
// existing browser tab. Unregister previous workers before booting the app so
// every GitHub Pages preview loads the current build.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((registrations) => {
    registrations.forEach((registration) => registration.unregister());
  });
}

_flutter.loader.load();
