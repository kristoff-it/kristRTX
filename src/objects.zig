const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Ray = @import("Ray.zig");

pub const Hit = struct {
    p: Vec3,
    n: Vec3,
    t: f64,
    front_face: bool,

    pub fn init(t: f64, r: Ray, p: Vec3, outward_normal: Vec3) Hit {
        if (builtin.mode == .Debug) {
            // NOTE: the parameter `outward_normal` is assumed to have unit length.
            const one = vec.magnitude2(outward_normal);
            assert(std.math.approxEqAbs(f64, one, 1, 0.001));
        }

        const front_face = vec.dot(r.direction, outward_normal) < 0;
        return .{
            .t = t,
            .p = p,
            .n = if (front_face) outward_normal else -outward_normal,
            .front_face = front_face,
        };
    }
};

pub const Sphere = struct {
    radius: f64,
    center: Vec3,

    pub fn init(center: Vec3, radius: f64) Sphere {
        assert(radius >= 0);
        return .{ .center = center, .radius = radius };
    }

    pub fn hit(s: Sphere, r: Ray, ray_tmin: f64, ray_tmax: f64) ?Hit {
        const oc: Vec3 = s.center - r.origin;
        const a = vec.magnitude2(r.direction);
        const h = vec.dot(r.direction, oc);
        const c = vec.magnitude2(oc) - s.radius * s.radius;
        const discriminant = h * h - a * c;

        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (h - sqrtd) / a;
        if (root <= ray_tmin or ray_tmax <= root) {
            root = (h + sqrtd) / a;
            if (root <= ray_tmin or ray_tmax <= root)
                return null;
        }

        const p = r.at(root);
        const outward_normal = (p - s.center) / vec.splat(s.radius);
        return .init(root, r, p, outward_normal);
    }
};
