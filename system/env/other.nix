{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    chez
    racket
  ];
}
