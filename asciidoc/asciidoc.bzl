#
# asciidoc.bzl - Collection of all ASCIIDoc rules
#
""" ASCIIDoc Rules """

load("//asciidoc/private:asciidoc_document.bzl", _asciidoc_document = "asciidoc_document")
load("//asciidoc/private:asciidoc_toolchain.bzl", _asciidoc_toolchain = "asciidoc_toolchain")

asciidoc_document = _asciidoc_document
asciidoc_toolchain = _asciidoc_toolchain
