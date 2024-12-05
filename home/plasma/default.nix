{pkgs,plasma-manager,username,...} : {
  imports = [
    plasma-manager.homeManagerModules.plasma-manager
  ];
  home.packages = with pkgs; [
    plasma-panel-colorizer
  ];
  # give up on the full plasma config for now, due to bugs.
  programs.plasma = {
    enable = true;
    overrideConfig = false;
    kscreenlocker.lockOnStartup = false;
    kscreenlocker.passwordRequired = false;
    shortcuts = {
      "services/Alacritty.desktop"."_launch" = "Ctrl+Alt+T";
    };
    # panels = [
    #   {
    #     screen = 0;
    #     location = "top";
    #     alignment = "center";
    #     floating = false;
    #     height = 22;
    #     hiding = "normalpanel";
    #     lengthMode = "fill";
    #     # share/plasma/plasmoids
    #     widgets = [
    #       "org.kde.plasma.marginsseparator"
    #       {
    #         kickoff = {
    #           icon = "nix-snowflake";
    #         };
    #       }
    #       "org.kde.plasma.marginsseparator"
    #       {
    #         name = "com.dv.uswitcher";
    #         config = {
    #           General = {
    #             icon = "~/nixos/assets/glom.jpg";
    #             showFace=true;
    #           };
    #         };
    #       }
    #       "org.kde.plasma.marginsseparator"
    #       "org.kde.plasma.showdesktop"
    #       {
    #         name = "org.kde.windowtitle.Fork";
    #         config = {
    #           General = {
    #             spacing = 10;
    #             lengthFirstMargin = 5;
    #             lengthLastMargin = 5;
    #           };
    #         };
    #       }
    #       "org.kde.plasma.panelspacer"
    #       {
    #         digitalClock = {
    #           date = {
    #             enable = true;
    #             format = "isoDate";
    #             position = "besideTime";
    #           };
    #           time = {
    #             showSeconds = "never";
    #             format = "12h";
    #           };
    #           timeZone = { 
    #             selected = ["Asia/Singapore"];
    #           };
    #           calendar = {
    #             firstDayOfWeek = "sunday";
    #             plugins = [
    #               "holidaysevents"
    #               "alternatecalendar"
    #               "astronomicalevents"
    #             ];
    #             showWeekNumbers = true;
    #           };
    #         };
    #       }
    #       # {
    #       #   name = "org.kde.plasma.weather";
    #       #   config = {
    #       #     General = {
    #       #       Units = "{pressureUnit: 5007,speedUnit:9000,temperatureUnit:6001,visibilityUnit:2007}";
    #       #       WeatherStation = "{ source : \"bbcukmet|weather|Kuala Lumpur, Malaysia, MY|1735161\" }";
    #       #     };
    #       #   };
    #       # }
    #       "org.kde.plasma.panelspacer"
    #       # {
    #       #     name = "org.kde.olib.thermalmonitor";
    #       #     config = {
    #       #       General = {
    #       #         sensors = ''[{"name":"CPU Temperature","sensorId":"cpu/all/averageTemperature"}]'';
                  
    #       #         # [
    #       #         #     "[{"name":"CPU Temperature","sensorId":"cpu/all/averageTemperature"}]"
    #       #         #     # {"name":"GPU Temperature","sensorId":"gpu/gpu1/temperature"}
    #       #         #   ];
    #       #     };
    #       #   };
    #       # }
    #       "org.kde.netspeedWidget"
    #       {
    #         systemTray.items = {
    #           shown = [
    #             "org.kde.plasma.clipboard"
    #             "org.kde.plasma.manage-inputmethod"
    #             "org.kde.plasma.volume"
    #             "org.kde.plasma.bluetooth"
    #             "org.kde.plasma.networkmanagement"
    #             "org.kde.plasma.battery"
    #           ];
    #           hidden = [
    #             "org.kde.plasma.brightness"
    #             "org.kde.kscreen"
    #             "org.kde.plasma.printmanager"
    #             "org.kde.plasma.mediacontroller"
    #             "org.kde.plasma.keyboardindicator"
    #             "blueman"
    #           ];
    #         };
    #       }
    #       "org.kde.plasma.notifications"
    #     ];
    #   }
    #   {
    #     screen = 0;
    #     location = "bottom";
    #     alignment = "center";
    #     floating = true;
    #     height = 40;
    #     hiding = "dodgewindows";
    #     lengthMode = "fit";
    #     widgets = [
    #       {
    #         iconTasks = {
    #           launchers = [
    #             "applications:org.kde.dolphin.desktop"
    #             "applications:microsoft-edge.desktop"
    #             "applications:code.desktop"
    #           ];
    #         };
    #       }
    #       # {
    #       #   plasmaPanelColorizer = {
    #       #     general = {
    #       #       enable = true;
    #       #       hideWidget = true;
    #       #     };
              
    #       #     widgetBackground = {
    #       #       shape = {
    #       #         radius = 12;
    #       #       };
    #       #     };
    #       #   };
    #       # }
    #     ];
    #   }
    # ];
  };
}