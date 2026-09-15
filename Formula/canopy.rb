require "open3"
require "socket"

class Canopy < Formula
  desc "Local-first workspace where AI coding agents work as a team"
  homepage "https://github.com/tiki51/canopy"
  url "https://github.com/tiki51/canopy/releases/download/v0.1.0-beta.1/canopy-0.1.0-beta.1-aarch64-apple-darwin.tar.gz"
  sha256 "a617b2ad131f7c34c7e487401cd748ade94db810fe2525737af0cab202724aa7"
  license "MIT"
  revision 1

  depends_on arch: :arm64
  depends_on :macos

  def install
    libexec.install Dir["*"]

    (bin/"canopy").write <<~SH
      #!/bin/sh
      set -eu

      if [ -n "${CANOPY_STATE_DIR:-}" ]; then
        state_dir="$CANOPY_STATE_DIR"
      elif [ -n "${XDG_DATA_HOME:-}" ]; then
        state_dir="$XDG_DATA_HOME/canopy"
      else
        state_dir="$HOME/Library/Application Support/Canopy"
      fi

      config_dir="$state_dir/config"
      secret_file="${CANOPY_SECRET_FILE:-$config_dir/secret_key_base}"
      umask 077
      mkdir -p "$config_dir" "${CANOPY_FILES_DIR:-$state_dir/files}"

      if [ -z "${SECRET_KEY_BASE:-}" ]; then
        if [ ! -s "$secret_file" ]; then
          secret=$(/usr/bin/openssl rand -hex 64)
          (set -C; printf '%s\n' "$secret" > "$secret_file") 2>/dev/null || true
        fi
        IFS= read -r SECRET_KEY_BASE < "$secret_file"
      fi

      PORT="${PORT:-4000}"
      DATABASE_PATH="${DATABASE_PATH:-$state_dir/canopy.db}"
      CANOPY_FILES_DIR="${CANOPY_FILES_DIR:-$state_dir/files}"
      CANOPY_URL="${CANOPY_URL:-http://127.0.0.1:$PORT}"

      export PORT DATABASE_PATH CANOPY_FILES_DIR CANOPY_URL SECRET_KEY_BASE

      seed() {
        (
          unset PHX_SERVER
          RELEASE_NODE="canopy_seed_$$@localhost"
          export RELEASE_NODE
          exec "#{libexec}/bin/canopy" eval 'Code.ensure_loaded!(Canopy.Release); if function_exported?(Canopy.Release, :seed, 0), do: Canopy.Release.seed(), else: (Application.ensure_all_started(:canopy); Code.eval_file(Application.app_dir(:canopy, "priv/repo/seeds.exs")))'
        )
      }

      if [ "${1:-}" = "seed" ]; then
        shift
        if [ "$#" -ne 0 ]; then
          printf '%s\n' "usage: canopy seed" >&2
          exit 64
        fi
        seed
        exit
      fi

      if [ "${1:-}" = "start" ] && [ ! -e "$DATABASE_PATH" ]; then
        seed
      fi

      PHX_SERVER=true
      export PHX_SERVER
      exec "#{libexec}/bin/canopy" "$@"
    SH
  end

  def caveats
    <<~EOS
      Canopy is currently an Apple Silicon beta.

      Start it in the foreground with:
        canopy start

      A new database receives the default agents automatically. To add any
      missing defaults later without overwriting customized agents, run:
        canopy seed

      Then open http://127.0.0.1:4000. User data is stored under:
        ~/Library/Application Support/Canopy

      Claude Code and OpenCode are optional, independently installed engines.
    EOS
  end

  test do
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close

    ENV["CANOPY_STATE_DIR"] = (testpath/"state").to_s
    ENV["PORT"] = port.to_s
    ENV["CANOPY_URL"] = "http://127.0.0.1:#{port}"

    log = testpath/"canopy.log"
    pid = spawn bin/"canopy", "start", out: log.to_s, err: [:child, :out]

    begin
      response = ""

      60.times do
        response, status = Open3.capture2e(
          "/usr/bin/curl", "--fail", "--silent", "http://127.0.0.1:#{port}/health"
        )
        break if status.success?

        sleep 1
      end

      assert_match '"status":"ok"', response
      assert_path_exists testpath/"state/canopy.db"
      assert_match "created agent @backend", File.binread(log).scrub
      seed_output = shell_output("#{bin}/canopy seed")
      assert_match "agent @backend already exists", seed_output
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
