# Diagnostics Collectors

This package creates diagnostic files only from closed typed values. It does
not accept source paths, enumerate files, inspect installed applications, read
destinations or parse raw runtime configuration. Every output path is fixed by
the package and every profile has bounded event/crash input and byte limits.

The output is an in-memory virtual file set for `pokrov_support_bundle`. It is
not an export format and must never be attached or written as plaintext.
