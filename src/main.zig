const std = @import("std");
const Writer = std.Io.Writer;
const Progress = std.Progress;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Ray = @import("Ray.zig");
const objects = @import("objects.zig");
const Hit = objects.Hit;
const Sphere = objects.Sphere;

const aspect_ratio = 16.0 / 9.0;
const img_width = 400;
const img_height = blk: {
    const h: comptime_int = @intFromFloat((img_width - 0.0) / aspect_ratio);
    if (h < 1) break :blk 1;
    break :blk h;
};

const focal_length = 1.0;
const viewport_height = 2.0;
const viewport_width = viewport_height * (img_width + 0.0) / (img_height - 0.0);
const camera_center: Vec3 = vec.zero;

// Calculate the vectors across the horizontal and down the vertical viewport edges
const viewport_u: Vec3 = .{ viewport_width, 0, 0 };
const viewport_v: Vec3 = .{ 0, -viewport_height, 0 };

// Calculate the horizontal and vertical delta vectors from pixel to pixel.
const pixel_delta_u: Vec3 = viewport_u / vec.splat(img_width);
const pixel_delta_v: Vec3 = viewport_v / vec.splat(img_height);

// Calculate the location of the upper left pixel.
const viewport_upper_left: Vec3 = blk: {
    const vu_half = viewport_u / vec.splat(2);
    const vv_half = viewport_v / vec.splat(2);
    const focal3: Vec3 = .{ 0, 0, focal_length };
    break :blk camera_center - focal3 - vu_half - vv_half;
};
const pixel00_loc = viewport_upper_left +
    (vec.splat(0.5) * (pixel_delta_u + pixel_delta_v));

pub fn main() !void {
    var wbuf: [4096]u8 = undefined;
    var file_writer = std.fs.File.stdout().writer(&wbuf);
    const out = &file_writer.interface;

    var pbuf: [1024]u8 = undefined;
    const pr = Progress.start(.{
        .draw_buffer = &pbuf,
        .estimated_total_items = img_height * img_width,
        .root_name = "raytracing",
    });
    defer pr.end();

    try out.print("P3\n{d} {d}\n255\n", .{ img_width, img_height });

    const world = .{
        Sphere.init(.{ 0, 0, -1 }, 0.5),
        Sphere.init(.{ 0, -100.5, -1 }, 100),
    };

    for (0..img_height) |h| {
        for (0..img_width) |w| {
            const pixel_center = pixel00_loc +
                (vec.splat(w) * pixel_delta_u) + (vec.splat(h) * pixel_delta_v);

            const ray_direction = pixel_center - camera_center;
            const r: Ray = .init(camera_center, ray_direction);

            const pixel: Vec3 = rayColor(r, world);
            try out.print("{f}", .{vec.Color{ .data = pixel }});
        }
    }
    try out.flush();
}

fn rayColor(r: Ray, world: anytype) Vec3 {
    if (hitEverything(world, r)) |hit| {
        return vec.splat(0.5) * (hit.n + vec.one);
    }

    const unit_dir = vec.unit(r.direction);
    const a = 0.5 * (vec.y(unit_dir) + 1.0);
    const wat: Vec3 = .{ 0.5, 0.7, 1.0 };
    return vec.splat(1.0 - a) * vec.one + vec.splat(a) * wat;
}

fn hitEverything(objs: anytype, r: Ray) ?Hit {
    var hit: ?Hit = null;
    var closest_so_far = std.math.inf(f64);
    inline for (objs) |obj| {
        if (obj.hit(r, 0, closest_so_far)) |h| {
            hit = h;
            closest_so_far = hit.?.t;
        }
    }
    return hit;
}
