#
# utils.bzl - Miscellaneous helper methods
#
""" Utility methods """

DEFAULT_RUBYGEM_URL = "https://rubygems.org/downloads/"

# Shamelessly stolen from https://github.com/aspect-build/rules_js/blob/main/npm/private/npm_translate_lock_state.bzl
def _yaml_to_json(repository_ctx, platform, yaml_path):
    """ Use yq to convert a YAML document into JSON """

    host_yq = Label("@yq_{}//:yq{}".format(platform, ".exe" if platform.startswith("windows") else ""))
    yq_args = [
        repository_ctx.path(host_yq),
        "eval-all",
        yaml_path,
        "-o=json",
    ]
    result = repository_ctx.execute(yq_args)
    if result.return_code:
        return None, "failed to parse {} with yq. '{}' exited with {}: \nSTDOUT:\n{}\nSTDERR:\n{}".format(yq_args, yaml_path, result.return_code, result.stdout, result.stderr)

    # NB: yq will return the string "null" if the yaml file is empty
    if result.stdout != "null":
        return result.stdout, None

    return None, None

def download_gem(
        repository_ctx,
        gem,
        version,
        host_platform,
        root_dir,
        **kwargs):
    """ Download an arbitrary Ruby Gem """

    versioned_gem = "{gem}-{version}".format(gem = gem, version = version)

    tmp_extract_dir = root_dir.get_child("tmp-download-{versioned_gem}".format(versioned_gem = versioned_gem))
    base_url = kwargs.get("rubygem_url", DEFAULT_RUBYGEM_URL)
    if base_url.endswith("/"):
        base_url = base_url[:-1]  # Rubygems is really picky about not having `//` apparently?
    gem_url = base_url + "/{versioned_gem}.gem".format(versioned_gem = versioned_gem)
    gem_integrity = kwargs.get("gem_integrity", "")

    repository_ctx.report_progress("Fetching gem {url}".format(url = gem_url))
    unpack_top_level_result = repository_ctx.download_and_extract(
        url = gem_url,
        integrity = gem_integrity,
        output = tmp_extract_dir,
        # strip_prefix = "{prefix}-{version}".format(prefix = prefix, version = version) if prefix != None else None
        type = "tar",
    )

    if not unpack_top_level_result:
        fail("Failed to download {gem} v{version}".format(gem = gem, version = version))
        return

    gem_dir = root_dir.get_child(versioned_gem)
    repository_ctx.extract(
        archive = tmp_extract_dir.get_child("data.tar.gz"),
        output = gem_dir,
        # strip_prefix = None,
        # rename_files = None,
    )

    repository_ctx.extract(
        archive = tmp_extract_dir.get_child("metadata.gz"),
        output = tmp_extract_dir,
    )

    metadata_json, metadata_json_err = _yaml_to_json(repository_ctx, host_platform, tmp_extract_dir.get_child("metadata"))
    if metadata_json_err != None:
        fail("Failed to read Ruby gem {gem} metadata:\n{err}".format(gem = gem, err = metadata_json_err))
        return

    repository_ctx.report_progress("Checking for dependencies of gem {url}".format(url = gem_url))

    metadata = json.decode(metadata_json)
    has_executables = "bindir" in metadata and "executables" in metadata and len(metadata["executables"]) > 0

    gem_struct = struct(
        name = gem,
        version = version,
        gem_dir = versioned_gem,
        require_paths = metadata["require_paths"],
        bin_dir = metadata["bindir"] if has_executables else None,
        executables = metadata["executables"] if has_executables else None,
    )

    #     repository_ctx.delete(tmp_extract_dir)

    return gem_struct
