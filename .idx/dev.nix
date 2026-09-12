{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.git
  ];

  idx = {
    extensions = [
      "Dart-Code.dart-code"
      "Dart-Code.flutter"
    ];

    previews = {
      enable = true;
      previews = {
        web = {
          command = [
            "flutter"
            "run"
            "-d"
            "web-server"
            "--web-hostname"
            "0.0.0.0"
            "--web-port"
            "$PORT"
          ];
          manager = "flutter";
        };
        android = {
          manager = "flutter";
        };
      };
    };
  };

  bootstrap = {
    onCreate = {
      install = "flutter pub get";
    };
  };
}
