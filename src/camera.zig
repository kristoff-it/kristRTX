const std = @import("std");
const Progress = std.Progress;
const Writer = std.Io.Writer;
const Ray = @import("Ray.zig");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const objects = @import("objects.zig");
const Hit = objects.Hit;

pub const aspect_ratio = 16.0 / 9.0;
pub const img_width = 1920;
pub const samples_per_pixel = 500;
const max_recursion = 50; // lol(lol)

const img_height = blk: {
    const h: comptime_int = @intFromFloat((img_width - 0.0) / aspect_ratio);
    if (h < 1) break :blk 1;
    break :blk h;
};

const vfov = 90.0;
const look_from: Vec3 = .{ -2, 2, 1 };
const look_at: Vec3 = .{ 0, 0, -1 };
const vup: Vec3 = .{ 0, 1, 0 };
const defocus_angle = 0.6;
const focus_distance = 10;
const viewport_height = blk: {
    const theta = std.math.degreesToRadians(vfov);
    const h = std.math.tan(theta / 2.0);
    break :blk 2 * h * focus_distance;
};
const viewport_width = viewport_height * (img_width + 0.0) / (img_height - 0.0);
const camera_center: Vec3 = look_from;

// Calculate the vectors across the horizontal and down the vertical viewport edges
const viewport_u: Vec3 = vec.splat(viewport_width) * u_vec;
const viewport_v: Vec3 = vec.splat(viewport_height) * -v_vec;

const w_vec = vec.unit(look_from - look_at);
const u_vec = vec.unit(vec.cross(vup, w_vec));
const v_vec = vec.cross(w_vec, u_vec);

// Calculate the horizontal and vertical delta vectors from pixel to pixel.
const pixel_delta_u: Vec3 = viewport_u / vec.splat(img_width);
const pixel_delta_v: Vec3 = viewport_v / vec.splat(img_height);

// Calculate the location of the upper left pixel.
const viewport_upper_left: Vec3 = blk: {
    const vu_half = viewport_u / vec.splat(2);
    const vv_half = viewport_v / vec.splat(2);
    const focal = vec.splat(focus_distance) * w_vec;
    break :blk camera_center - focal - vu_half - vv_half;
};
const pixel00_loc = viewport_upper_left +
    (vec.splat(0.5) * (pixel_delta_u + pixel_delta_v));

const defocus_radius = focus_distance * std.math.tan(
    std.math.degreesToRadians(defocus_angle / 2.0),
);
const defocus_disk_u = u_vec * vec.splat(defocus_radius);
const defocus_disk_v = v_vec * vec.splat(defocus_radius);

pub fn render(out: *Writer, world: []const objects.Sphere) !void {
    var pbuf: [1024]u8 = undefined;
    const pr = Progress.start(.{
        .draw_buffer = &pbuf,
        .estimated_total_items = img_height,
        .root_name = "raytracing",
    });
    defer pr.end();

    const gpa = std.heap.smp_allocator;

    var out_buf: [][3]u8 = try gpa.alloc([3]u8, img_width * img_height);
    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = gpa });

    var wg: std.Thread.WaitGroup = .{};

    try out.print("P6\n{d} {d}\n255\n", .{ img_width, img_height });
    for (0..img_height) |h| {
        pool.spawnWg(&wg, computeRow, .{
            h,
            world,
            out_buf[h * img_width ..][0..img_width],
            pr,
        });
    }

    pool.waitAndWork(&wg);

    try out.writeSliceEndian(u8, std.mem.sliceAsBytes(out_buf), .little);
    try out.flush();
}

fn computeRow(h: usize, world: anytype, out: [][3]u8, pr: Progress.Node) void {
    defer pr.completeOne();

    for (0..img_width) |w| {
        var pixel: Vec3 = vec.zero;

        for (0..samples_per_pixel) |_| {
            const r = getRay(@floatFromInt(w), @floatFromInt(h));
            pixel += rayColor(r, 0, world);
        }

        pixel /= vec.splat(samples_per_pixel);

        const x: u8 = @intFromFloat(vec.toGamma(pixel[0]) * 255.999);
        const y: u8 = @intFromFloat(vec.toGamma(pixel[1]) * 255.999);
        const z: u8 = @intFromFloat(vec.toGamma(pixel[2]) * 255.999);
        out[w] = .{ x, y, z };
    }
}

fn getRay(w: f64, h: f64) Ray {
    @setFloatMode(.optimized);
    const offset = sampleSquare();
    const pixel_sample = pixel00_loc +
        (vec.splat(w + vec.x(offset)) * pixel_delta_u) +
        (vec.splat(h + vec.y(offset)) * pixel_delta_v);
    // const pixel_sample: Vec3 = @mulAdd(
    //     Vec3,
    //     vec.splat(h + offset[1]),
    //     pixel_delta_v,
    //     @mulAdd(
    //         Vec3,
    //         vec.splat(w + offset[0]),
    //         pixel_delta_u,
    //         pixel00_loc,
    //     ),
    // );
    //
    const origin = if (defocus_angle <= 0) camera_center else defocusDiskSample();

    const direction = pixel_sample - origin;
    return .init(origin, direction);
}

fn defocusDiskSample() Vec3 {
    // Returns a random point in the camera defocus disk.
    const rand = rand_state.random();
    const p = vec.randomUnitDisk(rand);
    return camera_center +
        (vec.splat(p[0]) * defocus_disk_u) +
        (vec.splat(p[1]) * defocus_disk_v);
    // return @mulAdd(
    //     Vec3,
    //     p,
    //     .{ defocus_disk_u, defocus_disk_v, 0 },
    //     @splat(camera_center),
    // );
}

pub threadlocal var rand_state = std.Random.DefaultPrng.init(42);

fn sampleSquare() Vec3 {
    const rand = rand_state.random();
    return .{
        rand.float(f64) - 0.5,
        rand.float(f64) - 0.5,
        0,
    };
}

fn rayColor(r: Ray, lvl: usize, world: anytype) Vec3 {
    @setFloatMode(.optimized);
    if (lvl == max_recursion) return vec.zero;

    const rand = rand_state.random();

    if (hitEverything(world, r)) |hit| {
        const scatter = hit.scatter(rand, r) orelse return vec.zero;
        return scatter.attenuation * rayColor(scatter.ray, lvl + 1, world);
    }

    const unit_dir = vec.unit(r.direction);
    const a = 0.5 * (vec.y(unit_dir) + 1.0);
    const sky: Vec3 = .{ 0.5, 0.7, 1.0 };
    return vec.splat(1.0 - a) * vec.one + vec.splat(a) * sky;
}

fn hitEverything(objs: anytype, r: Ray) ?Hit {
    var hit: ?Hit = null;
    var closest_so_far = std.math.inf(f64);
    for (objs) |obj| {
        if (obj.hit(r, .{ .min = 0.001, .max = closest_so_far })) |h| {
            hit = h;
            closest_so_far = hit.?.t;
        }
    }
    return hit;
}
