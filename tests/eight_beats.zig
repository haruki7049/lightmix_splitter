const std = @import("std");
const lightmix = @import("lightmix");
const lightmix_filters = @import("lightmix_filters");
const lightmix_splitter = @import("lightmix_splitter");
const lightmix_synths = @import("lightmix_synths");

const Splitter = lightmix_splitter.Splitter;
const sample_rate = 44100;
const channels = 1;

test {
    const allocator = std.testing.allocator;

    // Create a TmpDir
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // PCM
    {
        const samples_types = &.{ f64, f80, f128 };
        const bits = &.{ 16, 24, 32 };

        inline for (samples_types) |S| {
            inline for (bits) |b| {
                const b_str = std.fmt.comptimePrint("{d}", .{b});
                const filename = "test-eight-beat-" ++ @typeName(S) ++ "-" ++ b_str ++ "bit-pcm.wav";

                // Create a lightmix.Wave(S)
                const wave = try gen(S, allocator);
                defer wave.deinit();

                const bytes_per_sample = (b + 7) / 8;
                const header_size = 44;
                const total_size = header_size + (wave.samples.len * wave.channels * bytes_per_sample);
                const file = try tmp.dir.createFile(filename, .{});
                defer file.close();
                const buf = try allocator.alloc(u8, total_size);
                defer allocator.free(buf);

                var writer = file.writer(buf);
                try wave.write(&writer.interface, .{
                    .allocator = allocator,
                    .format_code = .pcm,
                    .bits = b,
                });
                try writer.interface.flush();
            }
        }
    }

    // IEEE Float
    {
        const samples_types = &.{ f64, f80, f128 };
        const bits = &.{ 32, 64 };

        inline for (samples_types) |S| {
            inline for (bits) |b| {
                const b_str = std.fmt.comptimePrint("{d}", .{b});
                const filename = "test-eight-beat-" ++ @typeName(S) ++ "-" ++ b_str ++ "bit-ieee-float.wav";

                // Create a lightmix.Wave(S)
                const wave = try gen(S, allocator);
                defer wave.deinit();

                const bytes_per_sample = (b + 7) / 8;
                const header_size = 44;
                const total_size = header_size + (wave.samples.len * wave.channels * bytes_per_sample);
                const file = try tmp.dir.createFile(filename, .{});
                const buf = try allocator.alloc(u8, total_size);
                defer allocator.free(buf);

                var writer = file.writer(buf);
                try wave.write(&writer.interface, .{
                    .allocator = allocator,
                    .format_code = .ieee_float,
                    .bits = b,
                });
                try writer.interface.flush();
            }
        }
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
