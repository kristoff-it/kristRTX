const std = @import("std");
const Random = std.Random;
const builtin = @import("builtin");
const assert = std.debug.assert;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Ray = @import("Ray.zig");
const inf64 = std.math.inf(f64);

pub const Interval = struct {
    min: f64,
    max: f64,

    pub const empty: Interval = .{
        .min = inf64,
        .max = -inf64,
    };
    pub const universe: Interval = .{
        .min = -inf64,
        .max = inf64,
    };

    pub fn size(i: Interval) f64 {
        return i.max - i.min;
    }

    pub fn contains(i: Interval, x: f64) bool {
        return i.min <= x and x <= i.max;
    }

    pub fn surrounds(i: Interval, x: f64) bool {
        return i.min < x and x < i.max;
    }
};

pub const Material = union(enum) {
    lambertian: struct {
        albedo: Vec3,

        pub fn scatter(
            lambertian: @This(),
            rand: Random,
            hit: Hit,
            r: Ray,
        ) ?Scatter {
            _ = r;

            // const direction = vec.randomHemisphere(rand, hit.n);
            const direction = hit.n + vec.randomUnit(rand);

            return .{
                .ray = .{
                    .origin = hit.p,
                    .direction = if (vec.nearZero(direction))
                        hit.n
                    else
                        direction,
                },
                .attenuation = lambertian.albedo,
            };
        }
    },
    metal: struct {
        albedo: Vec3,
        fuzz: f64,

        pub fn scatter(metal: @This(), rand: Random, hit: Hit, r: Ray) ?Scatter {
            const direction = vec.reflect(r.direction, hit.n) +
                vec.splat(metal.fuzz) * vec.randomUnit(rand);

            if (vec.dot(direction, hit.n) < 0) return null;

            return .{
                .ray = .{ .origin = hit.p, .direction = direction },
                .attenuation = metal.albedo,
            };
        }
    },

    dielectric: struct {
        refraction_index: f64,

        pub fn scatter(
            dielectric: @This(),
            rand: Random,
            hit: Hit,
            r: Ray,
        ) ?Scatter {
            const ratio = if (hit.front_face)
                1.0 / dielectric.refraction_index
            else
                dielectric.refraction_index;

            const unit_direction = vec.unit(r.direction);
            const cos_theta = @min(vec.dot(-unit_direction, hit.n), 1.0);
            const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

            const cannot_refract = ratio * sin_theta > 1.0;
            const shlick = reflectance(cos_theta, ratio) > rand.float(f64);

            const outcome: enum {
                reflect,
                refract,
            } = if (cannot_refract or shlick) .reflect else .refract;

            switch (outcome) {
                .reflect => {
                    // if (!hit.front_face) return null;
                    const direction = vec.reflect(r.direction, hit.n);

                    return .{
                        .ray = .{ .origin = hit.p, .direction = direction },
                        .attenuation = vec.one,
                    };
                },
                .refract => {
                    const direction = vec.refract(unit_direction, hit.n, ratio);

                    return .{
                        .ray = .{ .origin = hit.p, .direction = direction },
                        .attenuation = vec.one,
                    };
                },
            }
        }

        fn reflectance(cosine: f64, refraction_index: f64) f64 {
            // Use Schlick's approximation for reflectance.
            var r0 = (1 - refraction_index) / (1 + refraction_index);
            r0 = r0 * r0;
            return r0 + (1 - r0) * std.math.pow(f64, (1 - cosine), 5);
        }
    },

    pub const Scatter = struct {
        ray: Ray,
        attenuation: Vec3,
    };

    pub fn scatter(material: Material, rand: Random, hit: Hit, r: Ray) ?Scatter {
        return switch (material) {
            inline else => |m| m.scatter(rand, hit, r),
        };
    }
};

pub const Hit = struct {
    p: Vec3,
    n: Vec3,
    t: f64,
    front_face: bool,
    material: Material,

    pub fn init(
        t: f64,
        r: Ray,
        p: Vec3,
        outward_normal: Vec3,
        material: Material,
    ) Hit {
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
            .material = material,
        };
    }

    pub fn scatter(h: Hit, random: Random, r: Ray) ?Material.Scatter {
        return h.material.scatter(random, h, r);
    }
};

pub const Sphere = struct {
    radius: f64,
    center: Vec3,
    material: Material,

    pub fn init(center: Vec3, radius: f64, material: Material) Sphere {
        assert(radius >= 0);
        return .{
            .center = center,
            .radius = radius,
            .material = material,
        };
    }

    pub fn hit(s: Sphere, r: Ray, interval: Interval) ?Hit {
        const oc: Vec3 = s.center - r.origin;
        const a = vec.magnitude2(r.direction);
        const h = vec.dot(r.direction, oc);
        const c = vec.magnitude2(oc) - s.radius * s.radius;
        const discriminant = h * h - a * c;

        if (discriminant < 0) return null;

        const sqrtd = @sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (h - sqrtd) / a;
        if (!interval.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!interval.surrounds(root)) return null;
        }

        const p = r.at(root);
        const outward_normal = (p - s.center) / vec.splat(s.radius);
        return .init(root, r, p, outward_normal, s.material);
    }
};
