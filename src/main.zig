const std = @import("std");
const builtin = @import("builtin");
const Writer = std.Io.Writer;
const objects = @import("objects.zig");
const Material = objects.Material;
const Sphere = objects.Sphere;
const camera = @import("camera.zig");

pub fn main() !void {
    std.debug.print("mode = {t}\n", .{builtin.mode});

    var wbuf: [4096]u8 = undefined;
    var file_writer = std.fs.File.stdout().writer(&wbuf);
    const out = &file_writer.interface;

    const ground: Material = .{
        .lambertian = .{ .albedo = .{ 0.8, 0.8, 0 } },
    };

    const center: Material = .{
        .lambertian = .{ .albedo = .{ 0.1, 0.2, 0.5 } },
    };

    const left: Material = .{
        .metal = .{ .albedo = .{ 0.8, 0.8, 0.8 }, .fuzz = 0.3 },
    };
    _ = left;

    const right: Material = .{
        .metal = .{ .albedo = .{ 0.8, 0.6, 0.2 }, .fuzz = 1 },
    };

    const bubble: Material = .{
        .dielectric = .{ .refraction_index = 1.0 / 1.5 },
    };
    const glass_left: Material = .{
        .dielectric = .{ .refraction_index = 1.5 },
    };

    const world = .{
        Sphere.init(.{ 0, -100.5, -1 }, 100, ground),
        Sphere.init(.{ 0, 0, -1.2 }, 0.5, center),
        Sphere.init(.{ -1, 0, -1 }, 0.5, glass_left),
        Sphere.init(.{ -1, 0, -1 }, 0.4, bubble),
        Sphere.init(.{ 1, 0, -1 }, 0.5, right),
    };

    try camera.render(out, world);
}
