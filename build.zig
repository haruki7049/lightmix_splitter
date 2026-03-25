const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,

        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    const wave = try l.addWave(b, mod, .{
        .wave = .{ .bits = 16, .format_code = .pcm },
    });
    l.installWave(b, wave);

    const play = try l.addPlay(b, wave, .{ .optimize = optimize });
    const play_step = b.step("play", "Play the emitted Wavefile");
    play_step.dependOn(&play.step);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
