#
# extension.bzl - Bzlmod extension
#
""" Fetch and configure ASCIIDoc repositories. """

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
            gemfile = default_toolchain.gemfile,
            lockfile = default_toolchain.lockfile,
        )
    elif len(extra_toolchains) == 0:
        asciidoc_repository(
            name = "asciidoc",
            gemfile = "@rules_asciidoc//:Gemfile",
            lockfile = "@rules_asciidoc//:Gemfile.lock",
        )

    [
        asciidoc_repository(
            name = "asciidoctor_{}".format(toolchain.version),
            gemfile = default_toolchain.gemfile,
            lockfile = default_toolchain.lockfile,
        )
        for toolchain in extra_toolchains
    ]

    return module_ctx.extension_metadata(reproducible = True)

_toolchain = tag_class(
    attrs = {
        "gemfile": attr.label(allow_single_file = True),
        "lockfile": attr.label(allow_single_file = True),
        "is_default": attr.bool(default = True),
    },
)

asciidoc = module_extension(
    implementation = _asciidoc_impl,
    tag_classes = {"toolchain": _toolchain},
)
