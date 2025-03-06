#
# extension.bzl - Bzlmod extension
#
"""Fetch and configure ASCIIDoc repositories."""

load("//asciidoc/private:repository.bzl", "asciidoc_repository")

def _asciidoc_impl(module_ctx):
    """Fetches and configures the required ASCIIDoc toolchains."""

    default_toolchain = None
    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            if toolchain.is_default:
                if default_toolchain:
                    fail("Multiple default ASCIIDoc toolchains are not allowed.")
                default_toolchain = toolchain

    if default_toolchain:
        asciidoc_repository(
            name = "asciidoc",
            version = default_toolchain.version,
            integrity = default_toolchain.integrity,
        )

    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            if not toolchain.is_default:
                asciidoc_repository(
                    name = "asciidoctor_{}".format(toolchain.version),
                    version = toolchain.version,
                    integrity = toolchain.integrity,
                )

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
