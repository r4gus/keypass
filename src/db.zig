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

pub const Config = struct {
    pub const Theme = enum {
        dark,
    };

    db_path: []const u8 = "",
    theme: Theme = .dark,

    pub fn load(a: std.mem.Allocator) !Config {
        var file = openFile("~/.keypass/config.json") catch {
            return error.NotFound;
        };
        defer file.close();

        var mem = try file.readToEndAlloc(a, 50_000_000);
        defer a.free(mem);

        return try std.json.parseFromSliceLeaky(@This(), a, mem, .{ .allocate = .alloc_always });
    }

    pub fn create(a: std.mem.Allocator) !void {
        const home = std.os.getenv("HOME");
        if (home == null) return error.NoHome;
        var home_dir = try std.fs.openDirAbsolute(home.?, .{});
        defer home_dir.close();
        var file = try home_dir.createFile(".keypass/config.json", .{ .exclusive = true });
        defer file.close();

        var str = std.ArrayList(u8).init(a);
        defer str.deinit();

        var x = @This(){};
        try std.json.stringify(x, .{}, str.writer());

        try file.writeAll(str.items);
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        a.free(self.db_path);
    }
};
