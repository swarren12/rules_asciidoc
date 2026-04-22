#
# repository.bzl - Create a new ASCIIDoc repository
#

_DEFAULT_VERSION = "2.0.26"
_DEFAULT_VERSION_INTEGRITY = "sha256-JcIrk0vAriRI8tc9Sy66DFngUhz16JP7CwrVSkYb8GY="

BASE_URL = "https://github.com/asciidoctor/asciidoctor/archive/refs/tags/v{version}.tar.gz"
EPUB_BASE_URL = "https://github.com/asciidoctor/asciidoctor-epub3/archive/refs/tags/v{version}.tar.gz"
PDF_BASE_URL = "https://github.com/asciidoctor/asciidoctor-pdf/archive/refs/tags/v{version}.tar.gz"

def _download(repository_ctx, base, version, integrity, root_dir, prefix, **kwargs):
    result = repository_ctx.download_and_extract(
        url = base.format(version = version),
        integrity = integrity,
        output = root_dir,
        strip_prefix = "{prefix}-{version}".format(prefix = prefix, version = version)
    )

    if not result:
        fail("Failed to download {prefix} v{version}".format(prefix = prefix, version = version))
        return

def _asciidoc_repository(repository_ctx):
    """ Download and create a ASCIIDoc repository """

    root_dir = repository_ctx.path(".")
    version = repository_ctx.attr.version
    integrity = repository_ctx.attr.integrity

    asciidoctor_bin = "\"bin/asciidoctor\""
    asciidoctor_epub3_bin = None
    asciidoctor_pdf_bin = None

    if version == None or len(version) == 0:
        version = _DEFAULT_VERSION
        integrity = integrity if integrity != None and len(integrity) > 0 else _DEFAULT_VERSION_INTEGRITY

    _download(repository_ctx, BASE_URL, version, integrity, root_dir, "asciidoctor")

    epub_version = repository_ctx.attr.epub_version
    epub_integrity = repository_ctx.attr.epub_integrity
    if epub_version != "":
        asciidoctor_epub3_bin = "\"bin/asciidoctor-epub3\""
        _download(repository_ctx, EPUB_BASE_URL, epub_version, epub_integrity, root_dir, "asciidoctor-epub3")

    pdf_version = repository_ctx.attr.pdf_version
    pdf_integrity = repository_ctx.attr.pdf_integrity
    if pdf_version != "":
        asciidoctor_pdf_bin = "\"bin/asciidoctor-pdf\""
        _download(repository_ctx, PDF_BASE_URL, epub_version, pdf_integrity, root_dir, "asciidoctor-pdf")


    repository_ctx.file(
        "BUILD.bazel",
        content = """
load("@rules_asciidoc//asciidoc:asciidoc.bzl", "asciidoc_toolchain")

filegroup(name = "files", srcs = glob(["**/*"]))

asciidoc_toolchain(
  name = "asciidoc",
  bin = {bin},
  epub_bin = {epub_bin},
  pdf_bin = {pdf_bin},
  files = ":files",
)

toolchain(
  name = "toolchain",
  exec_compatible_with = [
      "@platforms//os:linux",
      "@platforms//cpu:x86_64",
  ],
  target_compatible_with = [
      "@platforms//os:linux",
      "@platforms//cpu:x86_64",
  ],
  toolchain = ":asciidoc",
  toolchain_type = "@rules_asciidoc//toolchain:asciidoc",
  visibility = ["//visibility:public"],
)
""".format(bin = asciidoctor_bin, epub_bin = asciidoctor_epub3_bin, pdf_bin = asciidoctor_pdf_bin)
    )

asciidoc_repository = repository_rule(
    implementation = _asciidoc_repository,
    attrs = {
        "version": attr.string(mandatory = False),
        "integrity": attr.string(mandatory = False),
        "epub_version": attr.string(mandatory = False),
        "epub_integrity": attr.string(mandatory = False),
        "pdf_version": attr.string(mandatory = False),
        "pdf_integrity": attr.string(mandatory = False),
    }
)