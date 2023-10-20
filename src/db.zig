const std = @import("std");
const tresor = @import("tresor");

pub fn open(path: []const u8, pw: []const u8, a: std.mem.Allocator) !tresor.Tresor {
    var file = openFile(path) catch {
        return error.NotFound;
    };
    defer file.close();

    var mem = try file.readToEndAlloc(a, 50_000_000);
    defer a.free(mem);

    return tresor.Tresor.open(
        mem,
        pw,
        a,
        std.crypto.random,
        std.time.milliTimestamp,
    );
}

pub fn openFile(path: []const u8) !std.fs.File {
    return if (path[0] == '~' and path[1] == '/') blk: {
        const home = std.os.getenv("HOME");
        if (home == null) return error.NoHome;
        var home_dir = try std.fs.openDirAbsolute(home.?, .{});
        defer home_dir.close();
        var file = try home_dir.openFile(path[2..], .{ .mode = .read_write });
        break :blk file;
    } else if (path[0] == '/') blk: {
        var file = try std.fs.openFileAbsolute(path[0..], .{ .mode = .read_write });
        break :blk file;
    } else blk: {
        var file = try std.fs.cwd().openFile(path[0..], .{ .mode = .read_write });
        break :blk file;
    };
}
