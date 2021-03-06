load("@bazel_skylib//lib:shell.bzl", "shell")

def _buildifier_impl(ctx):
    # Do not depend on defaults encoded in the binary.  Always use defaults set
    # on attributes of the rule.
    args = [
        "-mode=%s" % ctx.attr.mode,
        "-v=%s" % str(ctx.attr.verbose).lower(),
    ]

    if ctx.attr.lint_mode:
        args.append("-lint=%s" % ctx.attr.lint_mode)
    if ctx.attr.lint_warnings:
        if not ctx.attr.lint_mode:
            fail("Cannot pass 'lint_warnings' without a 'lint_mode'")
        args.append("--warnings={}".format(",".join(ctx.attr.lint_warnings)))
    if ctx.attr.multi_diff:
        args.append("-multi_diff")
    if ctx.attr.diff_command:
        args.append("-diff_command=%s" % ctx.attr.diff_command)
    if ctx.attr.add_tables:
        args.append("-add_tables=%s" % ctx.file.add_tables.path)

    exclude_patterns_str = ""
    if ctx.attr.exclude_patterns:
        exclude_patterns = ["\\! -path %s" % shell.quote(pattern) for pattern in ctx.attr.exclude_patterns]
        exclude_patterns_str = " ".join(exclude_patterns)

    os_extension = str(ctx.file.runner).split('.')[1].split('.')[0]
    out_file = ctx.actions.declare_file(ctx.label.name + ".{}".format(os_extension))
    substitutions = {
        "@@ARGS@@": shell.array_literal(args),
        "@@BUILDIFIER_SHORT_PATH@@": shell.quote(ctx.executable._buildifier.short_path),
        "@@EXCLUDE_PATTERNS@@": exclude_patterns_str,
    }
    ctx.actions.expand_template(
        template = ctx.file.runner,
        output = out_file,
        substitutions = substitutions,
        is_executable = True,
    )
    runfiles = ctx.runfiles(files = [ctx.executable._buildifier])
    return [DefaultInfo(
        files = depset([out_file]),
        runfiles = runfiles,
        executable = out_file,
    )]

_buildifier = rule(
    implementation = _buildifier_impl,
    attrs = {
        "verbose": attr.bool(
            doc = "Print verbose information on standard error",
        ),
        "mode": attr.string(
            default = "fix",
            doc = "Formatting mode",
            values = ["check", "diff", "fix", "print_if_changed"],
        ),
        "lint_mode": attr.string(
            doc = "Linting mode",
            values = ["", "fix", "warn"],
        ),
        "lint_warnings": attr.string_list(
            allow_empty = True,
            doc = "all prefixed with +/- if you want to include in or exclude from the default set of warnings, or none prefixed with +/- if you want to override the default set, or 'all' for all avaliable warnings",
        ),
        "exclude_patterns": attr.string_list(
            allow_empty = True,
            doc = "A list of glob patterns passed to the find command. E.g. './vendor/*' to exclude the Go vendor directory",
        ),
        "diff_command": attr.string(
            doc = "Command to use to show diff, with mode=diff. E.g. 'diff -u'",
        ),
        "multi_diff": attr.bool(
            default = False,
            doc = "Set to True if the diff command specified by the 'diff_command' can diff multiple files in the style of 'tkdiff'",
        ),
        "add_tables": attr.label(
            mandatory = False,
            doc = "path to JSON file with custom table definitions which will be merged with the built-in tables",
            allow_single_file = True,
        ),
        "runner": attr.label(
            default = "@com_github_bazelbuild_buildtools//buildifier:runner.bash.template",
            allow_single_file = True,
        ),
        "_buildifier": attr.label(
            default = "@com_github_bazelbuild_buildtools//buildifier",
            cfg = "host",
            executable = True,
        ),
    },
    executable = True,
)

def buildifier(**kwargs):
    tags = kwargs.get("tags", [])
    if "manual" not in tags:
        tags.append("manual")
        kwargs["tags"] = tags
    _buildifier(**kwargs)
