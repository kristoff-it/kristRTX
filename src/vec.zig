const std = @import("std");
const Writer = std.Io.Writer;
pub const Vec3 = @Vector(3, f64);

pub const zero: Vec3 = .{ 0, 0, 0 };
pub const one: Vec3 = .{ 1, 1, 1 };

pub fn x(v: Vec3) f64 {
    return v[0];
}
pub fn y(v: Vec3) f64 {
    return v[1];
}
pub fn z(v: Vec3) f64 {
    return v[2];
}

pub fn magnitude(v: Vec3) f64 {
    // const sqsum: f64 = v[0]*v[0] + v[1]*v[1] + v[2]*v[2];
    // return std.math.sqrt(sqsum);
    return @sqrt(magnitude2(v));
}
pub fn magnitude2(v: Vec3) f64 {
    return @reduce(.Add, v * v);
}

pub fn splat(n: anytype) Vec3 {
    switch (@TypeOf(n)) {
        usize, comptime_int => return @splat(@floatFromInt(n)),
        f64, comptime_float => return @splat(n),
        else => unreachable,
    }
}

pub const Fmt = std.fmt.Alt(Vec3, format);
fn format(v: Vec3, w: *Writer) !void {
    try w.print("{d} {d} {d}", .{ v[0], v[1], v[2] });
}

pub const Color = std.fmt.Alt(Vec3, colorFormat);
fn colorFormat(v: Vec3, w: *Writer) !void {
    const _x: u8 = @intFromFloat(v[0] * 255.999);
    const _y: u8 = @intFromFloat(v[1] * 255.999);
    const _z: u8 = @intFromFloat(v[2] * 255.999);
    try w.print("{d} {d} {d}\n", .{ _x, _y, _z });
}

pub fn dot(lhs: Vec3, rhs: Vec3) f64 {
    return @reduce(.Add, lhs * rhs);
}

pub fn cross(lhs: Vec3, rhs: Vec3) Vec3 {
    return .{
        lhs[1] * rhs[2] - lhs[2] * rhs[1],
        lhs[2] * rhs[0] - lhs[0] * rhs[2],
        lhs[0] * rhs[1] - lhs[1] * rhs[0],
    };
}

pub fn unit(v: Vec3) Vec3 {
    const mag = magnitude(v);
    if (mag == 0) return zero;

    const mag3: Vec3 = @splat(mag);
    return v / mag3;
}
