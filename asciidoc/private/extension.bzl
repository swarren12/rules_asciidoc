#
# extension.bzl - Bzlmod extension
#
"""Fetch and configure ASCIIDoc repositories."""

load("//asciidoc/private:repository.bzl", "asciidoc_repository")

def _asciidoc_impl(module_ctx):
    """Fetches and configures the required ASCIIDoc toolchains."""

    default_toolchain = None
    extra_toolchains = []
    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            if toolchain.is_default:
                if default_toolchain:
                    fail("Multiple default ASCIIDoc toolchains are not allowed.")
                default_toolchain = toolchain
            else:
                extra_toolchains.append(toolchain)

    if default_toolchain:
        asciidoc_repository(
            name = "asciidoc",
            version = default_toolchain.version,
            integrity = default_toolchain.integrity,
        )
    elif len(extra_toolchains) == 0:
        asciidoc_repository(name = "asciidoc")

    [
        asciidoc_repository(
            name = "asciidoctor_{}".format(toolchain.version),
            version = toolchain.version,
            integrity = toolchain.integrity,
        )
        for toolchain
        in extra_toolchains
    ]

    return module_ctx.extension_metadata(reproducible = True)

_toolchain = tag_class(
    attrs = {
        "version": attr.string(mandatory = False),
        "integrity": attr.string(mandatory = False),
        "is_default": attr.bool(default = True),
    },
)

asciidoc = module_extension(
    implementation = _asciidoc_impl,
    tag_classes = {"toolchain": _toolchain},
)
