load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _repeatable_string_flag_impl(ctx):
    return BuildSettingInfo(value = ctx.build_setting_value)

repeatable_string_flag = rule(
    build_setting = config.string_list(
        flag = True,
        repeatable = True,
    ),
    implementation = _repeatable_string_flag_impl,
)
