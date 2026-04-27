#
# asciidoc_document.bzl - ASCIIDoc document rule
#
""" ASCIIDoc Document Rule """

FORMAT_TO_BACKEND_MAP = {
    "html": "html5",
    "man": "manpage",
    "docbook": "docbook5",
    "epub": "epub",
    "pdf": "pdf",
}

def _asciidoc_doc(ctx):
    """Processes an ASCIIDoc document."""

    inputs = depset(ctx.files.srcs)
    main = ctx.file.main.path
    format = ctx.attr.format
    backend = FORMAT_TO_BACKEND_MAP[format]

    output = ctx.outputs.out
    if output == None:
        appropriate_name = ctx.label.package if len(ctx.label.package) > 0 else main[:-5]
        output_filename = "{name}.{ext}".format(name = appropriate_name, ext = format)
        output = ctx.actions.declare_file(output_filename)

    ruby = ctx.toolchains["@rules_ruby//ruby:toolchain_type"]
    ruby_exec = ruby.ruby.path

    asciidoc = ctx.toolchains["//asciidoc:toolchain_type"]
    asciidoctor_exec = asciidoc.asciidoc.bin
    asciidoc_backend = backend

    if format == "epub":
        if asciidoc.asciidoc.epub_bin == None:
            fail("epub support not enabled; set `epub_version` in `asciidoctor.toolchain()`")
        asciidoctor_exec = asciidoc.asciidoc.epub_bin
        asciidoc_backend = None
    elif format == "pdf":
        if asciidoc.asciidoc.pdf_bin == None:
            fail("pdf support not enabled; set `pdf_version` in `asciidoctor.toolchain()`")
        asciidoctor_exec = asciidoc.asciidoc.pdf_bin
        asciidoc_backend = None

    args = ctx.actions.args()
    args.add(asciidoctor_exec.path)
    if asciidoc_backend != None:
        args.add("--backend", backend)

    args.add("--out-file", output.path)
    if ctx.attr.verbose:
        args.add("--verbose")
    args.add(main)

    tools = depset([ruby.ruby, asciidoctor_exec], transitive = [depset(asciidoc.files), depset(ruby.files)])

    ctx.actions.run_shell(
        command = "{ruby} $@".format(ruby = ruby_exec),
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        tools = tools,
        env = {
            # Hack - work out if we can do this better?
            "RUBYLIB": ":".join(asciidoc.requires),
        },
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
        "out": attr.output(
            doc = "Output filename",
            mandatory = False,
        ),
    },
    toolchains = ["//asciidoc:toolchain_type", "@rules_ruby//ruby:toolchain_type"],
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
