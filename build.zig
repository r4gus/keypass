const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const passkeez = b.addExecutable(.{
        .name = "passkeez",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    passkeez.linkLibC();
    passkeez.linkSystemLibrary("gtk+-3.0");
    b.installArtifact(passkeez);
}
