class Runta < Formula
  desc "CLI for the Runta service"
  homepage "https://github.com/runta-dev/runta"
  version "0.2.15"

  on_macos do
    on_arm do
      url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.zip"
      sha256 "c4b4ff4c7b380c8b68f8af50fe7e15295f9ffef688b6844d11c2a60b9a54741f"
    end

    on_intel do
      odie "runta only supports Apple Silicon"
    end
  end

  def install
    bin.install "runta"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/runta --version")
  end
end
