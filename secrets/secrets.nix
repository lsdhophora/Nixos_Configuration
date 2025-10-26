let
  lysergic = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICFlmTK+LHn4o8U2ZiF/Cm5V1rJFYBTWoIC5Vy32n3Ie lysergic"; # 替换为实际公钥
in
{
  "access-tokens-github.age".publicKeys = [ lysergic ];
  "config.dae.age".publicKeys = [ lysergic ];
}
