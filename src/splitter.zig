const std = @import("std");
const lightmix = @import("lightmix");

pub fn gen(comptime T: type, arguments: Arguments(T)) anyerror!lightmix.Wave(T) {
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

/// Returns a number of samples per beat
fn samples_per_beat(
    /// BPM
    bpm: usize,
    /// Sample rate
    spl: u32,
) usize {
    return @intFromFloat(@as(f32, @floatFromInt(60)) / @as(f32, @floatFromInt(bpm)) * @as(f32, @floatFromInt(spl)));
}
