# ABOUTME: Homebrew formula for First Folio.
# ABOUTME: Copy this file to tigger04/homebrew-tap/Formula/ after tagging a release.

class FirstFolio < Formula
  desc "Format converter for stage plays — org, markdown, fountain, PDF"
  homepage "https://github.com/tigger04/first-folio"
  url "https://github.com/tigger04/first-folio/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "PLACEHOLDER"
  license "MIT"
  head "https://github.com/tigger04/first-folio.git", branch: "master"

  depends_on "typst"

  def install
    # Main CLI
    bin.install "bin/folio"

    # Perl modules
    (lib/"folio").install Dir["lib/Folio"]
    (lib/"folio").install Dir["lib/Folio/Config"]
    (lib/"folio").install Dir["lib/Folio/Emitter"]
    (lib/"folio").install Dir["lib/Folio/Parser"]
    (lib/"folio").install Dir["lib/OrgPlay"]
    (lib/"folio").install Dir["lib/YAML"]

    # Style presets
    (share/"folio/presets").install Dir["presets/*"]

    # Rewrite the lib path in the folio script
    inreplace bin/"folio", '$FindBin::RealBin/../lib', "#{lib}/folio"
    inreplace bin/"folio", '$FindBin::RealBin/../presets', "#{share}/folio/presets"
  end

  def caveats
    <<~EOS
      First Folio converts stage plays between org-mode, Markdown,
      Fountain, and PDF formats. PDF output requires Typst.

      Try it:
        folio convert play.org play.pdf
        folio convert play.org --to md
        folio letter play.org

      Config: ~/.config/first-folio/script.yaml
      Styles: --style=british (default), --style=us, --style=screenplay

      See: #{homepage}
    EOS
  end

  test do
    assert_match "folio", shell_output("#{bin}/folio --version")
    assert_match "convert", shell_output("#{bin}/folio --help")
  end
end
