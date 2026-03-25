const std = @import("std");
const lightmix = @import("lightmix");
const lightmix_synths = @import("lightmix_synths");
const lightmix_filters = @import("lightmix_filters");

const Splitter = @import("./splitter.zig");
const sample_rate = 44100;
const channels = 1;

test {
    const types = &.{f64};

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak)
            @panic("Memory leak happened");
    }

    for (types) |T| {
        const wave = try gen(T, allocator);
        defer wave.deinit();
    }
}

fn gen(comptime T: type, allocator: std.mem.Allocator) anyerror!lightmix.Wave(T) {
    // A number of samples per beat
    const spb = samples_per_beat(120, sample_rate);

    var waves: [16]?lightmix.Wave(T) = undefined;
    for (waves, 0..) |_, i| {
        const is_timing = i % 2 == 0;

        if (is_timing) {
            var w: lightmix.Wave(T) = try lightmix_synths.Basic.Sine.gen(T, .{
                .allocator = allocator,
                .amplitude = 1.0,
                .frequency = 220.0,
                .length = spb,
                .sample_rate = sample_rate,
                .channels = channels,
            });
            try w.filter_with(lightmix_filters.volume.DecayArgs, lightmix_filters.volume.decay, .{});
            try w.filter_with(lightmix_filters.volume.DecayArgs, lightmix_filters.volume.decay, .{});
            try w.filter_with(lightmix_filters.volume.DecayArgs, lightmix_filters.volume.decay, .{});
            try w.filter_with(lightmix_filters.volume.DecayArgs, lightmix_filters.volume.decay, .{});

            waves[i] = w;
        } else {
            waves[i] = null;
        }
    }
    defer for (waves) |wave| {
        if (wave != null) {
            wave.?.deinit();
        }
    };

    const result: lightmix.Wave(T) = try Splitter.gen(T, .{
        .allocator = allocator,
        .amplitude = 1.0,
        .length = spb * 8,
        .takes = 16,
        .waves = &waves,
        .sample_rate = sample_rate,
        .channels = channels,
    });
    return result;
}

/// Returns a number of samples per beat
pub fn samples_per_beat(
    /// BPM
    bpm: usize,
    /// Sample rate
    spl: u32,
) usize {
    return @intFromFloat(@as(f32, @floatFromInt(60)) / @as(f32, @floatFromInt(bpm)) * @as(f32, @floatFromInt(spl)));
}
