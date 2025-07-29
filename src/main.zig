const std = @import("std");
const builtin = @import("builtin");
const Writer = std.Io.Writer;
const objects = @import("objects.zig");
const Material = objects.Material;
const Sphere = objects.Sphere;
const camera = @import("camera.zig");
const vec = @import("vec.zig");

pub fn main() !void {
    std.debug.print("mode = {t}\n", .{builtin.mode});

    var wbuf: [4096]u8 = undefined;
    var file_writer = std.fs.File.stdout().writer(&wbuf);
    const out = &file_writer.interface;

    const world = try world1();
    try camera.render(out, world);
}

fn world0() [5]Sphere {
    const ground: Material = .{
        .lambertian = .{ .albedo = .{ 0.5, 0.5, 0.5 } },
    };

    const center: Material = .{
        .lambertian = .{ .albedo = .{ 0.1, 0.2, 0.5 } },
    };

    const left: Material = .{
        .metal = .{ .albedo = .{ 0.8, 0.8, 0.8 }, .fuzz = 0.3 },
    };
    _ = left;

    const right: Material = .{
        .metal = .{ .albedo = .{ 0.8, 0.6, 0.2 }, .fuzz = 0 },
    };

    const bubble: Material = .{
        .dielectric = .{ .refraction_index = 1.0 / 1.5 },
    };
    const glass_left: Material = .{
        .dielectric = .{ .refraction_index = 1.5 },
    };

    const world = [5]Sphere{
        Sphere.init(.{ 0, -100.5, -1 }, 100, ground),
        Sphere.init(.{ 0, 0, -1.2 }, 0.5, center),
        Sphere.init(.{ -1, 0, -1 }, 0.5, glass_left),
        Sphere.init(.{ -1, 0, -1 }, 0.4, bubble),
        Sphere.init(.{ 1, 0, -1 }, 0.5, right),
    };

    return world;
}

const gpa = std.heap.smp_allocator;
fn world1() ![]objects.Sphere {
    const rand = camera.rand_state.random();
    var world: std.ArrayListUnmanaged(objects.Sphere) = .empty;

    const ground: Material = .{
        .lambertian = .{
            .albedo = .{
                std.math.pow(f64, 247.0 / 255.0, 2),
                std.math.pow(f64, 164.0 / 255.0, 2),
                std.math.pow(f64, 29.0 / 255.0, 2),
            },
        },
    };

    try world.append(gpa, .{
        .center = .{ 0, -1000, 0 },
        .radius = 1000,
        .material = ground,
    });

    for (0..22) |x| {
        const a: f64 = @as(f64, @floatFromInt(x)) - 11.0;
        for (0..22) |y| {
            const b: f64 = @as(f64, @floatFromInt(y)) - 11.0;

            const choose_material = rand.float(f32);
            const center: vec.Vec3 = .{
                a + 0.9 * rand.float(f64),
                0.2,
                b + 0.9 * rand.float(f64),
            };

            const p = center - vec.Vec3{ 4, 0.2, 0 };
            if (vec.magnitude(p) > 0.9) {
                const material: objects.Material = if (choose_material < 0.8)
                    .{
                        .lambertian = .{
                            .albedo = vec.random(rand) * vec.random(rand),
                        },
                    }
                else if (choose_material < 0.95) .{
                    .metal = .{
                        .albedo = vec.randomRange(rand, 0.5, 1),
                        .fuzz = rand.float(f64) / 2,
                    },
                } else .{
                    .dielectric = .{
                        .refraction_index = 1.5,
                    },
                };

                try world.append(gpa, .{
                    .center = center,
                    .radius = 0.2,
                    .material = material,
                });
            }
        }
    }

    try world.appendSlice(gpa, &.{
        .{
            .center = .{ 0, 1, 0 },
            .radius = 1,
            .material = .{
                .dielectric = .{
                    .refraction_index = 1.5,
                },
            },
        },
        .{
            .center = .{ -4, 1, 0 },
            .radius = 1,
            .material = .{
                .lambertian = .{
                    .albedo = .{ 0.4, 0.2, 0.1 },
                },
            },
        },
        .{
            .center = .{ 4, 1, 0 },
            .radius = 1,
            .material = .{
                .metal = .{
                    .albedo = .{ 0.7, 0.6, 0.5 },
                    .fuzz = 0,
                },
            },
        },
    });

    return world.items;
}
// auto material1 = make_shared<dielectric>(1.5);
// world.add(make_shared<sphere>(point3(0, 1, 0), 1.0, material1));

// auto material2 = make_shared<lambertian>(color(0.4, 0.2, 0.1));
// world.add(make_shared<sphere>(point3(-4, 1, 0), 1.0, material2));

// auto material3 = make_shared<metal>(color(0.7, 0.6, 0.5), 0.0);
// world.add(make_shared<sphere>(point3(4, 1, 0), 1.0, material3));}
