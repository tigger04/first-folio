# ABOUTME: Homebrew formula for First Folio.
# ABOUTME: Copy this file to tigger04/homebrew-tap/Formula/ after tagging a release.

class FirstFolio < Formula
  desc "Format converter for stage plays — org, markdown, fountain, PDF"
  homepage "https://github.com/tigger04/first-folio"
  url "https://github.com/tigger04/first-folio/archive/refs/tags/v0.4.1.tar.gz"
  sha256 "613762f60f192de46866d1c2d79a3ce8b7e0d86c7991f4e95d4e635886c84071"
  license "MIT"
  head "https://github.com/tigger04/first-folio.git", branch: "master"

  depends_on "typst"

  def install
    # Install into libexec preserving the directory structure so
    # FindBin resolves ../lib and ../presets correctly from bin/
    (libexec/"bin").install "bin/folio"
    libexec.install "lib"
    libexec.install "presets"

    # Wrapper script in bin/ that exec's the real one
    (bin/"folio").write <<~SH
      #!/bin/bash
      exec "#{libexec}/bin/folio" "$@"
    SH
    (bin/"folio").chmod 0755
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
