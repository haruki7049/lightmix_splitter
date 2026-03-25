const std = @import("std");
const lightmix = @import("lightmix");
const lightmix_synths = @import("lightmix_synths");
const lightmix_filters = @import("lightmix_filters");

const SamplingType = f64;
const sample_rate = 44100;
const channels = 1;

pub fn gen(allocator: std.mem.Allocator) anyerror!lightmix.Wave(SamplingType) {
    // A number of samples per beat
    const spb = samples_per_beat(120, sample_rate);

    var waves: [16]?lightmix.Wave(SamplingType) = undefined;
    for (waves, 0..) |_, i| {
        const is_timing = i % 4 == 0 or i % 4 == 2 or i % 4 == 3;

        if (is_timing) {
            var w: lightmix.Wave(SamplingType) = try lightmix_synths.Basic.Sine.gen(SamplingType, .{
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

    const result: lightmix.Wave(f64) = try splitter_gen(SamplingType, .{
        .allocator = allocator,
        .amplitude = 1.0,
        .length = spb * 8,
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

pub fn splitter_gen(comptime T: type, arguments: Arguments(T)) anyerror!lightmix.Wave(T) {
    var composer = lightmix.Composer(T).init(arguments.allocator, .{
        .channels = arguments.channels,
        .sample_rate = arguments.sample_rate,
    });
    defer composer.deinit();

    // Get a interval for each Wave
    const interval: usize = arguments.length / arguments.waves.len;

    // Creates a soundless Wave to creates a sustain for composed wave data
    const soundless_data = try arguments.allocator.alloc(T, arguments.length);
    defer arguments.allocator.free(soundless_data);
    const soundless = try lightmix.Wave(T).init(soundless_data, arguments.allocator, .{
        .sample_rate = arguments.sample_rate,
        .channels = arguments.channels,
    });
    defer soundless.deinit();
    try composer.append(.{ .wave = soundless, .start_point = 0 });

    // Adds each wave to the `var composer`
    var intervals: usize = 0;
    for (arguments.waves) |wave| {
        if (wave != null) {
            try composer.append(.{ .wave = wave.?, .start_point = intervals });
        }

        intervals += interval;
    }

    // Finalize
    const result: lightmix.Wave(T) = try composer.finalize(.{});
    return result;
}

pub fn Arguments(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        amplitude: f32,
        length: usize,
        waves: []const ?lightmix.Wave(T),
        sample_rate: u32,
        channels: u16,
    };
}
