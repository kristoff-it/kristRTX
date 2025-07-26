const Ray = @This();
const std = @import("std");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;

origin: Vec3,
direction: Vec3,

pub fn init(origin: Vec3, dir: Vec3) Ray {
    return .{ .origin = origin, .direction = dir };
}

pub fn at(r: Ray, t: f64) Vec3 {
    // const t3: Vec3 = @splat(t);
    // return r.origin + t3 * r.direction;
    return @mulAdd(Vec3, @splat(t), r.direction, r.origin);
}
