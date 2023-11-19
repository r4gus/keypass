const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const keylib_dep = b.dependency("keylib", .{
        .target = target,
        .optimize = optimize,
    });

    const tresor_dep = b.dependency("tresor", .{
        .target = target,
        .optimize = optimize,
    });

    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "passkeez",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("keylib", keylib_dep.module("keylib"));
    exe.addModule("uhid", keylib_dep.module("uhid"));
    exe.addModule("zbor", keylib_dep.module("zbor"));
    exe.addModule("tresor", tresor_dep.module("tresor"));

    exe.addModule("dvui", dvui_dep.module("dvui"));
    exe.addModule("SDLBackend", dvui_dep.module("SDLBackend"));
    const freetype_dep = dvui_dep.builder.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(freetype_dep.artifact("freetype"));
    const stbi_dep = dvui_dep.builder.dependency("stb_image", .{
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(stbi_dep.artifact("stb_image"));
    exe.linkSystemLibrary("SDL2");

    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //const unit_tests = b.addTest(.{
    //    .root_source_file = .{ .path = "src/main.zig" },
    //    .target = target,
    //    .optimize = optimize,
    //});

    //const run_unit_tests = b.addRunArtifact(unit_tests);

    //const test_step = b.step("test", "Run unit tests");
    //test_step.dependOn(&run_unit_tests.step);
}
