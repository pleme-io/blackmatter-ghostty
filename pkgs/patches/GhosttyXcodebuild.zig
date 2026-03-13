/// Patched for blackmatter-ghostty: pass through env vars needed for Nix
/// daemon builds where HOME=/var/empty (read-only). Sets CFFIXED_USER_HOME
/// to redirect NSHomeDirectory() to a writable temp directory. Adds vendored
/// Sparkle framework search path (SPM removed from project to avoid sandbox-exec).
const Ghostty = @This();

const std = @import("std");
const builtin = @import("builtin");
const RunStep = std.Build.Step.Run;
const Config = @import("Config.zig");
const Docs = @import("GhosttyDocs.zig");
const I18n = @import("GhosttyI18n.zig");
const Resources = @import("GhosttyResources.zig");
const XCFramework = @import("GhosttyXCFramework.zig");

build: *std.Build.Step.Run,
open: *std.Build.Step.Run,
copy: *std.Build.Step.Run,
xctest: *std.Build.Step.Run,

pub const Deps = struct {
    xcframework: *const XCFramework,
    docs: *const Docs,
    i18n: ?*const I18n,
    resources: *const Resources,
};

fn setupXcodebuildEnv(env: std.process.EnvMap, allocator: std.mem.Allocator) !*std.process.EnvMap {
    // External environment variables can mess up xcodebuild, so
    // we create a new empty environment with only what's needed.
    const env_map = try allocator.create(std.process.EnvMap);
    env_map.* = .init(allocator);
    if (env.get("PATH")) |v| try env_map.put("PATH", v);
    if (env.get("DEVELOPER_DIR")) |v| try env_map.put("DEVELOPER_DIR", v);
    if (env.get("TMPDIR")) |v| try env_map.put("TMPDIR", v);

    // CFFIXED_USER_HOME overrides NSHomeDirectory(). The Nix daemon user's
    // home is /var/empty (read-only), but xcodebuild needs to write to
    // ~/Library/Developer/Xcode/DerivedData, ~/Library/Caches/org.swift.swiftpm, etc.
    if (env.get("HOME")) |v| {
        try env_map.put("HOME", v);
        try env_map.put("CFFIXED_USER_HOME", v);
    }

    return env_map;
}

pub fn init(
    b: *std.Build,
    config: *const Config,
    deps: Deps,
) !Ghostty {
    const xc_config = switch (config.optimize) {
        .Debug => "Debug",
        .ReleaseSafe,
        .ReleaseSmall,
        .ReleaseFast,
        => "ReleaseLocal",
    };

    const xc_arch: ?[]const u8 = switch (deps.xcframework.target) {
        .universal => null,
        .native => switch (builtin.cpu.arch) {
            .aarch64 => "arm64",
            .x86_64 => "x86_64",
            else => @panic("unsupported macOS arch"),
        },
    };

    const env = try std.process.getEnvMap(b.allocator);
    const app_path = b.fmt("macos/build/{s}/Ghostty.app", .{xc_config});

    // Vendored Sparkle framework path (set by Nix buildPhaseOverride).
    // SPM references were stripped from project.pbxproj to avoid sandbox-exec.
    // We provide Sparkle via FRAMEWORK_SEARCH_PATHS build setting instead.
    const sparkle_path = env.get("GHOSTTY_SPARKLE_PATH");

    // Our step to build the Ghostty macOS app.
    const build = build: {
        const env_map = try setupXcodebuildEnv(env, b.allocator);

        const step = RunStep.create(b, "xcodebuild");
        step.has_side_effects = true;
        step.cwd = b.path("macos");
        step.env_map = env_map;
        step.addArgs(&.{
            "xcodebuild",
            "-target",
            "Ghostty",
            "-configuration",
            xc_config,
        });

        if (xc_arch) |arch| step.addArgs(&.{ "-arch", arch });


        // Add vendored Sparkle framework search path so the compiler
        // and linker can find Sparkle.framework without SPM resolution.
        if (sparkle_path) |path| {
            step.addArgs(&.{
                b.fmt("FRAMEWORK_SEARCH_PATHS=$(inherited) {s}", .{path}),
            });
        }

        deps.xcframework.addStepDependencies(&step.step);
        deps.resources.addStepDependencies(&step.step);
        if (deps.i18n) |v| v.addStepDependencies(&step.step);
        deps.docs.installDummy(&step.step);

        // Don't use expectExitCode — it switches stdio to .check mode
        // which captures stderr, hiding Swift/xcodebuild errors.
        // has_side_effects=true keeps stdio in .inherit mode so errors
        // are visible in the build log. The build still fails on non-zero exit.

        break :build step;
    };

    const xctest = xctest: {
        const env_map = try setupXcodebuildEnv(env, b.allocator);

        const step = RunStep.create(b, "xcodebuild test");
        step.has_side_effects = true;
        step.cwd = b.path("macos");
        step.env_map = env_map;
        step.addArgs(&.{
            "xcodebuild",
            "test",
            "-scheme",
            "Ghostty",
        });
        if (xc_arch) |arch| step.addArgs(&.{ "-arch", arch });

        deps.xcframework.addStepDependencies(&step.step);
        deps.resources.addStepDependencies(&step.step);
        if (deps.i18n) |v| v.addStepDependencies(&step.step);
        deps.docs.installDummy(&step.step);

        step.expectExitCode(0);

        break :xctest step;
    };

    const open = open: {
        const disable_save_state = RunStep.create(b, "disable save state");
        disable_save_state.has_side_effects = true;
        disable_save_state.addArgs(&.{
            "/usr/libexec/PlistBuddy",
            "-c",
            "Add :NSQuitAlwaysKeepsWindows bool false",
            b.fmt("{s}/Contents/Info.plist", .{app_path}),
        });
        disable_save_state.expectExitCode(0);
        disable_save_state.step.dependOn(&build.step);

        const open = RunStep.create(b, "run Ghostty app");
        open.has_side_effects = true;
        open.cwd = b.path("");
        open.addArgs(&.{b.fmt(
            "{s}/Contents/MacOS/ghostty",
            .{app_path},
        )});

        open.step.dependOn(&build.step);
        open.step.dependOn(&disable_save_state.step);

        open.setEnvironmentVariable("GHOSTTY_LOG", "stderr,macos");
        open.setEnvironmentVariable("GHOSTTY_MAC_LAUNCH_SOURCE", "zig_run");

        if (b.args) |args| {
            open.addArgs(args);
        }

        break :open open;
    };

    const copy = copy: {
        const step = RunStep.create(b, "copy app bundle");
        step.addArgs(&.{ "cp", "-R" });
        step.addFileArg(b.path(app_path));
        step.addArg(b.fmt("{s}", .{b.install_path}));
        step.step.dependOn(&build.step);
        break :copy step;
    };

    return .{
        .build = build,
        .open = open,
        .copy = copy,
        .xctest = xctest,
    };
}

pub fn install(self: *const Ghostty) void {
    const b = self.copy.step.owner;
    b.getInstallStep().dependOn(&self.copy.step);
}

pub fn installXcframework(self: *const Ghostty) void {
    const b = self.build.step.owner;
    b.getInstallStep().dependOn(&self.build.step);
}

pub fn addTestStepDependencies(
    self: *const Ghostty,
    other_step: *std.Build.Step,
) void {
    other_step.dependOn(&self.xctest.step);
}
