#!/bin/sh
#
sudo nixos-container  update lichess --flake .#container
sudo nixos-container  start lichess
sudo nixos-container  root-login lichess
