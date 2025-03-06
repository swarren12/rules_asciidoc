#
# toolchain.bzl - ASCIIDoc toolchain provider
#

AsciidocInfo = provider(
    doc = "ASCIIDoc Toolchain",
    fields = [
        # Actual files / filegroups
        "bin",
        "bin_dir",
        "files",
    ],
)

def _asciidoc_toolchain_impl(ctx):
    """ ASCIIDoc Toolchain """

    toolchain_info = platform_common.ToolchainInfo(
        asciidoc = AsciidocInfo(
            bin = ctx.file.bin,
            files = ctx.files.files,
        ),
    )
    return [toolchain_info]

asciidoc_toolchain = rule(
    implementation = _asciidoc_toolchain_impl,
    attrs = {
        "bin": attr.label(allow_single_file = True),
        "files": attr.label(allow_files = True),
    },
)