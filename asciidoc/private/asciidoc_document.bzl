#
# asciidoc_document.bzl - ASCIIDoc document rule
#
"""ASCIIDoc Document Rule"""

FORMAT_TO_BACKEND_MAP = {
    "html": "html5",
    "man": "manpage",
    "docbook": "docbook5",
}

def _asciidoc_doc(ctx):
    """Processes an ASCIIDoc document."""

    inputs = depset(ctx.files.srcs)
    output = ctx.actions.declare_file("%s.%s" % (ctx.attr.name, ctx.attr.format))
    backend = FORMAT_TO_BACKEND_MAP[ctx.attr.format]

    asciidoc = ctx.toolchains["//toolchain:asciidoc"].asciidoc
    tools = depset([asciidoc.bin], transitive = [depset(asciidoc.files)])

    args = ctx.actions.args()
    args.add("--backend", backend)
    args.add("--out-file", output.path)
    if ctx.attr.verbose:
        args.add("--verbose")
    args.add(ctx.file.main.path)

    ctx.actions.run_shell(
        command = "{cmd} $@".format(cmd = asciidoc.bin.path),
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        tools = tools,
        mnemonic = "ASCIIDoc",
        progress_message = "Processing ASCIIDoc document %s" % ctx.file.main.short_path,
    )

    return DefaultInfo(files = depset([output]))

asciidoc_document = rule(
    implementation = _asciidoc_doc,
    attrs = {
        "srcs": attr.label_list(
            doc = "A list of source files to be processed.",
            allow_files = True,
        ),
        "main": attr.label(
            doc = "The main source file of the document.",
            allow_single_file = [".adoc"],
            mandatory = True,
        ),
        "format": attr.string(
            doc = "The output format of the document.",
            values = FORMAT_TO_BACKEND_MAP.keys(),
            default = "html",
        ),
        "verbose": attr.bool(
            doc = "Enables verbose output from the AsciiDoc processor.",
            default = False,
        ),
    },
    toolchains = ["//toolchain:asciidoc"],
)

#
# Usage:
#  asciidoc_document(
#      name = "my-doc",
#      src = glob(["*.adoc"]),
#      main = "index.adoc",
#      format = "html"
#  )
#