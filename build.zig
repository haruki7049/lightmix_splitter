const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});
    const lightmix_filters = b.dependency("lightmix_filters", .{});
    const lightmix_synths = b.dependency("lightmix_synths", .{});

    // Mod
    const mod = b.addModule("lightmix_splitter", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,

        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    // Lib
    const lib = b.addLibrary(.{
        .name = "lightmix_splitter",
        .root_module = mod,
    });
    b.installArtifact(lib);

    // Example
    try build_example_program(b, .{
        .root_source_file = b.path("examples/eight_beat.zig"),
        .target = target,
        .optimize = optimize,
        .lightmix_splitter = mod,

        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
            .{ .name = "lightmix_filters", .module = lightmix_filters.module("lightmix_filters") },
            .{ .name = "lightmix_splitter", .module = mod },
            .{ .name = "lightmix_synths", .module = lightmix_synths.module("lightmix_synths") },
        },
    });

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    // "tests/eight_beats.zig"
    const eight_beats_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/eight_beats.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lightmix", .module = lightmix.module("lightmix") },
                .{ .name = "lightmix_filters", .module = lightmix_filters.module("lightmix_filters") },
                .{ .name = "lightmix_splitter", .module = mod },
                .{ .name = "lightmix_synths", .module = lightmix_synths.module("lightmix_synths") },
            },
        }),
    });
    const run_eight_beats_tests = b.addRunArtifact(eight_beats_tests);
    test_step.dependOn(&run_eight_beats_tests.step);
}

fn build_example_program(b: *std.Build, args: BuildExampleProgramArgs) !void {
    const example = b.createModule(.{
        .root_source_file = args.root_source_file,
        .target = args.target,
        .optimize = args.optimize,
        .imports = args.imports,
    });

    const wave = try l.addWave(b, example, .{
        .wave = .{ .bits = 16, .format_code = .pcm },
    });
    const example_step = b.step("example", "Build example wave");
    example_step.dependOn(wave.step);

    const play = try l.addPlay(b, wave, .{ .optimize = args.optimize });
    const play_step = b.step("play", "Play the emitted Wavefile");
    play_step.dependOn(&play.step);
}

const BuildExampleProgramArgs = struct {
    root_source_file: std.Build.LazyPath,
    target: ?std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lightmix_splitter: *std.Build.Module,
    imports: []const std.Build.Module.Import,
};
