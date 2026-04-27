#
# toolchain.bzl - ASCIIDoc toolchain provider
#
""" ASCIIDoc Toolchain """

AsciidocInfo = provider(
    doc = "ASCIIDoc Toolchain",
    fields = [
        # Actual files / filegroups
        "bin",
        "epub_bin",
        "pdf_bin",
    ],
)

def _asciidoc_toolchain_impl(ctx):
    """ ASCIIDoc Toolchain """

    toolchain_info = platform_common.ToolchainInfo(
        asciidoc = AsciidocInfo(
            bin = ctx.file.bin,
            epub_bin = ctx.file.epub_bin,
            pdf_bin = ctx.file.pdf_bin,
        ),
        files = ctx.files.files,
        requires = ctx.attr.requires,
    )
    return [toolchain_info]

asciidoc_toolchain = rule(
    implementation = _asciidoc_toolchain_impl,
    attrs = {
        "bin": attr.label(allow_single_file = True),
        "epub_bin": attr.label(allow_single_file = True),
        "pdf_bin": attr.label(allow_single_file = True),
        "files": attr.label_list(allow_files = True),
        "requires": attr.string_list(default = ["lib"]),
    },
)
