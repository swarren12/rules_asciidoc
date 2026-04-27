#
# repository.bzl - Create a new ASCIIDoc repository
#
""" Configure the ASCIIDoc repository """

load("@bazel_lib//lib:repo_utils.bzl", "repo_utils")
load("//asciidoc/private:utils.bzl", _download_gem = "download_gem")

GEM_PLATFORM_TO_BAZEL_PLATFORM = {
    "aarch64-linux-gnu": "linux_arm64",
    "aarch64-linux-musl": "unsupported",
    "arm-linux-gnu": "unsupported",
    "arm-linux-musl": "unsupported",
    "arm64-darwin": "darwin_arm64",
    "x86_64-darwin": "darwin_amd64",
    "x86_64-linux-gnu": "linux_amd64",
    "x86_64-linux-musl": "unsupported",
}

def _hackily_parse_lock_file(repository_ctx, host_platform, lockfile):
    lockfile_content = repository_ctx.read(lockfile)

    gems_to_pull = {}
    in_checksums = False
    for line in lockfile_content.split("\n"):
        if "CHECKSUMS" == line:
            in_checksums = True
            continue

        if not in_checksums:
            continue

        if line == "" or not line.startswith("  "):
            break

        split = line[2:].split(" ")

        gem_name = split[0]
        gem_version_and_maybe_platform = split[1][1:-1]
        gem_version = gem_version_and_maybe_platform
        gem_platform = None
        gem_checksum = split[2]
        if "-" in gem_version_and_maybe_platform:
            sep_idx = gem_version_and_maybe_platform.index("-")
            gem_version = gem_version_and_maybe_platform[:sep_idx]
            gem_platform = gem_version_and_maybe_platform[sep_idx + 1:]

        if gem_platform != None and GEM_PLATFORM_TO_BAZEL_PLATFORM.get(gem_platform, "unsupported") != host_platform:
            print("Skipping unsupported platform {platform} for dependency {gem}-{version}".format(
                gem = gem_name,
                version = gem_version,
                platform = gem_platform,
            ))
            continue

        if gem_name in gems_to_pull:
            fail("Duplicate gem {gem}? This might cause problems!".format(gem = gem_name))
            return

        gems_to_pull[gem_name] = struct(
            name = gem_name,
            version = gem_version,
            platform = gem_platform,
            qualified_version = gem_version_and_maybe_platform,
            checksum = gem_checksum,
        )

    return gems_to_pull

def _path_as_str(path):
    """ Format a path as a quoted string """

    return "\"{path}\"".format(path = path) if path != None else None

def _symlink_bin(name, repository_ctx, gems, root_dir, gem_dir):
    """ Symlink the `asciidoctor` executables to `bin/` for convenience """

    if not name in gems:
        return None

    gem = gems[name]
    target = _resolve_gem_executable(gem)

    root_target = root_dir.get_child(target)
    gem_target = gem_dir.get_child(gem.gem_dir).get_child(target)

    repository_ctx.symlink(gem_target, root_target)

    return target

def _resolve_gem_executable(gem):
    """ Resolve the executable path of a gem """

    bin = gem.bin_dir
    exec = gem.executables[0]
    if len(gem.executables) > 1:
        print(
            "WARNING: Gem `{gem}-{version}` contains more than one declared executable! - using {exec}".format(
                gem = gem.name,
                version = gem.version,
                exec = exec,
            ),
        )

    return "{bin}/{exec}".format(bin = bin, exec = exec)

def _resolve_gem_require_dirs(gem_dir, gems):
    """ Flatten and expand the `require_paths` of all known gems """

    all_require_paths = []
    for (name, gem) in gems.items():
        gem_base_dir = gem_dir.get_child(gem.gem_dir)
        all_require_paths.extend([
            "{gem_base_dir}/{path}".format(gem_base_dir = gem_base_dir, path = path)
            for path in gem.require_paths
        ])

    return all_require_paths

def _asciidoc_repository(repository_ctx):
    """ Download and create a ASCIIDoc repository """

    root_dir = repository_ctx.path(".")
    gem_dir = root_dir.get_child("vendor")

    platform = repo_utils.platform(repository_ctx)

    gems_to_fetch = _hackily_parse_lock_file(repository_ctx, platform, repository_ctx.attr.lockfile)
    repository_ctx.report_progress("Downloading {n} gems".format(n = len(gems_to_fetch)))

    gems = {}
    for (_, gem) in gems_to_fetch.items():
        repository_ctx.report_progress("Downloading {gem}-{version}".format(gem = gem.name, version = gem.version))
        gems[gem.name] = _download_gem(repository_ctx, gem.name, gem.qualified_version, platform, gem_dir)

    asciidoctor_bin = _symlink_bin("asciidoctor", repository_ctx, gems, root_dir, gem_dir)
    asciidoctor_epub3_bin = _symlink_bin("asciidoctor-epub3", repository_ctx, gems, root_dir, gem_dir)
    asciidoctor_pdf_bin = _symlink_bin("asciidoctor-pdf", repository_ctx, gems, root_dir, gem_dir)

    gem_require_dirs = _resolve_gem_require_dirs(gem_dir, gems)

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
  files = glob(["**/*"]),
  requires = {require_paths},
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
  toolchain_type = "@rules_asciidoc//asciidoc:toolchain_type",
  visibility = ["//visibility:public"],
)
""".format(
            bin = _path_as_str(asciidoctor_bin),
            epub_bin = _path_as_str(asciidoctor_epub3_bin),
            pdf_bin = _path_as_str(asciidoctor_pdf_bin),
            require_paths = "[" + (",".join([_path_as_str(dir) for dir in gem_require_dirs])) + "]",
        ),
    )

asciidoc_repository = repository_rule(
    implementation = _asciidoc_repository,
    attrs = {
        "gemfile": attr.label(allow_single_file = True),
        "lockfile": attr.label(allow_single_file = True),
        "rubygem_url": attr.string(mandatory = False),
    },
)
