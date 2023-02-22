{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
    lichess-bot = {
      url = "github:ShailChoksi/lichess-bot";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, lichess-bot }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      nixosModule = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.nix-chess.services.lichess-bot;
        in
        {
          options.nix-chess.services.lichess-bot = {
            enable = mkEnableOption "Enables the lichess-bot";
            token = mkOption {
              type = types.str;
              default = "@LICHESS_BOT_TOKEN@";
              description = "Token for the bot";
            };
            skill = mkOption {
              type = types.str;
              default = "3";
              description = "skill level of the bot 0-10";
            };
            games = mkOption {
              type = types.str;
              default = "3";
              description = "number of games to play simultaneously";
            };
          };

          config = mkIf cfg.enable {
            systemd.services."nix-chess.lichess-bot" = {
              wantedBy = [ "multi-user.target" ];

              serviceConfig =
                let pkg = forAllSystems (system: self.packages.${system}.lichess-bot);
                in {
                  Restart = "on-failure";
                  ExecStart = "${self.packages.x86_64-linux.lichess-bot}/bin/lichess-bot --config ${pkgs.writeTextDir "config.yml" ''
token: "${cfg.token}"    # Lichess OAuth2 Token.
url: "https://lichess.org/"  # Lichess base URL.

engine:                      # Engine settings.
  dir: "${self.packages.x86_64-linux.lichess-bot}/engines/"          # Directory containing the engine. This can be an absolute path or one relative to lichess-bot/.
  name: "stockfish"        # Binary name of the engine to use.
  working_dir: ""            # Directory where the chess engine will read and write files. If blank or missing, the current directory is used.
  protocol: "uci"            # "uci", "xboard" or "homemade"
  ponder: true               # Think on opponent's time.
  polyglot:
    enabled: true # Activate polyglot book.
    book:
      standard:              # List of book file paths for variant standard.
        - ${self.packages.x86_64-linux.lichess-bot}/engines/nc3nc6.bin
#     atomic:                # List of book file paths for variant atomic.
#       - engines/atomicbook1.bin
#       - engines/atomicbook2.bin
#     etc.
#     Use the same pattern for 'giveaway' (antichess), 'crazyhouse', 'horde', 'kingofthehill', 'racingkings' and '3check' as well.
    min_weight: 0            # Does not select moves with weight below min_weight (min 0, max: 65535).
    selection: "weighted_random" # Move selection is one of "weighted_random", "uniform_random" or "best_move" (but not below the min_weight in the 2nd and 3rd case).
    max_depth: 20             # How many moves from the start to take from the book.
  draw_or_resign:
    resign_enabled: true
    resign_score: -1000      # If the score is less than or equal to this value, the bot resigns (in cp).
    resign_for_egtb_minus_two: true # If true the bot will resign in positions where the online_egtb returns a wdl of -2.
    resign_moves: 3          # How many moves in a row the score has to be below the resign value.
    offer_draw_enabled: true
    offer_draw_score: 0      # If the absolute value of the score is less than or equal to this value, the bot offers/accepts draw (in cp).
    offer_draw_for_egtb_zero: true # If true the bot will offer/accept draw in positions where the online_egtb returns a wdl of 0.
    offer_draw_moves: 5      # How many moves in a row the absolute value of the score has to be below the draw value.
    offer_draw_pieces: 10    # Only if the pieces on board are less than or equal to this value, the bot offers/accepts draw.
  online_moves:
    max_out_of_book_moves: 20 # Stop using online opening books after they don't have a move for 'max_out_of_book_moves' positions. Doesn't apply to the online endgame tablebases.
    max_retries: 2           # The maximum amount of retries when getting an online move.
    chessdb_book:
      enabled: false
      min_time: 20
      move_quality: "good"   # One of "all", "good", "best".
      min_depth: 20          # Only for move_quality: "best".
      contribute: true
    lichess_cloud_analysis:
      enabled: false
      min_time: 20
      move_quality: "good"   # One of "good", "best".
      max_score_difference: 50 # Only for move_quality: "good". The maximum score difference (in cp) between the best move and the other moves.
      min_depth: 20
      min_knodes: 0
    online_egtb:
      enabled: false
      min_time: 20
      max_pieces: 7
      source: "lichess"      # One of "lichess", "chessdb".
      move_quality: "best"   # One of "good", "best", "suggest" (it takes all the "good" moves and tells the engine to only consider these; will move instantly if there is only 1 "good" move).
  lichess_bot_tbs:
    syzygy:
      enabled: false
      paths:
        - "engines/syzygy"
      max_pieces: 7
      move_quality: "best"   # One of "good", "best", "suggest" (it takes all the "good" moves and tells the engine to only consider these; will move instantly if there is only 1 "good" move).
    gaviota:
      enabled: false
      paths:
        - "engines/gaviota"
      max_pieces: 5
      min_dtm_to_consider_as_wdl_1: 120  # The minimum dtm to consider as syzygy wdl=1/-1. Set to 100 to disable.
      move_quality: "best"   # One of "good", "best", "suggest" (it takes all the "good" moves and tells the engine to only consider these; will move instantly if there is only 1 "good" move).
# engine_options:            # Any custom command line params to pass to the engine.
#   cpuct: 3.1
  homemade_options:
#   Hash: 256
  uci_options:               # Arbitrary UCI options passed to the engine.
    Move Overhead: 100       # Increase if your bot flags games too often.
    Threads: 2               # Max CPU threads the engine can use.
    Hash: 256                # Max memory (in megabytes) the engine can allocate.
    Skill Level: ${cfg.skill}
  silence_stderr: false      # Some engines (yes you, Leela) are very noisy.

abort_time: 20               # Time to abort a game in seconds when there is no activity.
fake_think_time: false       # Artificially slow down the bot to pretend like it's thinking.
rate_limiting_delay: 0       # Time (in ms) to delay after sending a move to prevent "Too Many Requests" errors.
move_overhead: 2000          # Increase if your bot flags games too often.

correspondence:
  move_time: 60            # Time in seconds to search in correspondence games.
  checkin_period: 600      # How often to check for opponent moves in correspondence games after disconnecting.
  disconnect_time: 300     # Time before disconnecting from a correspondence game.
  ponder: false            # Ponder in correspondence games the bot is connected to.

challenge:                   # Incoming challenges.
  concurrency: ${cfg.games}             # Number of games to play simultaneously.
  sort_by: "best"            # Possible values: "best" and "first".
  accept_bot: true           # Accepts challenges coming from other bots.
  only_bot: false            # Accept challenges by bots only.
  max_increment: 180         # Maximum amount of increment to accept a challenge. The max is 180. Set to 0 for no increment.
  min_increment: 0           # Minimum amount of increment to accept a challenge.
  max_base: 315360000        # Maximum amount of base time to accept a challenge. The max is 315360000 (10 years).
  min_base: 0                # Minimum amount of base time to accept a challenge.
  max_days: 14               # Maximum number of days per move to accept a challenge for a correspondence game.
                             # Unlimited games can be accepted by removing this field or specifying .inf
  min_days: 1                # Minimum number of days per move to accept a challenge for a correspondence game.
  variants:                  # Chess variants to accept (https://lichess.org/variant).
    - standard
    - fromPosition
#   - antichess
#   - atomic
#   - chess960
#   - crazyhouse
#   - horde
#   - kingOfTheHill
#   - racingKings
#   - threeCheck
  time_controls:             # Time controls to accept.
    - bullet
    - blitz
    - rapid
    - classical
#   - correspondence
  modes:                     # Game modes to accept.
    - casual                 # Unrated games.
    - rated                  # Rated games - must comment if the engine doesn't try to win.

greeting:
  # Optional substitution keywords (include curly braces):
  #   {opponent} to insert opponent's name
  #   {me} to insert bot's name
  # Any other words in curly braces will be removed.
  hello: "Hi! I'm {me}. Good luck! Type !help for a list of commands I can respond to." # Message to send to opponent chat at the start of a game
  goodbye: "Good game!" # Message to send to opponent chat at the end of a game
  hello_spectators: "Hi! I'm {me}. Type !help for a list of commands I can respond to." # Message to send to spectator chat at the start of a game
  goodbye_spectators: "Thanks for watching!" # Message to send to spectator chat at the end of a game

# pgn_directory: "game_records" # A directory where PGN-format records of the bot's games are kept

matchmaking:
  allow_matchmaking: true     # Set it to 'true' to challenge other bots.
  challenge_variant: "random" # If set to 'random', the bot will choose one variant from the variants enabled in 'challenge.variants'.
  challenge_timeout: 1       # Create a challenge after being idle for 'challenge_timeout' minutes. The minimum is 1 minute.
  challenge_initial_time:     # Initial time in seconds of the challenge (to be chosen at random).
    - 300
    - 600
  challenge_increment:        # Increment in seconds of the challenge (to be chosen at random).
    - 3
    - 5
#  challenge_days:            # Days for correspondence challenge (to be chosen at random).
#    - 1
#    - 2
# opponent_min_rating: 600    # Opponents rating should be above this value (600 is the minimum rating in lichess).
# opponent_max_rating: 4000   # Opponents rating should be below this value (4000 is the maximum rating in lichess).
  opponent_rating_difference: 3000 # The maximum difference in rating between the bot's rating and opponent's rating.
  opponent_allow_tos_violation: true # Set to 'false' to prevent challenging bots that violated Lichess Terms of Service.
  challenge_mode: "random"    # Set it to the mode in which challenges are sent. Possible options are 'casual', 'rated' and 'random'.
  delay_after_decline: none  # If a bot declines a challenge, delay issuing another challenge to that bot. Possible options are 'none', 'coarse', and 'fine'.


      ''}/config.yml";
                  DynamicUser = "yes";
                  RuntimeDirectory = "nix-chess.lichess-bot";
                  RuntimeDirectoryMode = "0755";
                  StateDirectory = "nix-chess.lichess-bot";
                  StateDirectoryMode = "0700";
                  CacheDirectory = "nix-chess.lichess-bot";
                  CacheDirectoryMode = "0750";
                };
            };
          };
        };


      nixosConfigurations.container = nixpkgs.lib.nixosSystem {
        #system = "${forAllSystems (system: system)}";
        system = "x86_64-linux";
        modules = [
          self.nixosModule

          ({

            # Only allow this to boot as a container
            #boot.isContainer = true;
            networking.hostName = "lichess-bot";
            nix-chess.services.lichess-bot = {
              enable = true;
              token = "******************";
            };
            services.getty.autologinUser = "root";
            environment.systemPackages = [
              self.packages.x86_64-linux.lichess-bot
            ];
          })
        ];
      };
      packages = forAllSystems (system: {

        lichess-bot = pkgs.${system}.stdenv.mkDerivation {
          name = "lichess-bot";
          src = lichess-bot;
          buildInputs = with pkgs.${system}; [
            stockfish
            (python3.withPackages (ps: with ps;
            [
              chess
              pyyaml
              requests
              backoff
              rich

              # Requirements for tests
              pytest
              pytest-timeout
            ]))
          ];
          buildPhase = ''
            echo "#!/usr/bin/env python3" > lichess-bot
            cat lichess-bot.py >> lichess-bot
            rm lichess-bot.py
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp *.py $out/bin
            install -t $out/bin lichess-bot
            mkdir -p $out/engines
            install ${self.packages.${system}.openingbook}/engines/*.bin $out/engines
            install ${pkgs.${system}.stockfish}/bin/stockfish $out/engines/stockfish
          '';
          propagatedBuildInputs = with pkgs.${system}; [
            #python3Packages.requests
            stockfish

            (python3.withPackages (ps: with ps;
            [
              chess
              pyyaml
              requests
              backoff
              rich

              # Requirements for tests
              pytest
              pytest-timeout
            ]))
            #python3Minimal
          ];
        };
        openingbook = pkgs.${system}.stdenv.mkDerivation {
          name = "openingbook";
          src = ./.;
          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/engines
            install *.bin $out/engines
          '';
        };
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.lichess-bot);

      formatter = forAllSystems (system: pkgs.${system}.nixpkgs-fmt);

      devShells = forAllSystems (system: {
        default = pkgs.${system}.mkShellNoCC {
          packages = with pkgs.${system}; [
            (forAllSystems (system: self.packages.${system}.lichess-bot))
            stockfish
            #python3Minimal
            #python3Packages.requests
            (python3.withPackages (ps: with ps; [ requests ]))
          ];
        };
      });
      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.lichess-bot}/bin/lichess-bot";
        };
      });
    };
}
