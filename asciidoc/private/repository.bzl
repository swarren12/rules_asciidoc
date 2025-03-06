#
# repository.bzl - Create a new ASCIIDoc repository
#

DEFAULT_VERSION = "2.0.26"
DEFAULT_VERSION_INTEGRITY = "sha256-JcIrk0vAriRI8tc9Sy66DFngUhz16JP7CwrVSkYb8GY="
BASE_URL = "https://github.com/asciidoctor/asciidoctor/archive/refs/tags/v{version}.tar.gz"

def _asciidoc_repository(repository_ctx):
    """ Download and create a ASCIIDoc repository """

    root_dir = repository_ctx.path(".")
    version = repository_ctx.attr.version
    integrity = repository_ctx.attr.integrity

    if version == None:
        version = DEFAULT_VERSION
        integrity = integrity or DEFAULT_VERSION_INTEGRITY

    result = repository_ctx.download_and_extract(
        url = BASE_URL.format(version = version),
        integrity = integrity,
        output = root_dir,
        strip_prefix = "asciidoctor-{version}".format(version = version)
    )

    if not result:
        fail("Failed to download ASCIIDoc v{version}".format(version = version))
        return

    repository_ctx.file(
        "BUILD.bazel",
        content = """
load("@rules_asciidoc//asciidoc:asciidoc.bzl", "asciidoc_toolchain")

filegroup(name = "files", srcs = glob(["**/*"]))

asciidoc_toolchain(
  name = "asciidoc",
  bin = "bin/asciidoctor",
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
  toolchain_type = "@rules_asciidoc//toolchain:toolchain_type",
  visibility = ["//visibility:public"],
)
"""
    )

asciidoc_repository = repository_rule(
    implementation = _asciidoc_repository,
    attrs = {
        "version": attr.string(mandatory = False),
        "integrity": attr.string(mandatory = False),
        # "url": attr.string(mandatory = True),
        # "sha256": attr.string(mandatory = True),
    }
)